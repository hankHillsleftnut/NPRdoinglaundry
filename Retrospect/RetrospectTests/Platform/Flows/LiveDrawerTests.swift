import Foundation
import GRDB
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveDrawerTests {
    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    private let session = URLSession.stubbed()
    private let network = ManualReachability()
    private let log = Platform.Log.Recorder()
    private let database: Store.LocalDatabase
    private let data: LiveJournalData
    private let now = Date(timeIntervalSince1970: 1_792_591_200)

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let now = now
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: network, clock: TestClock(), log: log
        )
        self.database = database
        data = LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, now: { now }, timeZone: { .gmt }),
            outbox: Store.Outbox(database: database, log: log), reachability: StreamingReachability(), now: { now }, timeZone: { .gmt }
        )
    }

    private func serve(_ fixtures: [String: (Int, String, String)]) {
        StubProtocol.register(on: session) { request in
            let key = (request.url?.path ?? "") + (request.url?.query.map { "?" + $0 } ?? "")
            let (status, folder, name) = fixtures[key] ?? fixtures[request.url?.path ?? ""] ?? (404, "00", "error.not_found")
            return try (HTTPURLResponse.stub(request, status: status), Fixtures.data(folder, name))
        }
    }

    private func phoneRow(_ id: String, text: String, state: Store.SyncState = .local, at seconds: TimeInterval = 0) throws {
        let row = Store.EntryRow(
            localID: id, serverID: nil, kind: .typed, text: text, createdAt: now.addingTimeInterval(seconds), day: "2026-10-21",
            mediaPath: nil, syncState: state, failureCode: nil, attempts: 0, reading: nil, origin: .new
        )
        try database.writer.write { try row.insert($0) }
    }

    private func page(_ result: Result<Flows.Page<Flows.Journal.Entry>, Flows.Failure>) throws -> Flows.Page<Flows.Journal.Entry> {
        try result.get()
    }

    private func requests(_ path: String) -> [URLRequest] {
        StubProtocol.requests(on: session).filter { $0.url?.path == path }
    }

    @Test("paging passes the cursor through and stops when there is none, and an empty search is not sent")
    func paging() async throws {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries": (200, "02", "entries.list.last")])
        let cursor = "MTc5MjU4NzczMTQxMDAwMHww"
        StubProtocol.register(on: session) { request in
            let isFirst = request.url?.query == nil
            return try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", isFirst ? "entries.list" : "entries.list.last"))
        }

        let first = try await page(data.entries(cursor: nil, query: "  "))
        let second = try await page(data.entries(cursor: cursor, query: nil))

        #expect(first.items.count == 3)
        #expect(first.nextCursor != nil)
        #expect(second.nextCursor == nil)
        let sent = requests("/v2/entries")
        #expect(sent.first?.url?.query == nil, "no q for an empty search")
        #expect(sent.last?.url?.query?.contains("cursor=\(cursor)") == true)
    }

    @Test("a search longer than the door's limit is clipped to 100 UTF-16 units")
    func clipsTheSearch() {
        let long = String(repeating: "a", count: 150)

        #expect(LiveJournalData.cleaned(long)?.utf16.count == 100)
        #expect(LiveJournalData.cleaned("  dentist ") == "dentist")
        #expect(LiveJournalData.cleaned("   ") == nil)
    }

    @Test("an unsent entry on the phone matches a search with its own spans, and heads the first page")
    func searchFindsPhoneOnlyEntries() async throws {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries": (200, "02", "entries.search.empty")])
        try phoneRow("00000000-0000-4000-8000-0000000000c1", text: "Canal walk, by the canal")
        try phoneRow("00000000-0000-4000-8000-0000000000c2", text: "nothing relevant")

        let result = try await page(data.entries(cursor: nil, query: "canal"))

        #expect(result.items.count == 1)
        #expect(result.items.first?.matches == [.init(start: 0, length: 5), .init(start: 19, length: 5)])
        #expect(result.items.first?.delivery == .waiting)
    }

    @Test("a server range past the end of its text is dropped, and an astral emoji slices the right word")
    func serverRanges() async throws {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries": (200, "02", "entries.search.astral")])

        let result = try await page(data.entries(cursor: nil, query: "canal"))
        let entry = try #require(result.items.first)
        let match = try #require(entry.matches?.first)

        #expect((entry.text as NSString).substring(with: NSRange(location: match.start, length: match.length)) == "canal")

        let broken = entry.replacingMatches([match, .init(start: 40, length: 5)])
        #expect(broken.matches?.count == 2)
        let cleaned = broken.replacingMatches(broken.matches?.filter { LiveJournalData.valid($0, in: broken.text) })
        #expect(cleaned.matches == [match])
    }

    @Test("offline, the first page is the phone's entries and today's kept list, filtered, with no next page and no error")
    func offlineSearch() async throws {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries/today": (200, "02", "entries.today"), "/v2/entries": (200, "02", "entries.list")])
        await data.load()
        try phoneRow("00000000-0000-4000-8000-0000000000c3", text: "dentist again tomorrow")
        network.set(online: false)

        let result = try await page(data.entries(cursor: nil, query: "dentist"))

        #expect(result.nextCursor == nil)
        #expect(result.items.count == 2)
        #expect(Set(result.items.map(\.text)) == ["dentist again tomorrow", "dentist at 3 today, dreading it"])
        let later = await data.entries(cursor: "next", query: nil)
        #expect(later == .failure(Flows.Failure(.network)))
    }

    @Test("an invalid search or cursor is invalid, not a crash")
    func invalidRequest() async {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries": (400, "00", "error.invalid_request")])

        let result = await data.entries(cursor: "garbage", query: nil)

        #expect(result == .failure(Flows.Failure(.invalid)))
    }

    @Test("one entry: an unsent one from the phone with no request, a server one fetched, a stranger's not found")
    func oneEntry() async throws {
        defer { StubProtocol.clear(session) }
        serve(["/v2/entries/00000000-0000-4000-8000-000000000101": (200, "02", "entry")])
        let local = "00000000-0000-4000-8000-0000000000c4"
        try phoneRow(local, text: "still on the phone")

        let own = try await data.entry(id: local).get()
        let fetched = try await data.entry(id: "00000000-0000-4000-8000-000000000101").get()
        let stranger = await data.entry(id: "00000000-0000-4000-8000-0000000000ff")

        #expect(own.delivery == .waiting)
        #expect(fetched.text == "dentist at 3 today, dreading it")
        #expect(stranger == .failure(Flows.Failure(.notFound)))
        #expect(StubProtocol.requests(on: session).count == 2)
    }

    @Test("the same entry from the phone and the server is listed once")
    func deduplicates() throws {
        let json = #"{"id":"s1","kind":"typed","text":"x","createdAt":"2026-10-21T13:00:00.000Z","day":"2026-10-21","reading":"read","clientEntryId":"c1"}"#
        let server = try Backend.Coding.decoder.decode(Flows.Journal.Entry.self, from: Data(json.utf8))
        let phone = Flows.Journal.Entry(local: "c1", kind: .typed, text: "x", createdAt: now, day: "2026-10-21", delivery: .waiting)

        #expect(LiveJournalData.deduplicated([phone, server]).count == 1)
    }
}
