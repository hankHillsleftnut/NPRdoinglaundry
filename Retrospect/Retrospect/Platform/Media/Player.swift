import Foundation
import Observation

extension Platform.Media {
    /// What the audio engine reports. The player's state comes only from these, never from the
    /// player's own commands: "playing" means the engine is producing sound.
    enum EngineEvent: Equatable, Sendable {
        case time(Double)
        case duration(Double)
        /// Asked to play, waiting for data.
        case buffering
        case playing
        case paused
        case ended
        /// The item can't be played (bad data, an expired link).
        case failed
    }

    /// The thing that makes sound: one item at a time. `AVPlayerEngine` is the real one; tests use a fake.
    @MainActor
    protocol Engine: AnyObject {
        var events: AsyncStream<EngineEvent> { get }
        /// Loads `url` paused at the start, replacing whatever was loaded (and its observers).
        func replaceItem(with url: URL)
        func play(rate: Double)
        func pause()
        func setRate(_ rate: Double)
        func seek(to seconds: Double) async
        /// Unloads the item and its observers.
        func clear()
    }

    enum InterruptionEvent: Equatable, Sendable {
        case began
        case ended(shouldResume: Bool)
    }

    /// The audio session: how the app takes and gives up the speaker, and what interrupts it.
    @MainActor
    protocol AudioSession: AnyObject {
        /// Category `.playback`, mode `.spokenAudio`, the long-form route, never mixing with other audio.
        func prepare() throws
        func activate() throws
        /// Gives the session back, telling other apps they may resume.
        func deactivate()
        var interruptions: AsyncStream<InterruptionEvent> { get }
        /// The headphones (or other output) went away.
        var routeLosses: AsyncStream<Void> { get }
        var mediaServicesResets: AsyncStream<Void> { get }
    }

    /// Why audio could not be played, for the log (a count, never a title or an address).
    enum Trouble: Equatable, Sendable, CaseIterable {
        case sessionPrepare, sessionActivate, itemFailed, couldNotLoad
    }

    /// Posted by the journal's recorder when recording starts, so the player pauses first.
    static let recordingStarted = Notification.Name("com.shauryanarang.Retrospect.recordingStarted")

    /// The one player in the app (PLP.1a): `Flows.Playback` over an `Engine` and an `AudioSession`.
    ///
    /// Rules: the state is the engine's, never optimistic; the session is prepared before every play
    /// and given back after five minutes paused or on unload; a phone call or the headphones coming
    /// out pause it and nothing resumes it but the person's tap; a media-services reset rebuilds the
    /// item where it was. Everything it keeps is dropped on sign-out (`unload`).
    @MainActor @Observable
    final class LivePlayback: Flows.Playback {
        /// How long a pause lasts before the session is given back.
        static let sessionHold: Duration = .seconds(5 * 60)

        typealias Resolve = @Sendable (Flows.PlaybackItem, Double) async throws -> URL

        private(set) var item: Flows.PlaybackItem?
        private(set) var state: Flows.PlaybackState = .idle
        private(set) var position: Double = 0
        private(set) var duration: Double?
        var buffered: Double? {
            nil
        }

        var rate: Double {
            get {
                access(keyPath: \.rate)
                return storedRate
            }
            set {
                withMutation(keyPath: \.rate) { storedRate = min(max(newValue, 0.5), 2) }
                engine.setRate(storedRate)
            }
        }

        /// The part playing now, from the position and the parts' starts.
        var currentPart: Int? {
            guard let parts = item?.parts, !parts.isEmpty else { return nil }
            return Self.part(at: position, in: parts)
        }

        @ObservationIgnored private var storedRate: Double = 1
        @ObservationIgnored private let engine: any Engine
        @ObservationIgnored private let session: any AudioSession
        @ObservationIgnored private let resolve: Resolve
        @ObservationIgnored private let log: any Platform.LogSink
        @ObservationIgnored private let clock: any Clock<Duration>
        @ObservationIgnored private var loadedURL: URL?
        @ObservationIgnored private var generation = 0
        @ObservationIgnored private var sessionActive = false
        @ObservationIgnored private var watching: [Task<Void, Never>] = []
        @ObservationIgnored private var release: Task<Void, Never>?
        @ObservationIgnored private var recordingObserver: NSObjectProtocol?

        init(
            engine: any Engine,
            session: any AudioSession,
            resolve: @escaping Resolve,
            log: any Platform.LogSink,
            clock: any Clock<Duration> = ContinuousClock(),
            notifications: NotificationCenter = .default
        ) {
            self.engine = engine
            self.session = session
            self.resolve = resolve
            self.log = log
            self.clock = clock
            watch()
            recordingObserver = notifications.addObserver(forName: Platform.Media.recordingStarted, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pauseForRecording() }
            }
        }

        isolated deinit {
            watching.forEach { $0.cancel() }
            release?.cancel()
            if let recordingObserver {
                NotificationCenter.default.removeObserver(recordingObserver)
            }
        }

        // MARK: Loading

