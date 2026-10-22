import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveBriefTests {
    typealias Slot = Flows.Journal.BriefSlot
    typealias Latest = Backend.Endpoints.BriefLatest.Latest

    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    /// A clock for the data seam and a "now" that moves with it.
    private final class Moment: @unchecked Sendable {
        private let lock = NSLock()
        private var date: Date

        init(_ date: Date) {
            self.date = date
        }

        var value: Date {
            lock.withLock { date }
        }

        func advance(_ seconds: TimeInterval) {
            lock.withLock { date = date.addingTimeInterval(seconds) }
        }
    }

    /// 2026-10-21 07:59 UTC: a minute before the fixture's `nextAt` (08:00).
    private let moment = Moment(Date(timeIntervalSince1970: 1_792_569_540))
    private let session = URLSession.stubbed()
    private let clock = TestClock()
    private let log = Platform.Log.Recorder()
    private let database: Store.LocalDatabase
    private let data: LiveJournalData

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let moment = moment
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: ManualReachability(), clock: TestClock(), log: log
        )
        self.database = database
        data = LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, now: { moment.value }, timeZone: { .gmt }),
            outbox: Store.Outbox(database: database, log: log), reachability: StreamingReachability(),
            now: { moment.value }, timeZone: { .gmt }, clock: clock
        )
    }

    private final class Answers: @unchecked Sendable {
        private let lock = NSLock()
        private var queue: [(Int, String, String)]
        private var count = 0

        init(_ queue: [(Int, String, String)]) {
            self.queue = queue
        }

        var briefRequests: Int {
            lock.withLock { count }
        }

        /// The next answer; the last repeats.
        func next() -> (Int, String, String) {
            lock.withLock {
                count += 1
                return queue.count > 1 ? queue.removeFirst() : queue[0]
            }
        }
    }

    /// Today answers with the fixture; the brief answers from `answers` in turn.
    @discardableResult
    private func serve(_ answers: [(status: Int, folder: String, fixture: String)]) -> Answers {
        let queue = Answers(answers.map { ($0.status, $0.folder, $0.fixture) })
        StubProtocol.register(on: session) { request in
            if request.url?.path == "/v2/briefs/latest" {
                let (status, folder, fixture) = queue.next()
                return try (HTTPURLResponse.stub(request, status: status), Fixtures.data(folder, fixture))
            }
            return try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", "entries.today.empty"))
        }
        return queue
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        while !condition() {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func latest(_ fixture: String) throws -> Latest {
        struct Envelope: Decodable { let data: Latest }
        return try Backend.Coding.decoder.decode(Envelope.self, from: Fixtures.data("02", fixture)).data
    }

    // MARK: The slot

    @Test("off, making, none, quiet and ready come from their fixtures at the person's day")
    func theFiveSlots() throws {
        let today = "2026-10-21"

        #expect(try Slot.derive(from: latest("brief.latest.off"), today: today) == .off)
        #expect(try Slot.derive(from: latest("brief.latest.none"), today: today) == .none)
        if case let .making(readyBy?) = try Slot.derive(from: latest("brief.latest.making"), today: today) {
            #expect(readyBy == Date(timeIntervalSince1970: 1_792_569_600))
        } else {
            Issue.record("expected making")
        }
        if case let .quiet(line) = try Slot.derive(from: latest("brief.latest.quiet"), today: today) {
            #expect(line.hasPrefix("nothing new"))
        } else {
            Issue.record("expected quiet")
        }
        if case let .ready(brief) = try Slot.derive(from: latest("brief.latest.v2"), today: today) {
            #expect(brief.parts.count == 2)
        } else {
            Issue.record("expected ready")
        }
    }

    @Test("a brief dated another day is making (or none), never ready")
    func yesterdaysBriefIsNotReady() throws {
        let slot = try Slot.derive(from: latest("brief.latest.v2"), today: "2026-10-22")

        #expect(slot == .making(readyBy: Date(timeIntervalSince1970: 1_792_656_000)))
        let none = try Latest(brief: latest("brief.latest.v2").brief, enabled: true, nextAt: nil)
        #expect(Slot.derive(from: none, today: "2026-10-22") == .none)
    }

    // MARK: Loading

    @Test("the brief loads, is kept, survives a failed refresh, and fails only when nothing is kept")
    func loadingAndKeeping() async {
        defer { StubProtocol.clear(session) }
        serve([(200, "02", "brief.latest.v2"), (500, "00", "error.internal")])
        await data.load()
        if case .ready? = data.brief.value {} else {
            Issue.record("expected ready, got \(data.brief)")
        }

        await data.load()

        if case .ready? = data.brief.value {} else {
            Issue.record("a failed refresh keeps what was kept, got \(data.brief)")
        }
    }

    @Test("with nothing kept, a failed brief load is failed")
    func nothingKept() async {
        defer { StubProtocol.clear(session) }
        serve([(500, "00", "error.internal")])

        await data.load()

        if case let .failed(failure) = data.brief {
            #expect(failure.kind == .server)
        } else {
            Issue.record("expected failed, got \(data.brief)")
        }
    }

    // MARK: Waiting for a brief being made

    @Test("while it's being made, the brief is looked for at the due time, then 2, 5, 10 and 15 minutes later, and then no more")
    func theWaitingSchedule() async throws {
        defer { StubProtocol.clear(session) }
        let answers = serve([(200, "02", "brief.latest.making")])
        await data.load()
        #expect(answers.briefRequests == 1)

        for (index, step) in [60.0, 120, 180, 300, 300].enumerated() {
            try await waitUntil { clock.pendingSleeps == 1 }
            moment.advance(step)
            clock.advance(by: .seconds(step))
            try await waitUntil { answers.briefRequests == index + 2 }
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(answers.briefRequests == 6)
        #expect(clock.pendingSleeps == 0, "after the fifth look it stops until the next load")
    }

    @Test("when the brief arrives the waiting ends and the slot is ready in place")
    func theBriefArrives() async throws {
        defer { StubProtocol.clear(session) }
        let answers = serve([(200, "02", "brief.latest.making"), (200, "02", "brief.latest.v2")])
        await data.load()

        try await waitUntil { clock.pendingSleeps == 1 }
        moment.advance(60)
        clock.advance(by: .seconds(60))
        try await waitUntil { answers.briefRequests == 2 }
        try await waitUntil {
            if case .ready? = data.brief.value {
                true
            } else {
                false
            }
        }

        #expect(clock.pendingSleeps == 0)
    }

    @Test("a rate-limited look ends the waiting, and stopping the data ends it too")
    func rateLimitAndStop() async throws {
        defer { StubProtocol.clear(session) }
        let answers = serve([(200, "02", "brief.latest.making"), (429, "00", "error.rate_limited")])
        await data.load()

        try await waitUntil { clock.pendingSleeps == 1 }
        moment.advance(60)
        clock.advance(by: .seconds(60))
        try await waitUntil { answers.briefRequests == 2 }
        try await Task.sleep(for: .milliseconds(50))
        #expect(clock.pendingSleeps == 0)
        await data.load()
        try await waitUntil { clock.pendingSleeps == 1 }

        data.stop()
        try await Task.sleep(for: .milliseconds(50))
        #expect(clock.pendingSleeps == 0)
    }
}
