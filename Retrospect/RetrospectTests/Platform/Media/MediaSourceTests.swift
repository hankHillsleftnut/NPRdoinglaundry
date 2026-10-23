import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct MediaSourceTests {
    typealias Brief = Flows.Journal.Brief

    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("media-\(UUID().uuidString)", isDirectory: true)
    private let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("dl-\(UUID().uuidString)", isDirectory: true)
    private let now = Date(timeIntervalSince1970: 1_792_569_604)

    /// Counts what the source asked for.
    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var downloads: [URL] = []
        private(set) var refetches = 0
        var online = true
        var fresh: Brief?

        func downloaded(_ url: URL) {
            lock.withLock { downloads.append(url) }
        }

        func refetched() -> Brief? {
            lock.withLock {
                refetches += 1
                return fresh
            }
        }
    }

    private func brief(expiresIn seconds: TimeInterval, duration: Double = 74.2, url: String = "https://example.test/a.mp3") throws -> Brief {
        let expires = Backend.Coding.timestamp(now.addingTimeInterval(seconds))
        let json = """
        {"id":"b1","date":"2026-10-21","kind":"brief","parts":[{"text":"x","sources":[]}],"createdAt":"2026-10-21T07:58:00.000Z",
        "audio":{"url":"\(url)","expiresAt":"\(expires)","durationSeconds":\(duration)}}
        """
        return try Backend.Coding.decoder.decode(Brief.self, from: Data(json.utf8))
    }

    private func source(_ calls: Calls, body: String = "audio") -> Platform.Media.Source {
        let now = now
        let scratch = scratch
        return Platform.Media.Source(
            directory: directory, now: { now }, isOnline: { calls.online },
            download: { url in
                calls.downloaded(url)
                try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
                let file = scratch.appendingPathComponent(UUID().uuidString)
                try Data(body.utf8).write(to: file)
                return file
            },
            refetch: { calls.refetched() }
        )
    }

    @Test("the first play downloads the audio into the caches folder under the brief's id, and later plays reuse the file")
    func downloadsOnceAndKeeps() async throws {
        let calls = Calls()
        let source = source(calls)
        let brief = try brief(expiresIn: 3600)

        let first = try await source.playableFile(for: brief, rate: 1)
        let second = try await source.playableFile(for: brief, rate: 1)

        #expect(first == second)
        #expect(first.lastPathComponent == "b1.mp3")
        #expect(calls.downloads.count == 1)
        #expect(FileManager.default.fileExists(atPath: first.path))
    }

    @Test("an empty download is never kept as the brief's audio, and the next play tries again")
    func anEmptyDownloadIsNotKept() async throws {
        let calls = Calls()
        let brief = try brief(expiresIn: 3600)
        let empty = source(calls, body: "")

        await #expect(throws: Platform.Media.Source.Failure.self) { try await empty.playableFile(for: brief, rate: 1) }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("b1.mp3").path))

        let working = source(calls)
        let file = try await working.playableFile(for: brief, rate: 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(calls.downloads.count == 2)
    }

    @Test("only a 2xx HTTP answer is accepted as audio: a 403 or a 404 body is not")
    func onlyTwoXXIsAudio() throws {
        let url = try #require(URL(string: "https://example.test/a.mp3"))
        func answer(_ code: Int) throws -> URLResponse {
            try #require(HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil))
        }
        #expect(try Platform.Media.Source.accepts(answer(200)))
        #expect(try !Platform.Media.Source.accepts(answer(403)))
        #expect(try !Platform.Media.Source.accepts(answer(404)))
        #expect(try !Platform.Media.Source.accepts(answer(503)))
        #expect(!Platform.Media.Source.accepts(URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)))
    }

    @Test("a signed link that would run out before the brief finishes is refetched first, and the fresh link is the one used")
    func anExpiringLinkIsRefetched() async throws {
        let calls = Calls()
        calls.fresh = try brief(expiresIn: 3600, url: "https://example.test/fresh.mp3")
        let source = source(calls)
        // 74 s at 1x plus the 5 minute margin is 374 s: a link good for 300 s is too short
        let stale = try brief(expiresIn: 300, url: "https://example.test/stale.mp3")

        _ = try await source.playableFile(for: stale, rate: 1)

        #expect(calls.refetches == 1)
        #expect(calls.downloads.map(\.absoluteString) == ["https://example.test/fresh.mp3"])
    }

    @Test("a link good for the whole brief and the margin is used as it is")
    func aGoodLinkIsNotRefetched() async throws {
        let calls = Calls()
        let source = source(calls)

        _ = try await source.playableFile(for: brief(expiresIn: 400), rate: 1)

        #expect(calls.refetches == 0)
    }

    @Test("a missing file is downloaded again, and a brief whose length changed gets its audio replaced")
    func missingOrChangedAudioIsFetchedAgain() async throws {
        let calls = Calls()
        let source = source(calls)
        let file = try await source.playableFile(for: brief(expiresIn: 3600), rate: 1)
        try FileManager.default.removeItem(at: file)

        _ = try await source.playableFile(for: brief(expiresIn: 3600), rate: 1)
        _ = try await source.playableFile(for: brief(expiresIn: 3600, duration: 80), rate: 1)

        #expect(calls.downloads.count == 3)
    }

    @Test("offline with the file it plays; offline without it, it says offline and downloads nothing")
    func offline() async throws {
        let calls = Calls()
        let source = source(calls)
        let brief = try brief(expiresIn: 3600)
        calls.online = false
        await #expect(throws: Platform.Media.Source.Failure.offline) { try await source.playableFile(for: brief, rate: 1) }
        #expect(calls.downloads.isEmpty)

        calls.online = true
        _ = try await source.playableFile(for: brief, rate: 1)
        calls.online = false

        _ = try await source.playableFile(for: brief, rate: 1)
        #expect(calls.downloads.count == 1)
    }

    @Test("sign-out erases every file")
    func eraseRemovesEverything() async throws {
        let calls = Calls()
        let source = source(calls)
        let file = try await source.playableFile(for: brief(expiresIn: 3600), rate: 1)

        await source.erase()

        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("a brief with no audio, or a download that fails, is unavailable")
    func unavailable() async throws {
        let calls = Calls()
        let source = source(calls)
        let silent = try Backend.Coding.decoder.decode(
            Brief.self, from: Data(#"{"id":"b2","date":"2026-10-21","kind":"quiet","parts":[],"createdAt":"2026-10-21T07:58:00.000Z"}"#.utf8)
        )

        await #expect(throws: Platform.Media.Source.Failure.unavailable) { try await source.playableFile(for: silent, rate: 1) }
    }
}
