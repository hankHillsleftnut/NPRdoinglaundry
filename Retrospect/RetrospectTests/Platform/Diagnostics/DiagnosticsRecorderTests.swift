import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct DiagnosticsRecorderTests {
    typealias Diagnostics = Platform.Diagnostics
    typealias Recorder = Platform.Diagnostics.Recorder

    /// A clock the test moves by hand.
    private final class Now: @unchecked Sendable {
        private let lock = NSLock()
        private var date = Date(timeIntervalSince1970: 1_792_569_604.2)

        var value: Date {
            lock.withLock { date }
        }

        func advance(seconds: TimeInterval) {
            lock.withLock { date = date.addingTimeInterval(seconds) }
        }
    }

    private let database: Store.LocalDatabase
    private let log = Platform.Log.Recorder()
    private let now = Now()
    private let clock = TestClock()

    init() throws {
        database = try Store.LocalDatabase.inMemory()
    }

    private func recorder(attached: Bool = true) -> Recorder {
        let now = now
        return Recorder(database: attached ? database : nil, now: { now.value }, clock: clock, log: log)
    }

    /// Synchronous reads: in an async test, `writer.read` picks GRDB's async overload.
    private func rows(_ ring: Diagnostics.Ring, in database: Store.LocalDatabase? = nil) throws -> [Store.DiagnosticRow] {
        try (database ?? self.database).writer.read { try Store.DiagnosticRow.inRing(ring).fetchAll($0) }
    }

    private func count(_ ring: Diagnostics.Ring) throws -> Int {
        try database.writer.read { try Store.DiagnosticRow.inRing(ring).fetchCount($0) }
    }

    private func execute(_ sql: String) throws {
        try database.writer.write { try $0.execute(sql: sql) }
    }

    /// The scheduled flush registers its sleep on a task of its own; wait for
    /// it before moving the clock, or the sleep would start after the move.
    private func waitForSleep() async throws {
        for _ in 0 ..< 10000 where clock.pendingSleeps == 0 {
            await Task.yield()
        }
        try #require(clock.pendingSleeps == 1)
    }

    private func event(_ event: Diagnostics.Event) throws -> Data {
        try Recorder.encode(.event(event))
    }

    // MARK: Recording

    @Test("records land in their rings in order, stamped with the time they were recorded")
    func recordsLandInOrder() async throws {
        let recorder = recorder()

        await recorder.record(.event(.appLaunch))
        now.advance(seconds: 1.5)
        await recorder.record(.event(.screenShown(.journal)))
        await recorder.record(.request(.init(method: .get, route: .meta, status: 200, ms: 40)))
        await recorder.flush()

        let events = try rows(.events)
        #expect(try events.map(\.payload) == [event(.appLaunch), event(.screenShown(.journal))])
        let expectedAt = [Date(timeIntervalSince1970: 1_792_569_604.2), Date(timeIntervalSince1970: 1_792_569_605.7)]
        #expect(zip(events.map(\.at), expectedAt).allSatisfy { abs($0.timeIntervalSince($1)) < 0.001 })
        #expect(try count(.network) == 1)
        #expect(try rows(.network).first?.payload == Recorder.encode(.request(.init(method: .get, route: .meta, status: 200, ms: 40))))
    }

    @Test("a record waits for the flush delay, then lands")
    func aRecordWaitsForTheFlushDelay() async throws {
        let recorder = recorder()

        await recorder.record(.event(.appForeground))
        #expect(try count(.events) == 0)

        try await waitForSleep()
        clock.advance(by: Recorder.flushAfter)
        await recorder.waitForScheduledFlush()
        #expect(try count(.events) == 1)
    }

    @Test("a full batch lands at once, without waiting for the delay")
    func aFullBatchLandsAtOnce() async throws {
        let recorder = recorder()

        for _ in 0 ..< (Recorder.batchSize - 1) {
            await recorder.record(.event(.appForeground))
        }
        #expect(try count(.events) == 0)
        await recorder.record(.event(.appBackground))

        #expect(try count(.events) == Recorder.batchSize)
        #expect(clock.pendingSleeps == 0, "the scheduled flush is cancelled once the batch has landed")
    }

    @Test("rows reads a ring oldest first, after landing what's waiting")
    func rowsReadsARingAfterFlushing() async throws {
        let recorder = recorder()
        await recorder.record(.failure(.init(code: .network, screen: .brief)))
        await recorder.record(.failure(.init(code: .server)))

        let failures = try await recorder.rows(in: .failures)

        #expect(try failures.map(\.payload) == [
            Recorder.encode(.failure(.init(code: .network, screen: .brief))),
            Recorder.encode(.failure(.init(code: .server))),
        ])
        #expect(failures.map(\.id) == failures.map(\.id).sorted { ($0 ?? 0) < ($1 ?? 0) })
    }

    // MARK: The rings

    @Test("each ring keeps only its newest cap rows, and one ring filling never evicts another")
    func eachRingKeepsItsNewestCapRows() async throws {
        let recorder = recorder()
        await recorder.record(.crash(.init(kind: .crash)))
        for _ in 0 ..< (Diagnostics.Ring.failures.cap + 3) {
            await recorder.record(.failure(.init(code: .network)))
        }
        await recorder.flush()

        #expect(try count(.failures) == Diagnostics.Ring.failures.cap)
        #expect(try count(.crashes) == 1)
        let oldestKept = try #require(try rows(.failures).first?.id)
        #expect(oldestKept == 5, "the first three failures (ids 2, 3, 4, after the crash's 1) are gone")
    }

    @Test("a 7-day bundle can never exceed the server's caps: every ring is capped at them")
    func theRingsAreCappedAtTheServersCaps() {
        #expect(Diagnostics.Ring.events.cap == 2000)
        #expect(Diagnostics.Ring.network.cap == 2000)
        #expect(Diagnostics.Ring.failures.cap == 500)
        #expect(Diagnostics.Ring.crashes.cap == 100)
    }

    @Test("rows older than seven days are dropped when a batch lands")
    func oldRowsAreDroppedOnFlush() async throws {
        let recorder = recorder()
        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        now.advance(seconds: Recorder.retention + 1)
        await recorder.record(.event(.appForeground))
        await recorder.flush()

        #expect(try rows(.events).map(\.payload) == [event(.appForeground)])
    }

    @Test("rows older than seven days are dropped when the database is attached, before anything new lands")
    func oldRowsAreDroppedOnAttach() async throws {
        let first = recorder()
        await first.record(.event(.appLaunch))
        await first.flush()
        now.advance(seconds: Recorder.retention + 1)

        let next = recorder(attached: false)
        await next.attach(database)

        #expect(try count(.events) == 0)
    }

    @Test("a row exactly at the edge of the window stays")
    func aRowAtTheEdgeStays() async throws {
        let recorder = recorder()
        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        now.advance(seconds: Recorder.retention)
        await recorder.flush()
        await recorder.record(.event(.appForeground))
        await recorder.flush()

        #expect(try count(.events) == 2)
    }

    // MARK: Before sign-in

    @Test("records made before the database is attached land when it is, in order")
    func recordsBeforeAttachLandOnAttach() async throws {
        let recorder = recorder(attached: false)
        await recorder.record(.event(.appLaunch))
        await recorder.record(.event(.screenShown(.signIn)))
        #expect(clock.pendingSleeps == 0, "nothing is scheduled without a database")
        #expect(try count(.events) == 0)

        await recorder.attach(database)

        #expect(try rows(.events).map(\.payload) == [event(.appLaunch), event(.screenShown(.signIn))])
    }

    @Test("while detached, each ring keeps only its newest cap records in memory, and one ring's flood never evicts another's")
    func whileDetachedEachRingKeepsItsNewest() async throws {
        let recorder = recorder(attached: false)
        await recorder.record(.crash(.init(kind: .crash)))
        await recorder.record(.event(.appLaunch))
        for _ in 0 ..< Diagnostics.Ring.events.cap {
            await recorder.record(.event(.appForeground))
        }

        await recorder.attach(database)

        let events = try rows(.events)
        #expect(events.count == Diagnostics.Ring.events.cap)
        #expect(try !events.map(\.payload).contains(event(.appLaunch)), "the oldest event was dropped from memory")
        #expect(try count(.crashes) == 1, "the crash survived the flood of events")
    }

    // MARK: Failures

    @Test("a write that fails is logged as a count and its batch kept for the next flush, in order")
    func aFailedWriteIsLoggedAndRetried() async throws {
        let recorder = recorder()
        try execute("DROP TABLE diagnostics")

        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        #expect(log.events == [.diagnosticsWriteFailed])
        try execute("CREATE TABLE diagnostics (id INTEGER PRIMARY KEY AUTOINCREMENT, ring TEXT NOT NULL, at TEXT NOT NULL, payload BLOB NOT NULL)")
        await recorder.record(.event(.appForeground))
        await recorder.flush()
        #expect(try rows(.events).map(\.payload) == [event(.appLaunch), event(.appForeground)])
        #expect(log.events == [.diagnosticsWriteFailed])
    }

    @Test("a batch kept after a failed write is bounded like the queue: the newest pendingCap")
    func aKeptBatchIsBounded() async throws {
        let recorder = recorder()
        try execute("DROP TABLE diagnostics")
        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        for _ in 0 ..< Recorder.pendingCap {
            await recorder.record(.event(.appForeground))
        }
        try execute("CREATE TABLE diagnostics (id INTEGER PRIMARY KEY AUTOINCREMENT, ring TEXT NOT NULL, at TEXT NOT NULL, payload BLOB NOT NULL)")
        await recorder.flush()

        #expect(try count(.events) == Diagnostics.Ring.events.cap)
        #expect(try !rows(.events).map(\.payload).contains(event(.appLaunch)), "the oldest was dropped from memory")
    }

    // MARK: Sign-out

    @Test("a record made before sign-out never lands in the next person's rings")
    func aRecordBeforeSignOutNeverReachesTheNextPerson() async throws {
        let recorder = recorder()
        let next = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        await recorder.record(.event(.screenShown(.journal)))

        await recorder.detach()
        await recorder.record(.event(.appBackground))
        await recorder.attach(next)
        await recorder.flush()

        #expect(try rows(.events).map(\.payload) == [event(.screenShown(.journal))], "this person's row landed in their own database")
        #expect(try rows(.events, in: next).map(\.payload) == [event(.appBackground)], "only what happened after sign-out reaches the next person")
        #expect(try await recorder.rows(in: .events).map(\.payload) == [event(.appBackground)])
    }

    @Test("a record that couldn't be written before sign-out is forgotten, never carried to the next person")
    func anUnwrittenRecordBeforeSignOutIsForgotten() async throws {
        let recorder = recorder()
        let next = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        try execute("DROP TABLE diagnostics")
        await recorder.record(.event(.screenShown(.journal)))

        await recorder.detach()
        await recorder.attach(next)
        await recorder.flush()

        #expect(log.events == [.diagnosticsWriteFailed])
        #expect(try rows(.events, in: next).isEmpty)
    }

    @Test("a request that started before sign-out is dropped when it ends after it; one that started after is kept for the next person")
    func aRequestFromBeforeSignOutIsDropped() async throws {
        let recorder = recorder()
        let next = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        let late = Diagnostics.Record.request(.init(method: .get, route: .entriesToday, status: 200, ms: 0))
        let fresh = Diagnostics.Record.request(.init(method: .post, route: .authApple, status: 200, ms: 0))
        let before = recorder.generation

        await recorder.detach()
        let after = recorder.generation
        await recorder.record(late, startedIn: before)
        await recorder.record(fresh, startedIn: after)
        await recorder.attach(next)
        await recorder.flush()

        #expect(after != before, "sign-out moves the generation on")
        let landed = try rows(.network, in: next).map { try Backend.Coding.decoder.decode(Diagnostics.Request.self, from: $0.payload) }
        #expect(landed.map(\.route) == [.authApple], "only the request that started after sign-out")
        #expect(recorder.generation == after, "signing in doesn't move it: the sign-in request belongs to the next person")
    }

    @Test("after detach nothing is written anywhere until the next attach")
    func afterDetachNothingIsWritten() async throws {
        let recorder = recorder()
        await recorder.detach()

        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        #expect(try count(.events) == 0)
        #expect(clock.pendingSleeps == 0)
    }

    // MARK: Reading

    @Test("rows after seven days with nothing pending returns none, so a quiet recorder never hands over old rows")
    func rowsAfterSevenDaysWithNothingPendingReturnsNone() async throws {
        let recorder = recorder()
        await recorder.record(.event(.appLaunch))
        await recorder.flush()

        now.advance(seconds: Recorder.retention + 1)

        #expect(try await recorder.rows(in: .events).isEmpty)
        #expect(try count(.events) == 1, "the row stays until the next write prunes it; it just isn't handed over")
    }

    @Test("erase empties the rings with everything else")
    func eraseEmptiesTheRings() async throws {
        let recorder = recorder()
        await recorder.record(.crash(.init(kind: .hang)))
        await recorder.flush()

        try database.erase()

        #expect(try count(.crashes) == 0)
    }
}
