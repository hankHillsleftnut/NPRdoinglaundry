//
//  LivePodcastsData.swift
//  PL3.4.a.min (Alpha 0.1): the podcast library's live data, built per signed-in person (PL3.4.b.min
//  builds it in the app environment beside the journal). It never touches the client itself: reads go
//  through `Repositories.Podcasts`, network only, the last good answer in memory. Only the newest
//  request's answer is ever shown, and after `stop()` (sign-out) nothing is: one person's library
//  never lands on the next person's page.
//
import Foundation
import Observation

@MainActor
@Observable
final class LivePodcastsData: Flows.PodcastsData {
    typealias Podcasts = Flows.Podcasts

    /// A kept episode whose audio link ends sooner than this (seconds) is not handed out again: it would stop mid-listen.
    static let linkMargin: TimeInterval = 120

    private(set) var state: Podcasts.LibraryState = .loading

    @ObservationIgnored private let repository: any Platform.Repositories.PodcastsReading
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Counts library requests; an answer is shown only when it belongs to the newest one.
    @ObservationIgnored private var generation = 0
    /// After `stop()` nothing more is fetched or shown.
    @ObservationIgnored private var stopped = false

    init(repository: any Platform.Repositories.PodcastsReading, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    /// The person signed out: the shown library is erased, the repository drops what it kept, and any answer still on
    /// its way is thrown away. The flags flip before the first suspension, so nothing shown can slip in after the call.
    func stop() async {
        stopped = true
        generation += 1
        state = .loading
        await repository.close()
    }

    // MARK: The library

    @discardableResult
    func library() async -> Podcasts.LibraryState {
        guard !stopped else { return state }
        if case .loading = state, let kept = await repository.lastLibrary(), !stopped, case .loading = state {
            state = .content(kept)
        }
        await fetch()
        return state
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        guard !stopped else { return }
        generation += 1
        let mine = generation
        do {
            let fresh = try await repository.library()
            guard isNewest(mine) else { return }
            state = .content(fresh)
        } catch is CancellationError {
            return
        } catch {
            guard isNewest(mine) else { return }
            show(Self.failure(error))
        }
    }

    /// A failed look: offline keeps whatever is shown; any other failure keeps shown content, and only an empty page fails.
    private func show(_ failure: Flows.Failure) {
        let shown = state.library
        if failure.kind == .network {
            state = .offline(shown)
        } else if let shown {
            state = .content(shown)
        } else {
            state = .failed(failure)
        }
    }

    /// An answer to request `request` may still be shown: not stopped, and no newer request started since.
    private func isNewest(_ request: Int) -> Bool {
        !stopped && request == generation
    }

    // MARK: One episode

    func episode(id: String) async -> Result<Podcasts.Episode, Flows.Failure> {
        guard !stopped else { return .failure(.signedOut) }
        let expectsAudio = summary(id: id)?.hasAudio == true
        do {
            var episode = try await repository.episode(id: id)
            // A storage blip signs no link and reads as words only (review-192): when the library said the episode has
            // audio, ask once more; if that look fails too, the words-only answer stands.
            if expectsAudio, episode.audio == nil, !stopped, let again = try? await repository.episode(id: id), again.audio != nil {
                episode = again
            }
            guard !stopped else { return .failure(.signedOut) }
            return .success(episode)
        } catch {
            guard !stopped else { return .failure(.signedOut) }
            if let kept = await repository.lastEpisode(id: id), !stopped, linkLasts(kept) {
                return .success(kept)
            }
            return .failure(Self.failure(error))
        }
    }

    /// The library's row for `id` (the hero or an item), if the shown library has one.
    private func summary(id: String) -> Podcasts.EpisodeSummary? {
        guard let library = state.library else { return nil }
        if let hero = library.hero, hero.id == id {
            return hero
        }
        for case let .episode(summary) in library.items where summary.id == id {
            return summary
        }
        return nil
    }

    /// A kept episode can be handed out again only while its audio link has a while left (or it has no link).
    private func linkLasts(_ episode: Podcasts.Episode) -> Bool {
        guard let audio = episode.audio else { return true }
        return audio.expiresAt.timeIntervalSince(now()) > Self.linkMargin
    }

    private static func failure(_ error: any Error) -> Flows.Failure {
        (error as? Backend.Failure)?.flowFailure ?? .unknown
    }
}
