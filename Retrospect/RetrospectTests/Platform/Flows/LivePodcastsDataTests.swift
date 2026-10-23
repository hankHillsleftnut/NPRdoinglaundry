import Foundation
@testable import Retrospect
import Testing

/// PL3.4.a.min: the podcast library's live data. Fixtures 03 through the real repository and client (stubbed
/// network), plus a held repository for the order of two answers.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LivePodcastsDataTests {
    typealias Podcasts = Flows.Podcasts

    private struct Tokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "token" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "token" }
    }

    /// The hero in `podcasts.library` and the episode in `episode.v2`.
    private let heroID = "0b6f3a52-6c1e-4d0a-9b1e-2f7c0d4e9a01"
    /// 2026-10-21 14:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_792_591_200)
    private let session = URLSession.stubbed()
    private let network = ManualReachability()
    private let repository: Platform.Repositories.Podcasts
    private let data: LivePodcastsData

    init() {
        let client = Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: Tokens(), reachability: network, clock: TestClock(), log: Platform.Log.Recorder()
        )
        let now = now
        repository = Platform.Repositories.Podcasts(client: client)
        data = LivePodcastsData(repository: repository, now: { now })
    }

    /// Answers each path with a fixture; anything else is not found.
    private func serve(_ answers: [String: (Int, Data)]) {
        StubProtocol.register(on: session) { request in
            let (status, body) = try answers[request.url?.path ?? ""] ?? (404, Fixtures.data("03", "error.not_found"))
            return (HTTPURLResponse.stub(request, status: status), body)
        }
    }

    private func requests(to path: String) -> Int {
        StubProtocol.requests(on: session).filter { $0.url?.path == path }.count
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        while !condition() {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    /// `episode.v2` as the door sends it after a storage blip: the same episode, words only.
    private static func wordsOnly() throws -> Data {
        var envelope = try #require(JSONSerialization.jsonObject(with: Fixtures.data("03", "episode.v2")) as? [String: Any])
        var payload = try #require(envelope["data"] as? [String: Any])
        var episode = try #require(payload["episode"] as? [String: Any])
        episode["audio"] = nil
        episode["hasAudio"] = false
        payload["episode"] = episode
        envelope["data"] = payload
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    private static func library(_ name: String) throws -> Podcasts.Library {
        let envelope = try #require(JSONSerialization.jsonObject(with: Fixtures.data("03", name)) as? [String: Any])
        let payload = try JSONSerialization.data(withJSONObject: #require(envelope["data"]))
        return try Backend.Coding.decoder.decode(Podcasts.Library.self, from: payload)
    }

    // MARK: Fixtures through the repository

    @Test func theLibraryAndAnEpisodeReadThroughTheRepository() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library")), "/v2/episodes/\(heroID)": (200, Fixtures.data("03", "episode.v2"))])
        let state = await data.library()
        let library = try #require(state.library)
        #expect(state == .content(library))
        #expect(library.hero?.id == heroID)
        #expect(library.items.count == 3)
        let episode = try await data.episode(id: heroID).get()
        #expect(episode.id == heroID)
        #expect(episode.audio != nil)
        #expect(await repository.lastLibrary() == library)
        #expect(await repository.lastEpisode(id: heroID) == episode)
    }

    @Test func anEmptyLibraryIsContentNotAFailure() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library.empty"))])
        let state = await data.library()
        #expect(try state == .content(Self.library("podcasts.library.empty")))
        #expect(state.library?.hero == nil)
    }

    // MARK: Offline and failures

    @Test func offlineKeepsTheLastAnswer() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library"))])
        let library = try #require(await data.library().library)
        network.set(online: false)
        await data.refresh()
        #expect(data.state == .offline(library))
        #expect(data.state.library == library)
    }

    @Test func offlineOnTheFirstLoadHasNothingToShow() async {
        network.set(online: false)
        #expect(await data.library() == .offline(nil))
    }

    @Test func aRefusalKeepsShownContentAndOnlyAnEmptyPageFails() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library"))])
        let library = try #require(await data.library().library)
        serve([:])
        await data.refresh()
        #expect(data.state == .content(library))

        let fresh = LivePodcastsData(repository: Platform.Repositories.Podcasts(client: Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false), session: session, tokens: Tokens(),
            reachability: network, clock: TestClock(), log: Platform.Log.Recorder()
        )))
        #expect(await fresh.library() == .failed(.notFound))
    }

    @Test func aSecondLoadShowsTheKeptLibraryAtOnce() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library"))])
        let library = try #require(await data.library().library)
        let again = LivePodcastsData(repository: repository)
        network.set(online: false)
        #expect(await again.library() == .offline(library))
    }

    // MARK: Two refreshes, two people

    @Test func anOlderAnswerNeverReplacesANewerOne() async throws {
        let held = HeldPodcasts()
        let data = LivePodcastsData(repository: held)
        let older = Task { await data.refresh() }
        try await waitUntil { held.waitingCount == 1 }
        let newer = Task { await data.refresh() }
        try await waitUntil { held.waitingCount == 2 }
        let newest = try Self.library("podcasts.library.empty")
        held.answer(1, with: newest)
        await newer.value
        try held.answer(0, with: Self.library("podcasts.library"))
        await older.value
        #expect(data.state == .content(newest))
    }

    @Test func anAnswerLandingAfterSignOutIsNeverShownOrKept() async throws {
        let release = DispatchSemaphore(value: 0)
        let body = try Fixtures.data("03", "podcasts.library")
        StubProtocol.register(on: session) { request in
            _ = release.wait(timeout: .now() + 20) // the server is slow: the person signs out meanwhile
            return (HTTPURLResponse.stub(request, status: 200), body)
        }
        let load = Task { await data.library() }
        try await waitUntil { requests(to: "/v2/podcasts") == 1 }
        await data.stop()
        release.signal()
        #expect(await load.value == .loading)
        #expect(data.state == .loading)
        #expect(await repository.lastLibrary() == nil)
        await data.refresh()
        #expect(requests(to: "/v2/podcasts") == 1)
    }

    @Test func signOutDropsEverythingKept() async throws {
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library")), "/v2/episodes/\(heroID)": (200, Fixtures.data("03", "episode.v2"))])
        _ = await data.library()
        _ = try await data.episode(id: heroID).get()
        await data.stop()
        #expect(data.state == .loading)
        #expect(await repository.lastLibrary() == nil)
        #expect(await repository.lastEpisode(id: heroID) == nil)
        #expect(await data.episode(id: heroID) == .failure(.signedOut))
    }

    // MARK: Audio said yes, the episode said no (review-192)

    @Test func anEpisodeTheLibrarySaysHasAudioIsAskedForOnceMore() async throws {
        let episodePath = "/v2/episodes/\(heroID)"
        let library = try Fixtures.data("03", "podcasts.library")
        let words = try Self.wordsOnly()
        let full = try Fixtures.data("03", "episode.v2")
        let session = session
        StubProtocol.register(on: session) { request in
            let path = request.url?.path ?? ""
            if path == "/v2/podcasts" {
                return (HTTPURLResponse.stub(request, status: 200), library)
            }
            // the first look comes back words only, the second with its link
            let earlier = StubProtocol.requests(on: session).filter { $0.url?.path == episodePath }.count
            return (HTTPURLResponse.stub(request, status: 200), earlier <= 1 ? words : full)
        }
        _ = await data.library()
        let episode = try await data.episode(id: heroID).get()
        #expect(requests(to: episodePath) == 2)
        #expect(episode.audio != nil)
    }

    @Test func anEpisodeWithoutAudioInTheLibraryIsAskedForOnce() async throws {
        let words = try Self.wordsOnly()
        try serve(["/v2/podcasts": (200, Fixtures.data("03", "podcasts.library.empty")), "/v2/episodes/\(heroID)": (200, words)])
        _ = await data.library()
        let episode = try await data.episode(id: heroID).get()
        #expect(requests(to: "/v2/episodes/\(heroID)") == 1)
        #expect(episode.audio == nil)
    }

    @Test func aKeptEpisodeIsHandedBackOfflineOnlyWhileItsLinkLasts() async throws {
        try serve(["/v2/episodes/\(heroID)": (200, Fixtures.data("03", "episode.v2"))])
        let kept = try await data.episode(id: heroID).get()
        network.set(online: false)
        let expiresAt = try #require(kept.audio?.expiresAt)
        let lasting = LivePodcastsData(repository: repository, now: { expiresAt.addingTimeInterval(-600) })
        #expect(await lasting.episode(id: heroID) == .success(kept))
        let ending = LivePodcastsData(repository: repository, now: { expiresAt.addingTimeInterval(-30) })
        #expect(await ending.episode(id: heroID) == .failure(.network))
    }
}

/// A repository whose library answers wait until the test releases them, in any order.
private final class HeldPodcasts: Platform.Repositories.PodcastsReading, @unchecked Sendable {
    private let lock = NSLock()
    private var waiting: [CheckedContinuation<Backend.Podcasts.Library, any Error>] = []

    var waitingCount: Int {
        lock.withLock { waiting.count }
    }

    func answer(_ index: Int, with library: Backend.Podcasts.Library) {
        let continuation = lock.withLock { waiting[index] }
        continuation.resume(returning: library)
    }

    func close() async {}
    func lastLibrary() async -> Backend.Podcasts.Library? { nil }
    func lastEpisode(id _: String) async -> Backend.Podcasts.Episode? { nil }

    func library() async throws -> Backend.Podcasts.Library {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { waiting.append(continuation) }
        }
    }

    func episode(id _: String) async throws -> Backend.Podcasts.Episode {
        throw CancellationError()
    }
}
