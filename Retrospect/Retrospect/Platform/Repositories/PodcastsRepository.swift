import Foundation

extension Platform.Repositories {
    /// What `LivePodcastsData` needs from the podcasts repository (a seam, so tests can hold one answer back).
    protocol PodcastsReading: Sendable {
        func close() async
        func lastLibrary() async -> Backend.Podcasts.Library?
        func lastEpisode(id: String) async -> Backend.Podcasts.Episode?
        func library() async throws -> Backend.Podcasts.Library
        func episode(id: String) async throws -> Backend.Podcasts.Episode
    }

    /// The podcast library's reads (PL3.4.a.min): network only, nothing on disk. The last good library and each last
    /// good episode stay in memory for this person's session; `close()` (sign-out) drops them and refuses every answer
    /// that lands after it.
    actor Podcasts: PodcastsReading {
        private let client: Backend.Client
        private var closed = false
        private var keptLibrary: Backend.Podcasts.Library?
        private var keptEpisodes: [String: Backend.Podcasts.Episode] = [:]
        /// Library requests sent, and the one whose answer is kept.
        private var librarySent = 0
        private var libraryKeptFrom = 0

        init(client: Backend.Client) {
            self.client = client
        }

        /// The person signed out: everything kept is dropped, and nothing fetched from now on is kept or handed back.
        /// Closing and keeping are both this actor's, so they cannot interleave.
        func close() {
            closed = true
            keptLibrary = nil
            keptEpisodes = [:]
        }

        /// The last good library; nil before the first one, and after `close()`.
        func lastLibrary() -> Backend.Podcasts.Library? {
            keptLibrary
        }

        /// The last good answer for `id`; nil when none was kept.
        func lastEpisode(id: String) -> Backend.Podcasts.Episode? {
            keptEpisodes[id]
        }

        /// The library's first page from the server, kept as the last good answer unless a newer request's answer is
        /// already kept (two looks overlap: the older one coming back last never replaces the newer). After `close()`
        /// nothing is sent and every answer throws `CancellationError`, so a late answer never reaches the next person's page.
        func library() async throws -> Backend.Podcasts.Library {
            guard !closed else { throw CancellationError() }
            librarySent += 1
            let request = librarySent
            let library = try await client.send(Backend.Endpoints.PodcastLibrary())
            guard !closed, !Task.isCancelled else { throw CancellationError() }
            if request > libraryKeptFrom {
                keptLibrary = library
                libraryKeptFrom = request
            }
            return library
        }

        /// One episode from the server, kept as its last good answer. A words-only answer (a storage blip, review-192)
        /// never replaces a kept copy that has a link: the caller checks whether that link still lasts. After `close()`
        /// nothing is sent and every answer throws `CancellationError`.
        func episode(id: String) async throws -> Backend.Podcasts.Episode {
            guard !closed else { throw CancellationError() }
            let episode = try await client.send(Backend.Endpoints.EpisodeByID(id: id)).episode
            guard !closed, !Task.isCancelled else { throw CancellationError() }
            if episode.audio != nil || keptEpisodes[id]?.audio == nil {
                keptEpisodes[id] = episode
            }
            return episode
        }
    }
}
