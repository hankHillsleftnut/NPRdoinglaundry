import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct OutboxDrainTests {
    /// A clock the test moves by hand.
    private final class Now: @unchecked Sendable {
        private let lock = NSLock()
        private var date = Date(timeIntervalSince1970: 1_792_569_604)

        var value: Date {
            lock.withLock { date }
        }

        func advance(seconds: TimeInterval) {
            lock.withLock { date = date.addingTimeInterval(seconds) }
        }
    }

    private let database: Store.LocalDatabase
    private let recorder = Platform.Log.Recorder()
    private let sender = ScriptedSender()
    private let now = Now()
    private let a = UUID(uuidString: "00000000-0000-4000-8000-00000000000a") ?? UUID()
    private let b = UUID(uuidString: "00000000-0000-4000-8000-00000000000b") ?? UUID()

    init() throws {
        database = try Store.LocalDatabase.inMemory()
    }

    /// Full jitter is replaced by its ceiling, so delays are exact; the
    /// acknowledgement picker always takes the first choice.
    private func outbox(
        reachability: (any Backend.Reachability)? = nil,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) -> Store.Outbox {
        let now = now
        return Store.Outbox(
            database: database, sender: sender, reachability: reachability, now: { now.value }, timeZone: { .gmt }, jitter: { $0 },
            pick: { _ in 0 }, sleep: sleep, log: recorder
        )
    }

    /// Records each wait the drainer asks for and holds it until the test opens the gate.
    private final class Waits: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [TimeInterval] = []
        let gate = Gate()

        var values: [TimeInterval] {
            lock.withLock { seen }
        }

        func sleep(_ seconds: TimeInterval) async throws {
            lock.withLock { seen.append(seconds) }
            try await gate.wait()
        }
    }

    private func draft(_ id: UUID) throws -> Store.EntryDraft {
        try #require(Store.EntryDraft(id: id, kind: .typed, text: "dentist at 3", createdAt: Date(timeIntervalSince1970: 1_792_569_000)))
    }

    private func key(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    /// Synchronous reads: in an async test, `writer.read` picks GRDB's async overload.
    private func item(_ id: UUID) throws -> Store.OutboxRow {
        try #require(try database.writer.read { try Store.OutboxRow.fetchOne($0, key: key(id)) })
    }

    private func entryCount() throws -> Int {
        try database.writer.read { try Store.EntryRow.fetchCount($0) }
    }

    private func rowByID(_ id: String) throws -> Store.OutboxRow {
        try #require(try database.writer.read { try Store.OutboxRow.fetchOne($0, key: id) })
    }

    private func entry(_ id: UUID) throws -> Store.EntryRow {
        try #require(try database.writer.read { try Store.EntryRow.fetchOne($0, key: key(id)) })
    }

    private func execute(_ sql: String, _ arguments: StatementArguments = []) throws {
        try database.writer.write { try $0.execute(sql: sql, arguments: arguments) }
    }

    private var drainedLines: [Platform.Log.Event] {
        recorder.events.filter {
            if case .outbox(.drained) = $0 {
                true
            } else {
                false
            }
        }
    }

    // MARK: Sending

    @Test("a queued entry is sent once, with its own id as the key and the stored bytes, and marked sent with the server's answer")
    func aQueuedEntryIsSentOnce() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let stored = try item(a)

        await outbox.drain(reason: .manual)

        #expect(sender.sends == [.init(id: key(a), payload: stored.payload, attempts: 0)])
        let sent = try item(a)
        #expect(sent.status == .done)
        #expect(sent.attempts == 1)
        let entry = try entry(a)
        #expect(entry.syncState == .sent)
        #expect(entry.serverID == "server-\(key(a))")
        #expect(entry.reading == .waiting)
        #expect(entry.attempts == 1)
        #expect(recorder.events.contains(.outbox(.sent(operation: .entryCreate, attempts: 1, ms: 0))))
        #expect(drainedLines == [.outbox(.drained(sent: 1, failed: 0))])
    }

    @Test("a second drain sends nothing: a sent item is never sent again")
    func aSentItemIsNeverSentAgain() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        await outbox.drain(reason: .manual)

        await outbox.drain(reason: .foreground)

        #expect(sender.sends.count == 1)
    }

    @Test("without a sender, drain does nothing and the item stays queued")
    func withoutASenderDrainDoesNothing() async throws {
        let now = now
        let outbox = Store.Outbox(database: database, now: { now.value }, timeZone: { .gmt }, log: recorder)
        try await outbox.enqueueEntry(draft(a))

        await outbox.drain(reason: .manual)

        #expect(try item(a).status == .pending)
        #expect(drainedLines.isEmpty)
    }

    @Test("a sent entry takes the server's createdAt and day, so a clamped clock moves it once")
    func aSentEntryTakesTheServersCreatedAtAndDay() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.success(.init(
            serverID: "srv", reading: .waiting, createdAt: Date(timeIntervalSince1970: 1_792_569_000.5), day: "2026-10-20"
        ))])

        await outbox.drain(reason: .manual)

        let entry = try entry(a)
        #expect(abs(entry.createdAt.timeIntervalSince(Date(timeIntervalSince1970: 1_792_569_000.5))) < 0.001)
        #expect(entry.day == "2026-10-20")
        #expect(entry.serverID == "srv")
    }

    @Test("an answer that comes back without a createdAt or day keeps the row's own")
    func aSentEntryKeepsItsOwnDatesWhenTheAnswerHasNone() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let before = try entry(a)

        await outbox.drain(reason: .manual)

        #expect(try entry(a).day == before.day)
        #expect(try abs(entry(a).createdAt.timeIntervalSince(before.createdAt)) < 0.001)
    }

    // MARK: The acknowledgement

    @Test("an entry gets its acknowledgement line when first sent, never the newest line already stored, and keeps it for good")
    func anEntryGetsItsAcknowledgementOnce() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        #expect(try entry(a).acknowledgement == nil, "nothing until sent")

        await outbox.drain(reason: .manual)

        let first = try #require(try entry(a).acknowledgement)
        #expect(Flows.Journal.Acknowledgements.lines.contains(first))

        try await outbox.enqueueEntry(draft(b))
        await outbox.drain(reason: .manual)
        let second = try #require(try entry(b).acknowledgement)
        #expect(second != first, "never the same line twice in a row")
        #expect(try entry(a).acknowledgement == first)

        try execute("UPDATE entries SET acknowledgement = 'kept.' WHERE local_id = ?", [key(a)])
        try execute("UPDATE outbox SET status = 'pending' WHERE id = ?", [key(a)])
        await outbox.drain(reason: .manual)
        #expect(try entry(a).acknowledgement == "kept.", "a line already chosen is never changed")
    }

    @Test("a refused entry gets no acknowledgement")
    func aRefusedEntryGetsNoAcknowledgement() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.invalidRequest))])

        await outbox.drain(reason: .manual)

        #expect(try entry(a).acknowledgement == nil)
    }

    // MARK: Reports (DG.5b)

    private func report(_ id: String = "00000000-0000-4000-8000-0000000000d1", note: String? = "the brief stalled") throws -> Platform.Diagnostics.Report {
        let reportID = try #require(UUID(uuidString: id))
        return Platform.Diagnostics.Report(
            reportID: reportID, createdAt: Date(timeIntervalSince1970: 1_792_569_604.2), note: note,
            environment: Platform.Diagnostics.Environment(sources: .init(
                info: [:], osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "iPhone17,1",
                locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
                network: .none, freeDiskBytes: 8_000_000_000
            )),
            account: .init(provider: .apple, access: .member, entitlement: .trial), events: [], network: [], outbox: .empty,
            failures: [], performance: .none, crashes: []
        )
    }

    private func allRows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.fetchAll($0) }
    }

    @Test("queueing the same report twice stores one row, and one send makes one reference")
    func aRetryStoresOneReport() async throws {
        let outbox = outbox()
        let report = try report()

        try await outbox.enqueueReport(report)
        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)

        let rows = try allRows()
        #expect(rows.count == 1)
        #expect(rows.first?.id == report.reportId)
        #expect(rows.first?.operation == .diagnosticsSend)
        #expect(sender.sends.count == 1)
        #expect(sender.sends.first?.id == report.reportId)
        #expect(recorder.events.filter { $0 == .outbox(.enqueued(operation: .diagnosticsSend)) }.count == 1)
    }

    @Test("a report queued offline is kept, goes out when the phone is back, and its reference reaches the listener")
    func anOfflineSendDeliversLater() async throws {
        let outbox = outbox(reachability: StreamingReachability())
        let report = try report()
        sender.script(report.reportId, [.failure(Backend.Failure(.offline)), .success(Store.OutboxSendResult(reference: "r-7KQ2"))])
        var receipts = await outbox.receipts().makeAsyncIterator()

        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)

        var row = try rowByID(report.reportId)
        #expect(row.status == .pending, "offline pauses: the report waits, nothing counted")
        #expect(row.attempts == 0)
        #expect(!row.payload.isEmpty)

        await outbox.drain(reason: .reachability)

        row = try rowByID(report.reportId)
        #expect(row.status == .done)
        #expect(row.payload.isEmpty, "a delivered report's bytes are not kept")
        let receipt = await receipts.next()
        #expect(receipt == Store.Outbox.ReportReceipt(reportID: report.reportId, reference: "r-7KQ2"))
        #expect(try entryCount() == 0, "a report never makes an entry row")
    }

    @Test("a report the door refuses for good is dead and can be retried by hand")
    func aRefusedReportCanBeRetried() async throws {
        let outbox = outbox()
        let report = try report()
        sender.script(report.reportId, [.failure(Backend.Failure(.invalidRequest))])

        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)
        #expect(try rowByID(report.reportId).status == .dead)

        try await outbox.retry(entityID: #require(UUID(uuidString: report.reportId)))
        await outbox.drain(reason: .manual)
        #expect(try rowByID(report.reportId).status == .done)
    }

    @Test("a refused report sent again from the sheet goes back in the queue and is sent")
    func aRefusedReportEnqueuedAgainIsSent() async throws {
        let outbox = outbox()
        let report = try report()
        sender.script(report.reportId, [.failure(Backend.Failure(.invalidRequest))])
        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)
        #expect(try rowByID(report.reportId).status == .dead)

        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)

        #expect(try rowByID(report.reportId).status == .done)
        #expect(try allRows().count == 1)
    }

    @Test("an upper-case report id is stored under the lower-case key retry looks for, and is sent")
    func anUppercaseReportIDIsNormalised() async throws {
        let outbox = outbox()
        let report = try report("00000000-0000-4000-8000-0000000000D1")
        try await outbox.enqueueReport(report)
        await outbox.drain(reason: .manual)

        #expect(try allRows().map(\.id) == ["00000000-0000-4000-8000-0000000000d1"])
        #expect(try allRows().first?.status == .done)
    }

    @Test("a report is not an unsent entry, and sign-out drops reports that never went; delivered ones stay")
    func reportsAndSignOut() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        try await outbox.enqueueReport(report())
        #expect(try await outbox.unsentCount() == 1)

        try await outbox.discardReports()

        let rows = try allRows()
        #expect(rows.map(\.operation) == [.entryCreate], "the report is gone, the entry stays")
        try await outbox.enqueueReport(report("00000000-0000-4000-8000-0000000000d2"))
        await outbox.drain(reason: .manual)
        try await outbox.discardReports()
        #expect(try allRows().count == 2, "a delivered report stays as the record it was sent")
    }

    // MARK: Guess answers

    @Test("a queued guess answer is sent with its verdict, keyed by its own row, and never touches entries")
    func aQueuedGuessAnswerIsSent() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        await outbox.drain(reason: .manual)
        let entryBefore = try entry(a)
        let rowKey = try await outbox.enqueueGuessAnswer(guessID: "guess-1", verdict: .no)

        await outbox.drain(reason: .manual)

        let send = try #require(sender.sends.last)
        #expect(send.id == rowKey.uuidString.lowercased())
        #expect(try #require(String(data: send.payload, encoding: .utf8)) == #"{"verdict":"no"}"#)
        let row = try rowByID(rowKey.uuidString.lowercased())
        #expect(row.status == .done)
        #expect(row.entityID == "guess-1")
        #expect(row.operation == .guessAnswer)
        #expect(try entry(a) == entryBefore, "the entry row is untouched by a guess's send")
        #expect(try entryCount() == 1, "no entry row is made for a guess")
        #expect(recorder.events.contains(.outbox(.enqueued(operation: .guessAnswer))))
    }

    @Test("a guess answer refused for good is dead, and a retryable one is dead after the attempt budget; entries stay untouched")
    func aGuessAnswerDiesLikeAnEntry() async throws {
        let outbox = outbox()
        let refused = try await outbox.enqueueGuessAnswer(guessID: "guess-1", verdict: .yes)
        let flaky = try await outbox.enqueueGuessAnswer(guessID: "guess-2", verdict: .yes)
        sender.script(refused.uuidString.lowercased(), [.failure(Backend.Failure(.notFound))])
        sender.script(flaky.uuidString.lowercased(), Array(repeating: .failure(Backend.Failure(.upstreamUnavailable)), count: 5))

        for _ in 0 ..< 5 {
            await outbox.drain(reason: .manual)
            now.advance(seconds: 600)
        }

        #expect(try rowByID(refused.uuidString.lowercased()).status == .dead)
        #expect(try rowByID(refused.uuidString.lowercased()).lastErrorCode == "not_found")
        #expect(try rowByID(flaky.uuidString.lowercased()).status == .dead)
        #expect(try rowByID(flaky.uuidString.lowercased()).attempts == Store.Outbox.attemptLimit)
        #expect(try entryCount() == 0)
        #expect(try await outbox.unsentCount() == 2, "queued answers count as unsent")
    }

    // MARK: Offline and retries

    @Test("an entry written offline is sent once when the network returns, with the same key")
    func anOfflineWriteIsSentOnceWhenTheNetworkReturns() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.offline))])

        await outbox.drain(reason: .launch)
        #expect(try item(a).status == .pending)
        #expect(try item(a).attempts == 0, "offline counts no attempt")
        #expect(recorder.events.contains(.outbox(.paused(code: .offline))))

        await outbox.drain(reason: .reachability)

        #expect(sender.sends.map(\.id) == [key(a), key(a)])
        #expect(try item(a).status == .done)
    }

    @Test("every retry of an item carries the same key and the same bytes")
    func everyRetryCarriesTheSameKey() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.transport)), .failure(Backend.Failure(.upstreamUnavailable))])

        await outbox.drain(reason: .manual)
        now.advance(seconds: 3)
        await outbox.drain(reason: .manual)
        now.advance(seconds: 5)
        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a), key(a), key(a)])
        #expect(Set(sender.sends.map(\.payload)).count == 1)
        #expect(sender.sends.map(\.attempts) == [0, 1, 2])
        #expect(try item(a).status == .done)
    }

    @Test("a 503 is retried with jittered backoff: 2 s, 4 s, 8 s… capped at five minutes")
    func a503IsRetriedWithBackoff() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.upstreamUnavailable)), .failure(Backend.Failure(.upstreamUnavailable))])

        await outbox.drain(reason: .manual)
        #expect(try item(a).nextAttemptAt.timeIntervalSince(now.value) == 2)
        #expect(try item(a).lastErrorCode == "upstream_unavailable")
        #expect(try entry(a).syncState == .local)

        now.advance(seconds: 1)
        await outbox.drain(reason: .manual)
        #expect(sender.sends.count == 1, "not due yet")

        now.advance(seconds: 1)
        await outbox.drain(reason: .manual)
        #expect(sender.sends.count == 2)
        #expect(try item(a).nextAttemptAt.timeIntervalSince(now.value) == 4)
        #expect(Store.Outbox.backoffCeiling(attempt: 9) == .seconds(300))
        #expect(Store.Outbox.backoffCeiling(attempt: 20) == .seconds(300))
        #expect(recorder.events.filter { $0 == .outbox(.retry(operation: .entryCreate, code: .upstreamUnavailable)) }.count == 2)
    }

    @Test("429 waits for the server's retry-after when it's longer than the backoff")
    func a429WaitsForRetryAfter() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.rateLimited(retryAfter: .seconds(60))))])

        await outbox.drain(reason: .manual)

        #expect(try item(a).nextAttemptAt.timeIntervalSince(now.value) == 60)
        #expect(try item(a).status == .pending)
    }

    @Test("after five retryable failures the item is dead and the entry failed with the last code")
    func afterFiveRetryableFailuresTheItemIsDead() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), Array(repeating: .failure(Backend.Failure(.timedOut)), count: 5))

        for _ in 0 ..< 5 {
            await outbox.drain(reason: .manual)
            now.advance(seconds: 600)
        }

        #expect(sender.sends.count == Store.Outbox.attemptLimit)
        #expect(try item(a).status == .dead)
        #expect(try item(a).attempts == 5)
        #expect(try entry(a).syncState == .failed)
        #expect(try entry(a).failureCode == "timed_out")
        #expect(recorder.events.contains(.outbox(.dead(operation: .entryCreate, code: .timedOut))))
        await outbox.drain(reason: .manual)
        #expect(sender.sends.count == 5, "a dead item is never sent again")
    }

    // MARK: Refused for good

    @Test("a 400 makes the item dead and the entry failed with its code", arguments: [
        (Backend.Failure.Kind.invalidRequest, "invalid_request"), (.idempotencyMismatch, "idempotency_mismatch"), (.decoding, "decoding"),
        (.notFound, "not_found"), (.unknown(code: "brand_new"), "unknown"),
    ])
    func aPermanentFailureMakesTheItemDead(_ kind: Backend.Failure.Kind, _ code: String) async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(kind))])

        await outbox.drain(reason: .manual)

        #expect(try item(a).status == .dead)
        #expect(try item(a).lastErrorCode == code)
        #expect(try entry(a).syncState == .failed)
        #expect(try entry(a).failureCode == code)
        #expect(drainedLines == [.outbox(.drained(sent: 0, failed: 1))])
    }

    @Test("retry puts a dead item back, and the next drain sends it with the same key")
    func retryPutsADeadItemBackAndItIsSent() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.invalidRequest))])
        await outbox.drain(reason: .manual)

        try await outbox.retry(entityID: a)
        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a), key(a)])
        #expect(try item(a).status == .done)
        #expect(try entry(a).syncState == .sent)
    }

    // MARK: The session

    @Test("unauthenticated stops the pass without killing the item; later items wait untouched")
    func unauthenticatedStopsThePass() async throws {
        let outbox = outbox()
        let c = UUID()
        try await outbox.enqueueEntry(draft(a))
        try await outbox.enqueueEntry(draft(b))
        try await outbox.enqueueEntry(draft(c))
        sender.script(key(b), [.failure(Backend.Failure(.unauthenticated))])

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a), key(b)])
        #expect(try item(a).status == .done)
        #expect(try item(b).status == .pending)
        #expect(try item(b).attempts == 0)
        #expect(try entry(b).syncState == .local)
        #expect(try item(c).status == .pending)
        #expect(recorder.events.contains(.outbox(.paused(code: .unauthenticated))))
        #expect(drainedLines == [.outbox(.drained(sent: 1, failed: 0))])
    }

    @Test(
        "a pause ends the drain even with two items for one entity: one send, no loop",
        arguments: [Backend.Failure.Kind.offline, .unauthenticated, .sessionRevoked, .updateRequired]
    )
    func aPauseWithTwoItemsForOneEntityDoesNotLoop(kind: Backend.Failure.Kind) async throws {
        let outbox = outbox()
        let first = try await outbox.enqueueGuessAnswer(guessID: "guess-1", verdict: .no)
        try await outbox.enqueueGuessAnswer(guessID: "guess-1", verdict: .yes)
        sender.script(first.uuidString.lowercased(), [.failure(Backend.Failure(kind))])

        await outbox.drain(reason: .manual)

        #expect(sender.sends.count == 1)
        #expect(drainedLines.count == 1)
        #expect(try item(first).status == .pending)
        #expect(try item(first).attempts == 0)
    }

    @Test("a person on an old build (426) or past the day's spend (429) keeps every word: pending, no attempt counted, sent once it passes")
    func updateRequiredAndSpendLimitedNeverKillAnEntry() async throws {
        for kind in [Backend.Failure.Kind.updateRequired, .spendLimited(retryAfter: nil)] {
            let outbox = outbox()
            let id = UUID()
            try await outbox.enqueueEntry(draft(id))
            // 426 is sent again on each trigger; a spend refusal is not due again until its wait ends
            let refusals = kind == .updateRequired ? 2 : 1
            sender.script(key(id), Array(repeating: .failure(Backend.Failure(kind)), count: refusals))

            await outbox.drain(reason: .manual)
            await outbox.drain(reason: .foreground)

            #expect(try item(id).status == .pending, "\(kind): waits")
            #expect(try item(id).attempts == 0, "\(kind): no attempt counted")
            #expect(try entry(id).syncState == .local, "\(kind): the person sees 'not sent yet', never 'failed'")
            #expect(try await outbox.unsentCount() == 1)

            now.advance(seconds: 3600) // a spend refusal with no Retry-After holds its item an hour
            await outbox.drain(reason: .foreground) // the build was updated / the day passed: the script has run out, the send succeeds
            #expect(try item(id).status == .done, "\(kind): sent after the update")
            #expect(sender.sends.filter { $0.id == key(id) }.count == refusals + 1, "\(kind): one send per due drain, no spin")
            try execute("DELETE FROM outbox")
            try execute("DELETE FROM entries")
        }
    }

    @Test("a spent day holds only the refused item: an entry queued behind a spend-refused answer still goes, and the answer goes when the wait ends")
    func aSpendRefusalHoldsOnlyItsItem() async throws {
        let waits = Waits()
        let outbox = outbox(sleep: waits.sleep)
        let answer = try await outbox.enqueueGuessAnswer(guessID: "guess-1", verdict: .yes).uuidString.lowercased()
        try await outbox.enqueueEntry(draft(a))
        sender.script(answer, [.failure(Backend.Failure(.spendLimited(retryAfter: .seconds(86400))))])

        await outbox.start()
        for _ in 0 ..< 500 where waits.values.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(try item(a).status == .done, "the person's entry is not held behind the spent day")
        #expect(try rowByID(answer).status == .pending)
        #expect(try rowByID(answer).attempts == 0, "a spent day is not the answer's fault: no attempt counted")
        #expect(waits.values == [86400], "a timer wakes the answer when the server's wait ends, no sooner")
        #expect(sender.sends.count == 2)

        now.advance(seconds: 86400)
        waits.gate.open()
        for _ in 0 ..< 500 where try rowByID(answer).status != .done {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(try rowByID(answer).status == .done)
        #expect(sender.sends.map(\.id) == [answer, key(a), answer], "same key on the retry")
        #expect(sender.sends.first?.payload == sender.sends.last?.payload, "same bytes on the retry")
    }

    @Test("rows an earlier build killed for update_required or spend_limited are revived at start, with their entries; other refusals stay dead")
    func oldRefusalsAreRevived() async throws {
        let outbox = outbox()
        let (old, spend, real) = (UUID(), UUID(), UUID())
        for id in [old, spend, real] {
            try await outbox.enqueueEntry(draft(id))
        }
        try execute("UPDATE outbox SET status = 'dead', attempts = 1, last_error_code = 'update_required' WHERE id = ?", [key(old)])
        try execute("UPDATE outbox SET status = 'dead', attempts = 1, last_error_code = 'spend_limited' WHERE id = ?", [key(spend)])
        try execute("UPDATE outbox SET status = 'dead', attempts = 1, last_error_code = 'invalid_request' WHERE id = ?", [key(real)])
        try execute("UPDATE entries SET sync_state = 'failed'")

        await outbox.start()
        await outbox.drain(reason: .manual)

        #expect(try item(old).status == .done && item(spend).status == .done)
        #expect(try item(real).status == .dead, "a real refusal is not revived")
        #expect(try entry(real).syncState == .failed)
    }

    // MARK: Retry timer

    @Test("a failed send wakes the drainer when its backoff ends, with no other trigger")
    func aRetryWakesTheDrainerWhenDue() async throws {
        let waits = Waits()
        let outbox = outbox(sleep: waits.sleep)
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.upstreamUnavailable))])

        await outbox.start()
        for _ in 0 ..< 500 where waits.values.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(waits.values == [2])
        #expect(try item(a).status == .pending)
        #expect(sender.sends.count == 1)

        now.advance(seconds: 2)
        waits.gate.open()
        for _ in 0 ..< 500 where try item(a).status != .done {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(try item(a).status == .done)
        #expect(sender.sends.count == 2)
    }

    @Test("a pause sets no timer: the next trigger (reachability, sign-in, foreground) does it")
    func aPauseSetsNoTimer() async throws {
        let waits = Waits()
        let outbox = outbox(sleep: waits.sleep)
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.offline))])

        await outbox.start()
        await outbox.drain(reason: .manual)
        try await Task.sleep(for: .milliseconds(100))

        #expect(waits.values.isEmpty)
    }

    // MARK: Crashes mid-send

    @Test("a send in flight carries its crash deadline: two minutes out, the entry sending")
    func aSendInFlightCarriesItsDeadline() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let seen = Seen()
        let database = database
        sender.inspect = { row in
            let entry = try? database.writer.read { try Store.EntryRow.fetchOne($0, key: row.id) }
            seen.set(status: row.status, deadline: row.nextAttemptAt, entryState: entry?.syncState)
        }

        await outbox.drain(reason: .manual)

        let row = try item(a)
        #expect(row.status == .done, "the row the sender saw is the stored one; after the send it's done")
        #expect(try #require(seen.status) == .inFlight)
        #expect(try #require(seen.entryState) == .sending)
        #expect(try #require(seen.deadline).timeIntervalSince(now.value) == Store.Outbox.crashedSendAfter)
    }

    @Test("an inFlight item left by a crash is resent with the same key after two minutes, not before")
    func anInFlightItemLeftByACrashIsResentAfterTwoMinutes() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let sentAt = now.value
        try execute(
            "UPDATE outbox SET status = 'inFlight', next_attempt_at = ? WHERE id = ?",
            [Backend.Coding.timestamp(sentAt.addingTimeInterval(Store.Outbox.crashedSendAfter)), key(a)]
        )

        now.advance(seconds: 60)
        await outbox.drain(reason: .launch)
        #expect(sender.sends.isEmpty, "still in flight: not two minutes yet")
        #expect(try item(a).status == .inFlight)

        now.advance(seconds: 61)
        await outbox.drain(reason: .launch)

        #expect(sender.sends.map(\.id) == [key(a)])
        #expect(try item(a).status == .done)
    }

    @Test("cancelling a drain mid-send puts the item back to pending for the next drain")
    func cancellingADrainMidSendPutsTheItemBack() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let gate = Gate()
        sender.gate = gate
        let drain = Task { await outbox.drain(reason: .backgroundTask) }
        try await waitUntil { gate.waiting == 1 }

        drain.cancel()
        await drain.value

        #expect(try item(a).status == .pending)
        #expect(try entry(a).syncState == .local)
        sender.gate = nil
        await outbox.drain(reason: .manual)
        #expect(try item(a).status == .done)
    }

    // MARK: One drainer

    @Test("two triggers during a drain cause one extra pass, never two drainers")
    func twoTriggersDuringADrainCauseOneExtraPass() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let gate = Gate()
        sender.gate = gate
        let first = Task { await outbox.drain(reason: .launch) }
        try await waitUntil { gate.waiting == 1 }

        await outbox.drain(reason: .foreground)
        await outbox.drain(reason: .afterWrite)
        try await outbox.enqueueEntry(draft(b))
        gate.open()
        await first.value

        #expect(sender.peakConcurrency == 1)
        #expect(sender.sends.map(\.id) == [key(a), key(b)], "the extra pass picked up what was queued during the drain")
        #expect(drainedLines.count == 2)
    }

    @Test(
        "a trigger that comes while a send is pausing still gets its pass: back online (or signed in) mid-send is not lost",
        arguments: [Backend.Failure.Kind.offline, .unauthenticated]
    )
    func aTriggerDuringAPausingSendGetsItsPass(pause: Backend.Failure.Kind) async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(pause))])
        let gate = Gate()
        sender.gate = gate
        let first = Task { await outbox.drain(reason: .launch) }
        try await waitUntil { gate.waiting == 1 }

        // The phone comes back online while the send that will fail offline is still out.
        await outbox.drain(reason: .reachability)
        sender.gate = nil
        gate.open()
        await first.value

        #expect(sender.sends.map(\.id) == [key(a), key(a)], "the pause ended the first pass; the trigger that came during it got a second")
        #expect(sender.sends.map(\.attempts) == [0, 0], "a pause counts no attempt")
        #expect(try item(a).status == .done)
        #expect(drainedLines.count == 2)
    }

    @Test("a trigger during a pause that is still offline costs one more pass, then the drain ends: no loop")
    func aTriggerDuringAPauseStillOfflineEndsAfterOneMorePass() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        sender.script(key(a), [.failure(Backend.Failure(.offline)), .failure(Backend.Failure(.offline))])
        let gate = Gate()
        sender.gate = gate
        let first = Task { await outbox.drain(reason: .launch) }
        try await waitUntil { gate.waiting == 1 }

        await outbox.drain(reason: .afterWrite)
        sender.gate = nil
        gate.open()
        await first.value

        #expect(sender.sends.map(\.id) == [key(a), key(a)])
        #expect(try item(a).status == .pending)
        #expect(try item(a).attempts == 0)
        #expect(drainedLines.count == 2)
    }

    // MARK: Ordering

    @Test("items for one entity go in order; a refused one blocks that entity's later items, not another entity's")
    func itemsForOneEntityGoInOrder() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        try await outbox.enqueueEntry(draft(b))
        let later = "later-\(key(a))"
        try execute(
            """
            INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, created_at)
            SELECT ?, operation, entity_id, payload, 0, next_attempt_at, 'pending', ? FROM outbox WHERE id = ?
            """,
            [later, Backend.Coding.timestamp(now.value.addingTimeInterval(1)), key(a)]
        )
        sender.script(key(a), [.failure(Backend.Failure(.invalidRequest))])

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a), key(b)], "a's later item waits behind its refused one; b goes")
        #expect(try rowByID(later).status == .pending)
    }

    @Test("an entity's second item goes in the next pass once its first has landed")
    func anEntitysSecondItemGoesNextPass() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        let later = "later-\(key(a))"
        try execute(
            """
            INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, created_at)
            SELECT ?, operation, entity_id, payload, 0, next_attempt_at, 'pending', ? FROM outbox WHERE id = ?
            """,
            [later, Backend.Coding.timestamp(now.value.addingTimeInterval(1)), key(a)]
        )

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a), later])
        #expect(drainedLines.count == 2, "the second item took one more pass")
    }

    @Test("items go oldest first by created_at then rowid, even within one millisecond")
    func itemsGoOldestFirst() async throws {
        let outbox = outbox()
        let ids = (1 ... 3).map { UUID(uuidString: "00000000-0000-4000-8000-00000000001\($0)") ?? UUID() }
        for id in ids {
            try await outbox.enqueueEntry(draft(id))
        }

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == ids.map(key))
    }

    @Test("an item whose operation this build doesn't know is left in the queue untouched")
    func anUnknownOperationIsLeftAlone() async throws {
        let outbox = outbox()
        try execute(
            """
            INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, created_at)
            VALUES ('later', 'entry.edit', 'later', X'7B7D', 0, '2026-10-21T08:00:04.200Z', 'pending', '2026-10-21T08:00:04.200Z')
            """
        )
        try await outbox.enqueueEntry(draft(a))

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a)])
        let row = try rowByID("later")
        #expect(row.status == .pending)
        #expect(row.attempts == 0)
    }

    // MARK: Triggers

    @Test("start drains when the phone is online and again when it comes back online")
    func startDrainsOnReachability() async throws {
        let reachability = StreamingReachability()
        let outbox = outbox(reachability: reachability)
        try await outbox.enqueueEntry(draft(a))

        await outbox.start()
        try await waitUntil { reachability.subscribers == 1 }
        reachability.send(true)
        try await waitUntil { sender.sends.count == 1 }
        try await outbox.enqueueEntry(draft(b))
        try await waitUntil { sender.sends.count == 2 }

        #expect(sender.sends.map(\.id) == [key(a), key(b)], "the launch value, then the write after start")
        reachability.send(false)
        let c = UUID()
        sender.script(key(c), [.failure(Backend.Failure(.offline))])
        try await outbox.enqueueEntry(draft(c))
        try await waitUntil { sender.sends.count == 3 }
        reachability.send(true)
        try await waitUntil { sender.sends.count == 4 }
        // the 4th send is counted when it starts; the row is marked done a moment later
        try await waitUntil { (try? item(c).status) == .done }
        #expect(try item(c).status == .done)
    }

    @Test("start is one-shot: a second start adds no second watcher")
    func startIsOneShot() async throws {
        let reachability = StreamingReachability()
        let outbox = outbox(reachability: reachability)
        try await outbox.enqueueEntry(draft(a))

        await outbox.start()
        await outbox.start()
        try await waitUntil { reachability.subscribers >= 1 }
        reachability.send(true)
        try await waitUntil { sender.sends.count == 1 }
        for _ in 0 ..< 50 {
            await Task.yield()
        }

        #expect(reachability.subscribers == 1)
    }

    // MARK: Privacy

    @Test("no outbox log line carries text, through sends, retries, deaths and pauses")
    func noOutboxLogLineCarriesText() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft(a))
        try await outbox.enqueueEntry(draft(b))
        sender.script(key(a), [.failure(Backend.Failure(.transport)), .failure(Backend.Failure(.invalidRequest, message: "the entry text"))])
        sender.script(key(b), [.failure(Backend.Failure(.offline))])
        await outbox.drain(reason: .manual)
        now.advance(seconds: 10)
        await outbox.drain(reason: .manual)

        for event in recorder.events {
            #expect(ContentCheck.values(in: event).isEmpty, "\(event) carries content")
        }
        #expect(recorder.events.count >= 5)
    }

    // MARK: Helpers

    private final class Seen: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var status: Store.OutboxStatus?
        private(set) var deadline: Date?
        private(set) var entryState: Store.SyncState?

        func set(status: Store.OutboxStatus, deadline: Date, entryState: Store.SyncState?) {
            lock.withLock {
                self.status = status
                self.deadline = deadline
                self.entryState = entryState
            }
        }
    }

    /// Yields until `condition` holds. No deadline of its own: the suite's
    /// time limit ends a wait that never comes true.
    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        while !condition() {
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

/// Reachability whose changes a test pushes by hand, counting subscribers.
final class StreamingReachability: Backend.Reachability, @unchecked Sendable {
    private let lock = NSLock()
    private var online = true
    private var continuations: [AsyncStream<Bool>.Continuation] = []

    var subscribers: Int {
        lock.withLock { continuations.count }
    }

    var isOnline: Bool {
        get async { lock.withLock { online } }
    }

    func changes() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            lock.withLock { continuations.append(continuation) }
        }
    }

    func send(_ value: Bool) {
        let targets = lock.withLock {
            online = value
            return continuations
        }
        targets.forEach { $0.yield(value) }
    }
}
