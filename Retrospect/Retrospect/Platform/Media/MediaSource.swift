import Foundation

extension Platform {
    /// Audio the player plays (PL3.1b): where it comes from and whether it can be played now.
    enum Media {}
}

extension Platform.Media {
    /// Gives the player a file to play for a brief (contract PL3.1 §2). The audio is downloaded once, on first
    /// play, into the caches folder under the brief's id; later plays (and offline plays) use the file. A signed
    /// link that would run out before the brief has finished playing is never used: the brief is fetched again
    /// first. Everything it keeps is erased on sign-out.
    actor Source {
        enum Failure: Error, Equatable {
            /// Offline, and this audio isn't on the phone.
            case offline
            /// The brief came back without audio, or the download failed.
            case unavailable
        }

        /// A signed link must stay good for the whole brief at the playback speed, and this long on top.
        static let linkMargin: TimeInterval = 5 * 60

        private let directory: URL
        private let now: @Sendable () -> Date
        private let isOnline: @Sendable () async -> Bool
        /// Downloads `url` to a temporary file and returns it.
        private let download: @Sendable (URL) async throws -> URL
        /// Fetches the latest brief again (a new signed link).
        private let refetch: @Sendable () async throws -> Flows.Journal.Brief?

        init(
            directory: URL = URL.cachesDirectory.appendingPathComponent("Platform/audio", isDirectory: true),
            now: @escaping @Sendable () -> Date = { Date() },
            isOnline: @escaping @Sendable () async -> Bool,
            download: @escaping @Sendable (URL) async throws -> URL = Source.downloadChecked,
            refetch: @escaping @Sendable () async throws -> Flows.Journal.Brief?
        ) {
            self.directory = directory
            self.now = now
            self.isOnline = isOnline
            self.download = download
            self.refetch = refetch
        }

        /// The file to play for `brief` at `rate`. Throws `.offline` when the audio isn't on the phone and
        /// there's no connection, `.unavailable` when there is no audio to get.
        func playableFile(for brief: Flows.Journal.Brief, rate: Double) async throws -> URL {
            guard let audio = brief.audio else { throw Failure.unavailable }
            let file = fileURL(brief.id)
            if keptDuration(brief.id) == audio.durationSeconds, FileManager.default.fileExists(atPath: file.path) {
                return file
            }
            guard await isOnline() else { throw Failure.offline }
            var current = audio
            let needed = audio.durationSeconds / max(rate, 0.1) + Self.linkMargin
            if audio.expiresAt.timeIntervalSince(now()) < needed {
                guard let fresh = try await refetch(), fresh.id == brief.id, let freshAudio = fresh.audio else {
                    throw Failure.unavailable
                }
                current = freshAudio
            }
            let temporary: URL
            do {
                temporary = try await download(current.url)
            } catch {
                throw Failure.unavailable
            }
            // an empty download is never kept as the brief's audio
            guard Self.isUsable(temporary) else {
                try? FileManager.default.removeItem(at: temporary)
                throw Failure.unavailable
            }
            try store(temporary, as: brief.id, duration: current.durationSeconds)
            return file
        }

        /// The default download: a non-2xx answer (an expired link's 403, a CDN error page) throws, so its body is never kept.
        @Sendable
        static func downloadChecked(_ url: URL) async throws -> URL {
            let (file, response) = try await URLSession.shared.download(from: url)
            guard Self.accepts(response) else {
                try? FileManager.default.removeItem(at: file)
                throw Failure.unavailable
            }
            return file
        }

        /// A 2xx HTTP answer (anything that is not HTTP is refused).
        static func accepts(_ response: URLResponse) -> Bool {
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ..< 300).contains(http.statusCode)
        }

        static func isUsable(_ file: URL) -> Bool {
            let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
            return size > 0
        }

        /// Sign-out: every file goes.
        func erase() {
            try? FileManager.default.removeItem(at: directory)
        }

        private func fileURL(_ briefID: String) -> URL {
            directory.appendingPathComponent("\(briefID).mp3")
        }

        private func lengthURL(_ briefID: String) -> URL {
            directory.appendingPathComponent("\(briefID).length")
        }

        /// The length the kept file was fetched for; a brief whose length changed gets its audio replaced.
        private func keptDuration(_ briefID: String) -> Double? {
            (try? String(contentsOf: lengthURL(briefID), encoding: .utf8)).flatMap(Double.init)
        }

        private func store(_ temporary: URL, as briefID: String, duration: Double) throws {
            let files = FileManager.default
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = fileURL(briefID)
            try? files.removeItem(at: file)
            try files.moveItem(at: temporary, to: file)
            try String(duration).write(to: lengthURL(briefID), atomically: true, encoding: .utf8)
        }
    }
}
