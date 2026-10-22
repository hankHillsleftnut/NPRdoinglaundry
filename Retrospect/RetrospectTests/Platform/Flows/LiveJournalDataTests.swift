import Foundation
import GRDB
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveJournalDataTests {
    typealias Journal = Flows.Journal

    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    /// 2026-10-21 14:00 UTC: the fixtures' day.
    private let now = Date(timeIntervalSince1970: 1_792_591_200)
    private let database: Store.LocalDatabase
    private let session = URLSession.stubbed()
    private let sender = ScriptedSender()
    private let reachability = StreamingReachability()
    private let log = Platform.Log.Recorder()
    private let outbox: Store.Outbox
    private let data: LiveJournalData
    private let id = "00000000-0000-4000-8000-0000000000a1"

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let now = now
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: ManualReachability(), clock: TestClock(), log: log
        )
        let outbox = Store.Outbox(
            database: database, sender: sender, now: { now }, timeZone: { .gmt }, jitter: { $0 }, pick: { _ in 0 }, log: log
        )
        self.database = database
        self.outbox = outbox
        data = LiveJournalData(
            repository: Platform.Repositories.Journal(database: database, client: client, now: { now }, timeZone: { .gmt }),
            outbox: outbox, reachability: reachability, now: { now }, timeZone: { .gmt }
        )
    }

    private func answerToday(_ fixture: String = "entries.today") {
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", fixture))
        }
    }

    private func refuseToday(status: Int, fixture: String) {
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: status), Fixtures.data("00", fixture))
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        while !condition() {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private var entries: [Journal.Entry] {
        data.today.value ?? []
    }

    private func row(_ id: String) throws -> Store.EntryRow {
        try #require(try database.writer.read { try Store.EntryRow.fetchOne($0, key: id) })
    }

    private func rowCount() throws -> Int {
        try database.writer.read { try Store.EntryRow.fetchCount($0) }
    }

    private func documentCount() throws -> Int {
        try database.writer.read { try Store.CachedDocument.fetchCount($0) }
    }

    private func execute(_ sql: String, _ arguments: StatementArguments = []) throws {
        try database.writer.write { try $0.execute(sql: sql, arguments: arguments) }
    }

    // MARK: Today

    @Test("today is the server's list, oldest first, every entry sent")
    func todayIsTheServersList() async {
        defer { StubProtocol.clear(session) }
        answerToday()

        await data.load()

        #expect(entries.map(\.kind) == [.typed, .voice, .imported])
        #expect(entries.allSatisfy { $0.delivery == .sent })
        #expect(StubProtocol.requests(on: session).first?.url?.path == "/v2/entries/today")
    }

    @Test("an entry sent shows at once as waiting from the store alone, then as sent, with no copy appended by the seam")
    func aSentEntryAppearsFromTheStore() async throws {
        defer { StubProtocol.clear(session) }
        refuseToday(status: 500, fixture: "error.internal")
        await data.load()

        await data.send(text: "  dentist at 3  ")
        try await waitUntil { entries.count == 1 }

        #expect(entries.first?.text == "dentist at 3")
        #expect(entries.first?.delivery == .waiting)
        #expect(entries.first?.clientEntryId != nil)
        #expect(try rowCount() == 1)

        await outbox.drain(reason: .manual)
        try await waitUntil { entries.first?.delivery == .sent }

        #expect(entries.count == 1)
    }

    @Test("an entry sent before load is still in today after load, once")
    func anEntrySentBeforeLoadIsKept() async throws {
        defer { StubProtocol.clear(session) }
        answerToday()
        await data.send(text: "before the load")

        await data.load()
        try await waitUntil { entries.count == 4 }

        #expect(entries.filter { $0.text == "before the load" }.count == 1)
        #expect(entries.map(\.createdAt) == entries.map(\.createdAt).sorted())
    }

    @Test("the cached list shows at once next time, and a failed refresh keeps it")
    func theCachedListSurvivesAFailedRefresh() async {
        defer { StubProtocol.clear(session) }
        answerToday()
        await data.load()
        refuseToday(status: 429, fixture: "error.rate_limited")

        await data.load()

        #expect(entries.count == 3)
    }

    @Test("with nothing cached, a failed load is failed; with phone-only entries it is still loaded")
    func aFailedLoadFailsOnlyWhenEmpty() async throws {
        defer { StubProtocol.clear(session) }
        refuseToday(status: 500, fixture: "error.internal")
        await data.load()
        if case let .failed(failure) = data.today {
            #expect(failure.kind == .server)
        } else {
            Issue.record("expected a failed today, got \(data.today)")
        }

        await data.send(text: "still here")
        try await waitUntil { entries.count == 1 }

        #expect(entries.count == 1)
    }

    @Test("a fetch that finishes after the task was cancelled writes nothing to the store")
    func aCancelledFetchWritesNothing() async throws {
        defer { StubProtocol.clear(session) }
        answerToday()
        let repository = Platform.Repositories.Journal(
            database: database,
            client: Backend.Client(
                configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
                session: session, tokens: Tokens(), reachability: ManualReachability(), clock: TestClock(), log: log
            ),
            now: { now }, timeZone: { .gmt }
        )

        let fetch = Task { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await repository.refreshToday(day: "2026-10-21")
                return false
            } catch {
                return true
            }
        }

        #expect(await fetch.value)
        #expect(try documentCount() == 0)
    }

    // MARK: Delivery

    @Test("the acknowledgement appears only after the entry is sent, stays through a reload, and server entries get none")
    func theAcknowledgementFollowsSent() async throws {
        defer { StubProtocol.clear(session) }
        answerToday()
        await data.load()
        await data.send(text: "kept")
        try await waitUntil { entries.count == 4 }
        let sent = try #require(entries.first { $0.text == "kept" }?.clientEntryId)
        #expect(data.acknowledgement(for: sent) == nil)

        await outbox.drain(reason: .manual)
        try await waitUntil { data.acknowledgement(for: sent) != nil }
        await data.load()

        #expect(data.acknowledgement(for: sent) != nil)
        #expect(data.acknowledgement(for: "00000000-0000-4000-8000-000000000901") == nil)
    }

    @Test("a refused entry shows failed with its stored code, and a code this build doesn't know can be tried again")
    func aRefusedEntryShowsItsCode() {
        #expect(LiveJournalData.failure(code: "invalid_request").kind == .invalid)
        #expect(LiveJournalData.failure(code: "decoding").kind == .server)
        #expect(!LiveJournalData.failure(code: "invalid_request").isRetryable)
        #expect(LiveJournalData.failure(code: "not-a-code-we-know").isRetryable)
        #expect(LiveJournalData.failure(code: nil).isRetryable)
    }

    @Test("retry resets a failed entry and drains; on a waiting entry, or offline, it does nothing")
    func retryOnlyFailedAndOnline() async throws {
        defer { StubProtocol.clear(session) }
        refuseToday(status: 500, fixture: "error.internal")
        await data.load()
        sender.script("never", [])
        await data.send(text: "will fail")
        try await waitUntil { entries.count == 1 }
        let key = try #require(entries.first?.clientEntryId)

        await data.retry(clientEntryId: key)
        #expect(sender.sends.isEmpty, "a waiting entry isn't retried")

        sender.script(key, [.failure(Backend.Failure(.invalidRequest))])
        await outbox.drain(reason: .manual)
        try await waitUntil {
            if case .failed? = entries.first?.delivery {
                true
            } else {
                false
            }
        }
        reachability.send(false)
        try await waitUntil { !data.isOnline }
        await data.retry(clientEntryId: key)
        #expect(sender.sends.count == 1, "offline, nothing is sent")

        reachability.send(true)
        try await waitUntil { data.isOnline }
        await data.retry(clientEntryId: key)
        try await waitUntil { entries.first?.delivery == .sent }
        #expect(sender.sends.count == 2)
    }

    @Test("an empty or over-long entry is never saved, and a refused one says so, so the words can go back")
    func refusedDrafts() async throws {
        #expect(await data.send(text: "   ") == .failed(Flows.Failure(.invalidRequest)))
        let long = await data.send(text: String(repeating: "a", count: LiveJournalData.longestEntry + 1))
        #expect(long == .failed(Flows.Failure(.invalidRequest)))
        #expect(try rowCount() == 0)
        #expect(await data.send(text: "fine") == .queued)
        #expect(try rowCount() == 1)
    }

    // MARK: Merging

    private func serverEntry(_ idSuffix: Int, client: String?, at seconds: TimeInterval, reading: String = "read") throws -> Journal.Entry {
        let clientKey = client.map { #","clientEntryId":"\#($0)""# } ?? ""
        let json = """
        {"id":"s\(idSuffix)","kind":"typed","text":"server","createdAt":"\(Backend.Coding.timestamp(now.addingTimeInterval(seconds)))",
        "day":"2026-10-21","reading":"\(reading)"\(clientKey)}
        """
        return try Backend.Coding.decoder.decode(Journal.Entry.self, from: Data(json.utf8))
    }

    private func localRow(_ id: String, state: Store.SyncState, at seconds: TimeInterval, code: String? = nil) -> Store.EntryRow {
        Store.EntryRow(
            localID: id, serverID: nil, kind: .typed, text: "phone", createdAt: now.addingTimeInterval(seconds), day: "2026-10-21",
            mediaPath: nil, syncState: state, failureCode: code, attempts: 0, reading: nil, origin: .new
        )
    }

    @Test("a sent row also in the server list is one entry with the server's copy; a row still on the phone keeps its own state")
    func mergingDeduplicates() throws {
        let sentKey = "00000000-0000-4000-8000-0000000000b1"
        let waitingKey = "00000000-0000-4000-8000-0000000000b2"
        let server = try [
            serverEntry(1, client: sentKey, at: 10, reading: "reading"),
            serverEntry(2, client: waitingKey, at: 30),
            serverEntry(3, client: nil, at: 5),
        ]
        let rows = [localRow(sentKey, state: .sent, at: 9), localRow(waitingKey, state: .local, at: 31)]

        let merged = LiveJournalData.merged(server: server, rows: rows)

        #expect(merged.count == 3)
        #expect(merged.map(\.createdAt) == merged.map(\.createdAt).sorted())
        #expect(merged.first { $0.clientEntryId == sentKey }?.reading == .reading)
        #expect(merged.first { $0.clientEntryId == waitingKey }?.delivery == .waiting)
        #expect(merged.first { $0.clientEntryId == waitingKey }?.text == "phone")
    }

    @Test("every sync state maps to a delivery")
    func deliveryMapping() {
        let merged = LiveJournalData.merged(server: [], rows: [
            localRow("a", state: .local, at: 1), localRow("b", state: .sending, at: 2), localRow("c", state: .sent, at: 3),
            localRow("d", state: .failed, at: 4, code: "invalid_request"), localRow("e", state: .legacy, at: 5),
        ])

        #expect(merged.map(\.delivery) == [.waiting, .sending, .sent, .failed(Flows.Failure(.invalid)), .sent])
    }
}
