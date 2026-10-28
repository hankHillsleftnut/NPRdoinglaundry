import Foundation
import GRDB
@testable import Retrospect
import Testing

/// FR.b1.data: first-run answers through the outbox. Kept and queued in one write, sent once with the
/// same key however often they are tried, counted as unsent words; `complete` is one row that goes only
/// after every answer has gone out or been refused, and hands the door's access state back.
@Suite(.timeLimit(.minutes(1)))
struct OutboxOnboardingTests {
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
    private let a1 = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1") ?? UUID()
    private let a2 = UUID(uuidString: "00000000-0000-4000-8000-0000000000a2") ?? UUID()
    private let complete = Store.Outbox.completeID

    init() throws {
        database = try Store.LocalDatabase.inMemory()
    }

    /// Jitter replaced by its ceiling; the retry timer never fires on its own (the test drains by hand).
    private func outbox(
        sender: (any Store.OutboxSending)? = nil,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) -> Store.Outbox {
        let now = now
        return Store.Outbox(
            database: database, sender: sender ?? self.sender, now: { now.value }, timeZone: { .gmt }, jitter: { $0 }, pick: { _ in 0 },
            sleep: sleep, log: recorder
        )
    }

    private func key(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    private func row(_ id: String) throws -> Store.OutboxRow {
        try #require(try database.writer.read { try Store.OutboxRow.fetchOne($0, key: id) })
    }

    private func rows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.order(Column("created_at"), Column.rowID).fetchAll($0) }
    }

    private func answers() throws -> [Store.FirstRunAnswerRow] {
        try database.writer.read { try Store.FirstRunAnswerRow.order(Column("key")).fetchAll($0) }
    }

    @discardableResult
    private func enqueue(_ outbox: Store.Outbox, _ id: UUID, key: Flows.QuestionKey = .namePlace, text: String = "sam, in london.") async throws -> UUID {
        try await outbox.enqueueAnswer(key: key, doorKey: .namePlace, text: text, given: .typed, createdAt: Date(timeIntervalSince1970: 1_792_569_000), id: id)
    }

    // MARK: The rows

    @Test("an answer is kept and queued in one write: the words row, and an onboarding.answer row keyed by the answer's id")
    func anAnswerIsKeptAndQueued() async throws {
        let outbox = outbox()

        let id = try await enqueue(outbox, a1)

        #expect(id == a1)
        let item = try row(key(a1))
        #expect(item.operation == .onboardingAnswer)
        #expect(item.entityID == key(a1))
        #expect(item.status == .pending)
        let body = try Backend.Coding.decoder.decode(Backend.Endpoints.OnboardingAnswer.Body.self, from: item.payload)
        #expect(body == Backend.Endpoints.OnboardingAnswer.Body(
            questionKey: .namePlace, text: "sam, in london.", given: .typed, clientEntryID: a1, createdAt: Date(timeIntervalSince1970: 1_792_569_000)
        ))
        #expect(try answers() == [Store.FirstRunAnswerRow(key: "name.place", text: "sam, in london.", createdAt: Date(timeIntervalSince1970: 1_792_569_000))])
        #expect(try await outbox.firstRunAnswers() == [.namePlace: "sam, in london."])
        #expect(recorder.events.contains(.outbox(.enqueued(operation: .onboardingAnswer))))
    }

    @Test("the queued bytes are the contract's request (fixture 01/answer.create.request), field for field")
    func theQueuedBytesAreTheFixture() async throws {
        let outbox = outbox()
        let fixture = try Fixtures.data("01", "answer.create.request")
        let expected = try Backend.Coding.decoder.decode(Backend.Endpoints.OnboardingAnswer.Body.self, from: fixture)

        try await outbox.enqueueAnswer(
            key: .namePlace, doorKey: .namePlace, text: "sam, in london.", given: .voice, createdAt: expected.createdAt,
            id: #require(UUID(uuidString: expected.clientEntryId))
        )

        let item = try row(expected.clientEntryId)
        #expect(try item.payload == (Backend.Coding.encoder.encode(expected)))
        let queued = try #require(JSONSerialization.jsonObject(with: item.payload) as? NSDictionary)
        #expect(try queued == (JSONSerialization.jsonObject(with: fixture) as? NSDictionary))
    }

    @Test("answering a question again replaces the kept words and queues a second row; the first row is untouched")
    func answeringAgainReplacesTheWords() async throws {
        let outbox = outbox()
        try await enqueue(outbox, a1, text: "sam.")

        try await enqueue(outbox, a2, text: "sam, in london.")

        #expect(try answers().map(\.text) == ["sam, in london."])
        #expect(try rows().map(\.id) == [key(a1), key(a2)])
        #expect(try row(key(a1)).status == .pending)
    }

    @Test("if the outbox row can't be written, the words aren't kept either (one transaction)")
    func neitherRowWithoutTheOther() async throws {
        let outbox = outbox()
        try await database.writer.write { try $0.execute(sql: "DROP TABLE outbox") }

        await #expect(throws: (any Error).self) { try await enqueue(outbox, a1) }

        #expect(try answers().isEmpty)
    }

    @Test("complete is one fixed row: queued once, a repeat changes nothing, a refused one goes back in the queue")
    func completeIsOneRow() async throws {
        let outbox = outbox()

        #expect(try await outbox.enqueueComplete() == true)
        #expect(try await outbox.enqueueComplete() == false)

        let item = try row(complete)
        #expect(item.operation == .onboardingComplete)
        #expect(item.payload == Data("{}".utf8))
        #expect(try rows().count == 1)
        try await database.writer.write {
            try $0.execute(sql: "UPDATE outbox SET status = 'dead', attempts = 3, last_error_code = 'internal' WHERE id = ?", arguments: [complete])
        }
        #expect(try await outbox.enqueueComplete() == true)
        let requeued = try row(complete)
        #expect(requeued.status == .pending)
        #expect(requeued.attempts == 0)
        #expect(requeued.lastErrorCode == nil)
        #expect(recorder.events.filter { $0 == .outbox(.enqueued(operation: .onboardingComplete)) }.count == 2)
    }

    @Test("v5 is additive: a v4 store with rows migrates, keeps every row, and gains an empty first_run_answers table")
    func v5IsAdditive() throws {
        let queue = try DatabaseQueue()
        try Store.Migrations.all.migrate(queue, upTo: "v4")
        try queue.write { db in
            try db.execute(sql: """
            INSERT INTO outbox (id, operation, entity_id, payload, next_attempt_at, status, created_at)
            VALUES ('o1', 'entry.create', 'e1', x'7B7D', '2026-10-21T08:00:00.000Z', 'pending', '2026-10-21T08:00:00.000Z')
            """)
            try db.execute(sql: "INSERT INTO flags (key, value, set_at) VALUES ('youre_in_seen', '1', '2026-10-21T08:00:00.000Z')")
        }
        #expect(try queue.read { try $0.tableExists("first_run_answers") } == false)

        try Store.Migrations.all.migrate(queue)

        #expect(try queue.read { try $0.tableExists("first_run_answers") })
        let counts: [Int?] = try queue.read { db in
            try ["outbox", "flags", "first_run_answers"].map { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \($0)") }
        }
        #expect(counts == [1, 1, 0])
        // a data table: erase empties it with the rest
        let tables = try queue.read { try Store.LocalDatabase.dataTables($0) }
        #expect(tables.contains("first_run_answers"))
    }

    @Test("Log Out's erase clears the kept words with everything else")
    func eraseClearsTheWords() async throws {
        let outbox = outbox()
        try await enqueue(outbox, a1)

        try database.erase()

        #expect(try answers().isEmpty)
        #expect(try rows().isEmpty)
    }

    // MARK: Counting

    @Test("answers count as unsent words (Log Out asks); complete does not")
    func answersCountAsUnsentCompleteDoesNot() async throws {
        let outbox = outbox()
        try await enqueue(outbox, a1)
        try await outbox.enqueueComplete()

        #expect(try await outbox.unsentCount() == 1)
        #expect(try await outbox.waitingToSendCount() == 2, "the drain still has both to send")
    }

    // MARK: Sending

    @Test("an answer goes out with its own id as the key and the stored bytes; the row is done and the words stay")
    func anAnswerIsSentOnce() async throws {
        let outbox = outbox()
        try await enqueue(outbox, a1)

        await outbox.drain(reason: .manual)

        let send = try #require(sender.sends.first)
        #expect(send.id == key(a1))
        #expect(try send.payload == (row(key(a1)).payload))
        #expect(sender.sends.count == 1)
        #expect(try row(key(a1)).status == .done)
        #expect(try answers().count == 1)
        #expect(recorder.events.contains(.outbox(.sent(operation: .onboardingAnswer, attempts: 1, ms: 0))))
        await outbox.drain(reason: .manual)
        #expect(sender.sends.count == 1, "sent once, ever")
    }

    @Test("a send lost to a crash (in flight past its deadline) goes out again with the same key and bytes: the door keeps one answer")
    func aCrashedSendIsRepeatedWithTheSameKey() async throws {
        let outbox = outbox()
        try await enqueue(outbox, a1)
        let payload = try row(key(a1)).payload
        try await database.writer.write {
            try $0.execute(
                sql: "UPDATE outbox SET status = ?, next_attempt_at = ? WHERE id = ?",
                arguments: [Store.OutboxStatus.inFlight.rawValue, Backend.Coding.timestamp(now.value.addingTimeInterval(-1)), key(a1)]
            )
        }

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a1)])
        #expect(sender.sends.first?.payload == payload)
        #expect(try row(key(a1)).status == .done)
    }

    @Test("offline, the answer waits (no attempt counted) and goes out when the phone is back; nothing is lost")
    func offlineThenOnline() async throws {
        let outbox = outbox()
        sender.script(key(a1), [.failure(Backend.Failure(.offline))])
        try await enqueue(outbox, a1)

        await outbox.drain(reason: .manual)

        #expect(try row(key(a1)).status == .pending)
        #expect(try row(key(a1)).attempts == 0)
        #expect(try await outbox.unsentCount() == 1)
        await outbox.drain(reason: .reachability)
        #expect(try row(key(a1)).status == .done)
        #expect(sender.sends.map(\.id) == [key(a1), key(a1)])
    }

    @Test("complete waits while an answer is retrying, then goes once the answer has landed")
    func completeWaitsForTheAnswers() async throws {
        let outbox = outbox()
        sender.script(key(a1), [.failure(Backend.Failure(.upstreamUnavailable))])
        try await enqueue(outbox, a1)
        try await enqueue(outbox, a2)
        try await outbox.enqueueComplete()

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a1), key(a2)], "complete did not go")
        #expect(try row(key(a1)).status == .pending)
        #expect(try row(key(a2)).status == .done)
        #expect(try row(complete).status == .pending)
        #expect(try row(complete).attempts == 0, "held, not tried")

        now.advance(seconds: 10) // past the first retry's wait
        await outbox.drain(reason: .retryTimer)

        #expect(sender.sends.map(\.id) == [key(a1), key(a2), key(a1), complete])
        #expect(try row(complete).status == .done)
    }

    @Test("a server outage never kills an answer: six 503s, then it lands, and complete goes only after it (the attempt limit is for entries)")
    func anOutageNeverKillsAnAnswer() async throws {
        let outbox = outbox()
        sender.script(key(a1), Array(repeating: .failure(Backend.Failure(.upstreamUnavailable)), count: 6))
        try await enqueue(outbox, a1)
        try await outbox.enqueueComplete()

        for _ in 0 ..< 6 {
            await outbox.drain(reason: .retryTimer)
            now.advance(seconds: 400) // past the backoff cap (5 min)
        }

        let item = try row(key(a1))
        #expect(item.status == .pending, "past the entry limit of 5, still waiting")
        #expect(item.attempts == 6)
        #expect(try row(complete).status == .pending)
        #expect(sender.sends.map(\.id) == Array(repeating: key(a1), count: 6), "complete never went")
        #expect(!recorder.events.contains {
            if case .outbox(.dead) = $0 {
                true
            } else {
                false
            }
        })

        await outbox.drain(reason: .retryTimer)

        #expect(try row(key(a1)).status == .done)
        #expect(try row(complete).status == .done)
        #expect(sender.sends.map(\.id).suffix(2) == [key(a1), complete])
    }

    @Test("a 503 burst on complete leaves it pending, not dead, and it lands later")
    func anOutageNeverKillsComplete() async throws {
        let outbox = outbox()
        sender.script(complete, Array(repeating: .failure(Backend.Failure(.internal)), count: 7))
        try await outbox.enqueueComplete()

        for _ in 0 ..< 7 {
            await outbox.drain(reason: .retryTimer)
            now.advance(seconds: 400)
        }

        #expect(try row(complete).status == .pending)
        #expect(try row(complete).attempts == 7)
        await outbox.drain(reason: .retryTimer)
        #expect(try row(complete).status == .done)
        #expect(sender.sends.count == 8)
    }

    @Test("the retry timer also wakes for an in-flight row's crash deadline, so a held complete isn't left to the next trigger")
    func theWakeCoversAnInFlightDeadline() async throws {
        let waits = Platform.Box<[TimeInterval]>([])
        let outbox = outbox(sender: sender, sleep: { seconds in
            waits.value.append(seconds)
            try await Task.sleep(for: .seconds(3600))
        })
        try await enqueue(outbox, a1)
        try await database.writer.write {
            try $0.execute(
                sql: "UPDATE outbox SET status = ?, next_attempt_at = ? WHERE id = ?",
                arguments: [Store.OutboxStatus.inFlight.rawValue, Backend.Coding.timestamp(now.value.addingTimeInterval(90)), key(a1)]
            )
        }
        try await outbox.enqueueComplete()
        await outbox.start() // one drain, the launch one; its wake records the wait it asks for

        for _ in 0 ..< 500 where waits.value.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sender.sends.isEmpty, "the answer is still in flight, complete is held")
        #expect(await outbox.retryWakeArmed)
        #expect(waits.value == [90])
        await outbox.stop()
    }

    @Test("a refused answer (dead) does not hold complete: it goes, and the answer stays visible as refused")
    func aDeadAnswerDoesNotHoldComplete() async throws {
        let outbox = outbox()
        sender.script(key(a1), [.failure(Backend.Failure(.invalidRequest))])
        try await enqueue(outbox, a1)
        try await outbox.enqueueComplete()

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a1), complete])
        #expect(try row(key(a1)).status == .dead)
        #expect(try row(complete).status == .done)
        #expect(try await outbox.unsentCount() == 1, "the refused answer still counts as unsent words")
        #expect(recorder.events.contains(.outbox(.dead(operation: .onboardingAnswer, code: .invalidRequest))))
    }

    @Test("complete queued before the answers still goes after them: the rule is by state, not by order")
    func completeQueuedFirstStillWaits() async throws {
        let outbox = outbox()
        try await outbox.enqueueComplete()
        now.advance(seconds: 1)
        try await enqueue(outbox, a1)

        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key(a1), complete])
    }

    @Test("when complete lands, the door's access state reaches whoever listens; isCompleteSent says so for a later launch")
    func completePublishesAccess() async throws {
        let outbox = outbox()
        sender.script(complete, [.success(Store.OutboxSendResult(access: .member))])
        try await outbox.enqueueComplete()
        let stream = await outbox.completions()
        #expect(try await outbox.isCompleteSent() == false)

        await outbox.drain(reason: .manual)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .member)
        #expect(try await outbox.isCompleteSent())
    }

    @Test("stopped mid-send (sign-out), the answer goes back to pending and nothing is sent after")
    func stopMidSendKeepsTheRow() async throws {
        let outbox = outbox()
        let gate = Gate()
        sender.gate = gate
        try await enqueue(outbox, a1)
        let drain = Task { await outbox.drain(reason: .manual) }
        while sender.sends.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }

        await outbox.stop()
        gate.open()
        await drain.value

        #expect(try row(key(a1)).status == .pending)
        #expect(sender.sends.count == 1)
    }

    @Test("no answer's words reach the log: every outbox event the answers cause is content-free")
    func nothingInTheLogCarriesWords() async throws {
        let outbox = outbox()
        sender.script(key(a2), [.failure(Backend.Failure(.invalidRequest))])
        try await enqueue(outbox, a1, text: "a secret only the person wrote")
        try await enqueue(outbox, a2, key: .careMost, text: "another secret")
        try await outbox.enqueueComplete()

        await outbox.drain(reason: .manual)

        #expect(recorder.events.count >= 5)
        for event in recorder.events {
            let strings = ContentCheck.values(in: event).compactMap { $0 as? String }
            #expect(!strings.contains { $0.contains("secret") }, "\(event) carries the person's words")
        }
    }

    @Test("the drain rule itself: complete waits only for answers that are pending or in flight")
    func theRule() {
        let at = Date(timeIntervalSince1970: 1_792_569_604)
        func row(_ operation: Store.OutboxOperation, _ status: Store.OutboxStatus) -> Store.OutboxRow {
            Store.OutboxRow(id: UUID().uuidString, operation: operation, entityID: "e", payload: Data(), nextAttemptAt: at, status: status, createdAt: at)
        }
        let complete = row(.onboardingComplete, .pending)
        #expect(Store.Outbox.waitsForAnswers(complete, among: [complete, row(.onboardingAnswer, .pending)]))
        #expect(Store.Outbox.waitsForAnswers(complete, among: [complete, row(.onboardingAnswer, .inFlight)]))
        #expect(!Store.Outbox.waitsForAnswers(complete, among: [complete, row(.onboardingAnswer, .dead)]))
        #expect(!Store.Outbox.waitsForAnswers(complete, among: [complete, row(.onboardingAnswer, .done)]))
        #expect(!Store.Outbox.waitsForAnswers(complete, among: [complete, row(.entryCreate, .pending)]), "an entry is not an answer")
        #expect(!Store.Outbox.waitsForAnswers(row(.onboardingAnswer, .pending), among: [row(.onboardingAnswer, .pending)]), "answers never wait")
        // decided after the pass's answers: held by one this pass sends → another pass; held by one waiting for its retry → no spin
        let cutoff = Backend.Coding.timestamp(at)
        let sending = row(.onboardingAnswer, .pending)
        let held = Store.Outbox.completeToSend(among: [complete, sending], cutoff: cutoff, sendingNow: [sending.entityID])
        #expect(held.send.isEmpty && held.anotherPass)
        let waiting = Store.Outbox.completeToSend(among: [complete, sending], cutoff: cutoff, sendingNow: [])
        #expect(waiting.send.isEmpty && !waiting.anotherPass)
        let free = Store.Outbox.completeToSend(among: [complete, row(.onboardingAnswer, .dead)], cutoff: cutoff, sendingNow: [])
        #expect(free.send == [complete] && !free.anotherPass)
        var later = complete
        later.nextAttemptAt = at.addingTimeInterval(60)
        #expect(Store.Outbox.completeToSend(among: [later], cutoff: cutoff, sendingNow: []).send.isEmpty, "not due yet")
    }
}
