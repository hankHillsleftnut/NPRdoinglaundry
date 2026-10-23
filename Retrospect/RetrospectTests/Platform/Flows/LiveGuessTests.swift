import Foundation
import GRDB
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveGuessTests {
    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    private let guessID = "00000000-0000-4000-8000-000000000401"
    private let session = URLSession.stubbed()
    private let network = ManualReachability()
    private let log = Platform.Log.Recorder()
    private let database: Store.LocalDatabase
    private let data: LiveJournalData
    private let client: Backend.Client

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: network, clock: TestClock(), log: log
        )
        self.database = database
        self.client = client
        data = LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, timeZone: { .gmt }),
            outbox: Store.Outbox(database: database, log: log), reachability: StreamingReachability(), timeZone: { .gmt }
        )
    }

    private func makeData(outbox: Store.Outbox) throws -> LiveJournalData {
        LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, timeZone: { .gmt }),
            outbox: outbox, reachability: StreamingReachability(), timeZone: { .gmt }
        )
    }

    /// The guess list answers with `list`; an answer with `answer` (a status and a fixture).
    private func serve(list: String = "guesses", answer: (status: Int, folder: String, fixture: String) = (200, "02", "guess.answer")) {
        StubProtocol.register(on: session) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v2/guesses"):
                try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", list))
            case ("POST", _):
                try (HTTPURLResponse.stub(request, status: answer.status), Fixtures.data(answer.folder, answer.fixture))
            default:
                try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", "entries.today.empty"))
            }
        }
    }

    private func answerRequests() -> [URLRequest] {
        StubProtocol.requests(on: session).filter { $0.httpMethod == "POST" }
    }

    private func outboxRows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.fetchAll($0) }
    }

    private func offered() throws -> Flows.Journal.Guess {
        try #require(data.guesses.first)
    }

    @Test("the guess on offer is shown; while the server isn't speaking there are none, and the kept list is emptied")
    func speaking() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        await data.load()
        #expect(try offered().status == .offered)

        serve(list: "guesses.silent")
        await data.load()

        #expect(data.guesses.isEmpty)
    }

    @Test("an answer takes at once and is queued in the outbox with its verdict; nothing is sent around the outbox")
    func answeringQueues() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        await data.load()

        let outcome = try await data.answer(offered(), verdict: .yes)

        #expect(outcome == .queued)
        #expect(try offered().status == .confirmed)
        #expect(answerRequests().isEmpty, "no direct send with a throwaway key")
        let rows = try outboxRows()
        #expect(rows.count == 1)
        #expect(rows.first?.operation == .guessAnswer && rows.first?.entityID == guessID)
        let expected = try JSONSerialization.jsonObject(with: Fixtures.data("02", "guess.answer.request")) as? NSDictionary
        let stored = try JSONSerialization.jsonObject(with: #require(rows.first?.payload)) as? NSDictionary
        #expect(stored == expected)
    }

    @Test("offline the answer shows at once and survives a refresh that still offers the guess")
    func answeringOffline() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        await data.load()
        network.set(online: false)

        let outcome = try await data.answer(offered(), verdict: .no)
        await data.load()

        #expect(outcome == .queued)
        #expect(try outboxRows().count == 1)
        #expect(try offered().status == .declined, "the queued answer wins over the server's list")
    }

    @Test("a retried answer carries the same idempotency key every time: the id stored with the answer")
    func theKeyIsStoredWithTheAnswer() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        let sender = ScriptedSender()
        let outbox = Store.Outbox(database: database, sender: sender, jitter: { $0 }, sleep: { _ in }, log: log)
        let live = try makeData(outbox: outbox)
        await live.load()
        let guess = try #require(live.guesses.first)

        _ = await live.answer(guess, verdict: .yes)
        let key = try #require(try outboxRows().first?.id)
        sender.script(key, [.failure(Backend.Failure(.transport)), .failure(Backend.Failure(.transport))])
        await outbox.drain(reason: .manual)
        try await database.writer.write { try $0.execute(sql: "UPDATE outbox SET next_attempt_at = '2000-01-01T00:00:00.000Z'") }
        await outbox.drain(reason: .manual)
        try await database.writer.write { try $0.execute(sql: "UPDATE outbox SET next_attempt_at = '2000-01-01T00:00:00.000Z'") }
        await outbox.drain(reason: .manual)

        #expect(sender.sends.map(\.id) == [key, key, key], "three attempts, one key")
    }

    @Test("a refused answer (dead in the outbox) is no longer applied: the guess is offered again")
    func aRefusedAnswerIsOfferedAgain() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        let sender = ScriptedSender()
        let outbox = Store.Outbox(database: database, sender: sender, log: log)
        let live = try makeData(outbox: outbox)
        await live.load()
        let guess = try #require(live.guesses.first)
        _ = await live.answer(guess, verdict: .yes)
        let key = try #require(try outboxRows().first?.id)
        sender.script(key, [.failure(Backend.Failure(.notFound))])

        await outbox.drain(reason: .manual)
        await live.load()

        #expect(try outboxRows().first?.status == .dead)
        #expect(live.guesses.first?.status == .offered)
    }
}
