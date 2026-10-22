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

    /// Full jitter is replaced by its ceiling, so delays are exact.
    private func outbox(reachability: (any Backend.Reachability)? = nil) -> Store.Outbox {
        let now = now
        return Store.Outbox(
            database: database, sender: sender, reachability: reachability, now: { now.value }, timeZone: { .gmt }, jitter: { $0 }, log: recorder
        )
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
