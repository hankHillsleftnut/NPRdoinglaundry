import Foundation
import GRDB
@testable import Retrospect
import Testing

/// Work that is already past its checks when the person signs out must not put their words back on disk.
@Suite(.timeLimit(.minutes(1)))
struct LateWriteTests {
    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    @Test("a fetch that comes back after the store was closed writes nothing")
    func closedRepositoryWritesNothing() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let session = URLSession.stubbed()
        defer { StubProtocol.clear(session) }
        let held = DispatchSemaphore(value: 0)
        let reached = DispatchSemaphore(value: 0)
        StubProtocol.register(on: session) { request in
            reached.signal()
            _ = held.wait(timeout: .now() + 20) // the server is slow: sign-out happens meanwhile
            return try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", "entries.today"))
        }
        let client = Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false), session: session, tokens: Tokens(),
            reachability: ManualReachability(), clock: TestClock(), log: Platform.Log.Recorder()
        )
        let repository = Platform.Repositories.Journal(database: database, client: client, timeZone: { .gmt })

        let today = Task { try await repository.refreshToday(day: "2026-10-21") }
        reached.wait()
        await repository.close()
        held.signal()
        _ = try? await today.value

        let kept = try await database.writer.read { try Store.CachedDocument.fetchCount($0) }
        #expect(kept == 0, "nothing of the last person is cached after sign-out")
    }

    @Test("an open repository still keeps what it fetches")
    func openRepositoryKeeps() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let session = URLSession.stubbed()
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { request in
            try (HTTPURLResponse.stub(request, status: 200), Fixtures.data("02", "entries.today"))
        }
        let client = Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false), session: session, tokens: Tokens(),
            reachability: ManualReachability(), clock: TestClock(), log: Platform.Log.Recorder()
        )
        let repository = Platform.Repositories.Journal(database: database, client: client, timeZone: { .gmt })

        _ = try await repository.refreshToday(day: "2026-10-21")

        #expect(try await database.writer.read { try Store.CachedDocument.fetchCount($0) } == 1)
    }

    @Test("a download still running when the media source is erased is thrown away, not stored")
    func erasedSourceStoresNothing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("late-\(UUID().uuidString)", isDirectory: true)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("late-dl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let gate = Gate()
        let source = Platform.Media.Source(
            directory: directory, isOnline: { true },
            download: { _ in
                try await gate.wait()
                let file = scratch.appendingPathComponent(UUID().uuidString)
                try Data("audio".utf8).write(to: file)
                return file
            },
            refetch: { nil }
        )
        let expires = Backend.Coding.timestamp(Date().addingTimeInterval(7200))
        let json = """
        {"id":"b1","date":"2026-10-21","kind":"brief","parts":[{"text":"x","sources":[]}],"createdAt":"2026-10-21T07:58:00.000Z",
        "audio":{"url":"https://example.test/a.mp3","expiresAt":"\(expires)","durationSeconds":60}}
        """
        let brief = try Backend.Coding.decoder.decode(Flows.Journal.Brief.self, from: Data(json.utf8))

        let playing = Task { try await source.playableFile(for: brief, rate: 1) }
        for _ in 0 ..< 500 where gate.waiting == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        await source.erase()
        gate.open()

        await #expect(throws: Platform.Media.Source.Failure.self) { try await playing.value }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("b1.mp3").path))
    }
}
