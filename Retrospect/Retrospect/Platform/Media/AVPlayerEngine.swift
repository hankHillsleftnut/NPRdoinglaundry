import AVFoundation
import Foundation

extension Platform.Media {
    /// The real engine: one `AVPlayer`. Every observer belongs to the item that was loaded when it was
    /// made and is removed when the item changes or the engine goes (the old player leaked its end observer).
    @MainActor
    final class AVPlayerEngine: Engine {
        let events: AsyncStream<EngineEvent>
        private let continuation: AsyncStream<EngineEvent>.Continuation
        private var player: AVPlayer
        /// The player's own timeControlStatus observation; the item's live in `itemObservations`.
        private var playerObservation: NSKeyValueObservation?
        private var timeObserver: Any?
        private var itemObservations: [NSKeyValueObservation] = []
        private var endObserver: NSObjectProtocol?

        init() {
            (events, continuation) = AsyncStream.makeStream(of: EngineEvent.self, bufferingPolicy: .unbounded)
            player = AVPlayer()
            observePlayer()
        }

        isolated deinit {
            removeItemObservers()
            playerObservation?.invalidate()
            continuation.finish()
        }

        /// After a media-services reset the old `AVPlayer` is dead (Apple: dispose of and recreate every
        /// audio object): its observers go with it and a fresh one, with nothing loaded, takes its place.
        func rebuildPlayer() {
            removeItemObservers()
            playerObservation?.invalidate()
            player.pause()
            player.replaceCurrentItem(with: nil)
            player = AVPlayer()
            observePlayer()
        }

        private func observePlayer() {
            player.automaticallyWaitsToMinimizeStalling = true
            let continuation = continuation
            playerObservation = player.observe(\.timeControlStatus, options: [.new]) { player, _ in
                let status = player.timeControlStatus
                continuation.yield(Self.event(for: status))
            }
        }

        func replaceItem(with url: URL) {
            removeItemObservers()
            let item = AVPlayerItem(url: url)
            item.audioTimePitchAlgorithm = .timeDomain
            let continuation = continuation
            itemObservations.append(item.observe(\.status, options: [.new]) { item, _ in
                switch item.status {
                case .failed:
                    continuation.yield(.failed)
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    if seconds.isFinite, seconds > 0 {
                        continuation.yield(.duration(seconds))
                    }
                default:
                    break
                }
            })
            endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { _ in
                continuation.yield(.ended)
            }
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { time in
                let seconds = time.seconds
                if seconds.isFinite {
                    continuation.yield(.time(seconds))
                }
            }
            player.replaceCurrentItem(with: item)
        }

        func play(rate: Double) {
            player.defaultRate = Float(rate)
            player.playImmediately(atRate: Float(rate))
        }

        func pause() {
            player.pause()
        }

        func setRate(_ rate: Double) {
            player.defaultRate = Float(rate)
            if player.timeControlStatus != .paused {
                player.rate = Float(rate)
            }
        }

        func seek(to seconds: Double) async {
            await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }

        func clear() {
            removeItemObservers()
            player.pause()
            player.replaceCurrentItem(with: nil)
        }

        private func removeItemObservers() {
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            itemObservations.forEach { $0.invalidate() }
            itemObservations = []
        }

        nonisolated static func event(for status: AVPlayer.TimeControlStatus) -> EngineEvent {
            switch status {
            case .playing: .playing
            case .waitingToPlayAtSpecifiedRate: .buffering
            default: .paused
            }
        }
    }

    /// The real audio session.
    @MainActor
    final class SystemAudioSession: AudioSession {
        let interruptions: AsyncStream<InterruptionEvent>
        let routeLosses: AsyncStream<Void>
        let mediaServicesResets: AsyncStream<Void>
        private var tokens: [NSObjectProtocol] = []
        private let center: NotificationCenter

        init(center: NotificationCenter = .default) {
            self.center = center
            let (interruptions, interruptionFeed) = AsyncStream.makeStream(of: InterruptionEvent.self, bufferingPolicy: .unbounded)
            let (routeLosses, routeFeed) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .unbounded)
            let (resets, resetFeed) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .unbounded)
            self.interruptions = interruptions
            self.routeLosses = routeLosses
            mediaServicesResets = resets
            tokens = [
                center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
                    if let event = Self.interruption(from: note.userInfo) {
                        interruptionFeed.yield(event)
                    }
                },
                center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
                    let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                    if raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                        routeFeed.yield()
                    }
                },
                center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
                    resetFeed.yield()
                },
            ]
        }

        isolated deinit {
            tokens.forEach { center.removeObserver($0) }
        }

        func prepare() throws {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
        }

        func activate() throws {
            try AVAudioSession.sharedInstance().setActive(true)
        }

        func deactivate() {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        nonisolated static func interruption(from info: [AnyHashable: Any]?) -> InterruptionEvent? {
            guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return nil }
            switch type {
            case .began:
                return .began
            case .ended:
                let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init(rawValue:))
                return .ended(shouldResume: options?.contains(.shouldResume) ?? false)
            @unknown default:
                return nil
            }
        }
    }
}
