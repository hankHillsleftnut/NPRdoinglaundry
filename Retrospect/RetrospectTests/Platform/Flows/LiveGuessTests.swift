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

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: network, clock: TestClock(), log: log
        )
        self.database = database
        data = LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, timeZone: { .gmt }),
            outbox: Store.Outbox(database: database, log: log), reachability: StreamingReachability(), timeZone: { .gmt }
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

    @Test("an answer takes at once, goes to the server once with its verdict and a key, and the outbox is left alone")
    func answeringOnline() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        await data.load()

        let outcome = try await data.answer(offered(), verdict: .yes)

        #expect(outcome == .recorded(.confirmed))
        #expect(try offered().status == .confirmed)
        let posts = answerRequests()
        #expect(posts.count == 1)
        #expect(posts.first?.url?.path == "/v2/guesses/\(guessID)")
        let sent = try JSONSerialization.jsonObject(with: #require(posts.first?.httpBody)) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Fixtures.data("02", "guess.answer.request")) as? NSDictionary
        #expect(sent == expected)
        #expect(posts.first?.value(forHTTPHeaderField: "Idempotency-Key") != nil)
        #expect(try outboxRows().isEmpty)
    }

    @Test("offline the answer is queued once, shows at once, and survives a refresh that still offers the guess")
    func answeringOffline() async throws {
        defer { StubProtocol.clear(session) }
        serve()
        await data.load()
        network.set(online: false)

        let outcome = try await data.answer(offered(), verdict: .no)
        await data.load()

        #expect(outcome == .queued)
        let rows = try outboxRows()
        #expect(rows.count == 1)
        #expect(rows.first?.operation == .guessAnswer)
        #expect(rows.first?.entityID == guessID)
        #expect(try offered().status == .declined, "the queued answer wins over the server's list")
        #expect(answerRequests().isEmpty)
    }

    @Test("a guess that isn't there any more is put back, and the outbox gets nothing")
    func aRefusalReverts() async throws {
        defer { StubProtocol.clear(session) }
        serve(answer: (404, "00", "error.not_found"))
        await data.load()

        let outcome = try await data.answer(offered(), verdict: .yes)

        #expect(outcome == .failed(Flows.Failure(.notFound)))
        #expect(try offered().status == .offered)
        #expect(try outboxRows().isEmpty)
    }

    @Test("an expired guess is adopted as expired, and leaves the next time the list is read")
    func expiredIsAdoptedThenLeaves() async throws {
        defer { StubProtocol.clear(session) }
        serve(answer: (200, "02", "guess.answer.expired"))
        await data.load()

        let outcome = try await data.answer(offered(), verdict: .yes)
        #expect(outcome == .recorded(.expired))
        #expect(try offered().status == .expired)

        serve(list: "guesses.silent")
        await data.load()
        #expect(data.guesses.isEmpty)
    }
}