        func load(_ item: Flows.PlaybackItem) async {
            generation += 1
            let mine = generation
            release?.cancel()
            engine.clear()
            loadedURL = nil
            self.item = item
            position = 0
            duration = item.durationSeconds
            state = .buffering
            do {
                let url = try await resolve(item, rate)
                guard mine == generation else { return }
                loadedURL = url
                engine.replaceItem(with: url)
                state = .paused
            } catch {
                guard mine == generation, !(error is CancellationError) else { return }
                if let failure = error as? Platform.Media.Source.Failure, failure == .offline {
                    state = .offline
                } else {
                    log.record(.playbackTrouble(.couldNotLoad))
                    state = .failed(Flows.Failure(.unknown))
                }
            }
        }

        /// Gives up the item and the session: nothing is loaded, nothing is audible. Sign-out, a stop.
        func unload() {
            generation += 1
            release?.cancel()
            engine.clear()
            loadedURL = nil
            item = nil
            state = .idle
            position = 0
            duration = nil
            deactivateSession()
        }

        // MARK: Commands

        func play() {
            guard let item else { return }
            if loadedURL == nil {
                // Offline or failed earlier: a tap is a new try.
                Task {
                    await load(item)
                    if loadedURL != nil {
                        start()
                    }
                }
                return
            }
            start()
        }

        func pause() {
            engine.pause()
            if state == .playing || state == .buffering {
                state = .paused
            }
            holdSession()
        }

        func seek(to seconds: Double) {
            guard loadedURL != nil else { return }
            let target = max(seconds, 0)
            if let duration, target >= duration {
                position = duration
                engine.pause()
                state = .ended
                holdSession()
                return
            }
            position = target
            if state == .ended {
                state = .paused
            }
            Task { await engine.seek(to: target) }
        }

        func skip(by seconds: Double) {
            seek(to: position + seconds)
        }

        /// The recorder is about to listen: stop talking. Never resumed by itself.
        func pauseForRecording() {
            guard state == .playing || state == .buffering else { return }
            pause()
        }

        // MARK: Private

        private func start() {
            do {
                try session.prepare()
            } catch {
                log.record(.playbackTrouble(.sessionPrepare))
                state = .failed(Flows.Failure(.unknown))
                return
            }
            if !sessionActive {
                do {
                    try session.activate()
                    sessionActive = true
                } catch {
                    log.record(.playbackTrouble(.sessionActivate))
                    state = .failed(Flows.Failure(.unknown))
                    return
                }
            }
            release?.cancel()
            if state == .ended {
                position = 0
                Task { await engine.seek(to: 0) }
            }
            engine.play(rate: rate)
        }

        /// After a pause lasts, the session goes back so other apps' audio can return.
        private func holdSession() {
            release?.cancel()
            let clock = clock
            release = Task { [weak self] in
                try? await clock.sleep(for: Self.sessionHold)
                guard !Task.isCancelled else { return }
                self?.deactivateSession()
            }
        }

        private func deactivateSession() {
            guard sessionActive else { return }
            sessionActive = false
            session.deactivate()
        }

        private func watch() {
            let events = engine.events
            let interruptions = session.interruptions
            let routes = session.routeLosses
            let resets = session.mediaServicesResets
            watching = [
                Task { [weak self] in
                    for await event in events {
                        self?.handle(event)
                    }
                },
                Task { [weak self] in
                    // a call (or Siri, an alarm) pauses; the end of it never resumes by itself
                    for await event in interruptions where event == .began {
                        self?.pauseForRecording()
                    }
                },
                Task { [weak self] in
                    for await _ in routes {
                        self?.pauseForRecording()
                    }
                },
                Task { [weak self] in
                    for await _ in resets {
                        await self?.rebuild()
                    }
                },
            ]
        }

        private func handle(_ event: EngineEvent) {
            guard loadedURL != nil else { return }
            switch event {
            case let .time(seconds):
                position = seconds
            case let .duration(seconds):
                duration = seconds
            case .buffering, .playing, .paused:
                handleTimeControl(event)
            case .ended:
                if let duration {
                    position = duration
                }
                state = .ended
                holdSession()
            case .failed:
                log.record(.playbackTrouble(.itemFailed))
                state = .failed(Flows.Failure(.network))
            }
        }

        /// The engine's own word on whether it is waiting, producing sound or stopped.
        private func handleTimeControl(_ event: EngineEvent) {
            switch event {
            case .buffering:
                if state != .ended {
                    state = .buffering
                }
            case .playing:
                state = .playing
            default:
                if state == .playing || state == .buffering {
                    state = .paused
                }
            }
        }

        /// The system rebuilt its audio services: the item goes back where it was, paused.
        private func rebuild() async {
            guard let item, loadedURL != nil else { return }
            let at = position
            sessionActive = false
            await load(item)
            if loadedURL != nil {
                position = at
                await engine.seek(to: at)
            }
        }

        /// The last part that starts at or before `seconds` (parts are in order).
        static func part(at seconds: Double, in parts: [Flows.PlaybackItem.Part]) -> Int? {
            var low = 0
            var high = parts.count - 1
            var found: Int?
            while low <= high {
                let middle = (low + high) / 2
                if parts[middle].startSeconds <= seconds {
                    found = middle
                    low = middle + 1
                } else {
                    high = middle - 1
                }
            }
            return found.map { parts[$0].id }
        }
    }
}
