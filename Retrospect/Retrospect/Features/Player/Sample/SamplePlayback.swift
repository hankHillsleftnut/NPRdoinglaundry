//
//  SamplePlayback.swift
//  UI3.0: the player's every state without audio, a network or an audio session. The player
//  parts (scrubber, transport, sheet, mini-player) are built and tested against this, through
//  `Flows.Playback` only. Time comes from the injected clock, never the wall clock.
//
//  It mirrors how the live player reports itself (Platform.Media.LivePlayback): play goes
//  buffering first, then playing on the next beat (the engine's own word); pause, seek and skip
//  never invent "playing"; a seek at or past the end ends it; play after the end starts from 0;
//  a failed or offline item stays failed or offline when tapped (the live retry fails the same).
//
import Foundation
import Observation

extension Flows {
    /// The sample player's starting points, one per state the player parts draw.
    enum PlaybackScenario: String, CaseIterable, Sendable {
        /// Three parts, 2:10, paused at the start.
        case briefPaused
        /// The same brief, playing from 0:48.
        case briefPlaying
        /// The same brief, played to the end.
        case briefPlayed
        /// A quiet day: one part, 0:40.
        case briefQuiet
        /// Asked to play, waiting for audio that never arrives.
        case buffering
        /// The audio could not be loaded.
        case failed
        /// Offline, and this audio isn't on the phone.
        case offline
        /// Twelve parts, 11:30.
        case long
        /// Two parts, 0:45: under a minute, so one capsule and a 15 second forward skip.
        case shortUnderMinute
        /// ON-11, the first episode's tease (Paper 26NO-0): four chapters, 2:10, playing from 0:48.
        case tease
        /// The tease playing at 0:48, held still until something is tapped: the frame compared with Paper.
        case teaseStill
        /// The tease paused at 0:48.
        case teasePaused
        /// The tease played to the end.
        case teaseEnded
    }
}

/// `Flows.Playback` with no sound: the position moves on the injected clock at `rate`.
@MainActor @Observable
final class SamplePlayback: Flows.Playback {
    /// One beat of the sample's clock, in seconds: how often the position moves while playing.
    static let beatSeconds = 0.25
    static let beat: Duration = .seconds(beatSeconds)

    private(set) var item: Flows.PlaybackItem?
    private(set) var state: Flows.PlaybackState = .idle
    private(set) var position: Double = 0
    private(set) var duration: Double?

    /// Episodes show how much is downloaded; briefs are short enough not to.
    var buffered: Double? {
        guard item?.kind == .episode, let duration, duration > 0 else { return nil }
        return 1
    }

    var currentPart: Int? {
        guard let parts = item?.parts, !parts.isEmpty else { return nil }
        return Self.part(at: position, in: parts)
    }

    var rate: Double {
        get {
            access(keyPath: \.rate)
            return storedRate
        }
        set {
            // the live player's range
            withMutation(keyPath: \.rate) { storedRate = min(max(newValue, 0.5), 2) }
        }
    }

    let scenario: Flows.PlaybackScenario
    @ObservationIgnored private var storedRate: Double = 1
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(scenario: Flows.PlaybackScenario, clock: any Clock<Duration>) {
        self.scenario = scenario
        self.clock = clock
        let item = Self.item(for: scenario)
        self.item = item
        duration = item.durationSeconds
        switch scenario {
        case .briefPaused, .briefQuiet, .long, .shortUnderMinute:
            state = .paused
        case .briefPlaying, .tease:
            position = 48
            state = .playing
            run()
        case .teaseStill:
            // playing, as drawn, with no ticker: nothing moves until it's paused and played again
            position = 48
            state = .playing
        case .teasePaused:
            position = 48
            state = .paused
        case .briefPlayed, .teaseEnded:
            position = item.durationSeconds ?? 0
            state = .ended
        case .buffering:
            state = .buffering
        case .failed:
            state = .failed(Flows.Failure(.network))
        case .offline:
            state = .offline
        }
    }

    isolated deinit {
        ticker?.cancel()
    }

    // MARK: Flows.Playback

    func load(_ item: Flows.PlaybackItem) async {
        stop()
        self.item = item
        position = 0
        duration = item.durationSeconds
        state = unplayable ?? .paused
    }

    func play() {
        guard item != nil else { return }
        if let unplayable {
            // a tap on a failed or offline item is a new try that fails the same way
            state = unplayable
            return
        }
        if state == .playing || state == .buffering {
            return
        }
        if state == .ended {
            position = 0
        }
        state = .buffering
        run()
    }

    func pause() {
        stop()
        if state == .playing || state == .buffering {
            state = .paused
        }
    }

    func seek(to seconds: Double) {
        guard item != nil, unplayable == nil, let duration else { return }
        let target = max(seconds, 0)
        if target >= duration {
            position = duration
            stop()
            state = .ended
            return
        }
        position = target
        if state == .ended {
            state = .paused
        }
    }

    func skip(by seconds: Double) {
        seek(to: position + seconds)
    }

    // MARK: Private

    /// The scenario's state for audio that can never play here.
    private var unplayable: Flows.PlaybackState? {
        switch scenario {
        case .failed: .failed(Flows.Failure(.network))
        case .offline: .offline
        default: nil
        }
    }

    private func stop() {
        ticker?.cancel()
        ticker = nil
    }

    private func run() {
        stop()
        let clock = clock
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: Self.beat)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                if !beat() {
                    return
                }
            }
        }
    }

    /// One beat: buffering becomes playing (the buffering scenario never gets there); playing
    /// moves the position by a beat at `rate`, and ends at the end. False when the ticker stops.
    private func beat() -> Bool {
        switch state {
        case .buffering:
            if scenario != .buffering {
                state = .playing
            }
            return true
        case .playing:
            let next = position + Self.beatSeconds * storedRate
            if let duration, next >= duration {
                position = duration
                state = .ended
                ticker = nil
                return false
            }
            position = next
            return true
        default:
            ticker = nil
            return false
        }
    }

    /// The last part that starts at or before `seconds` (parts are in order).
    static func part(at seconds: Double, in parts: [Flows.PlaybackItem.Part]) -> Int? {
        parts.last { $0.startSeconds <= seconds }?.id ?? parts.first?.id
    }

    // MARK: Sample items (invented brief lines, not anyone's words)

    static func item(for scenario: Flows.PlaybackScenario) -> Flows.PlaybackItem {
        switch scenario {
        case .briefPaused, .briefPlaying, .briefPlayed, .buffering, .failed, .offline:
            brief(id: "sample-brief", parts: threeParts, duration: 130)
        case .briefQuiet:
            brief(id: "sample-quiet", parts: [quietPart], duration: 40)
        case .long:
            brief(id: "sample-long", parts: longParts, duration: 690)
        case .shortUnderMinute:
            brief(id: "sample-short", parts: Array(threeParts.prefix(2)).enumerated().map { index, part in
                Flows.PlaybackItem.Part(id: index, title: part.title, text: part.text, startSeconds: Double(index) * 25)
            }, duration: 45)
        case .tease, .teaseStill, .teasePaused, .teaseEnded:
            tease
        }
    }

    /// ON-11's episode (Paper 26NO-0): "the week you started", 2:10 in four chapters whose lengths
    /// draw Paper's capsules (82 : 114 : 62 : 64 ≈ 33 : 46 : 25 : 26 s). Paper names only the second
    /// chapter ("the first thing i noticed", 26OI-0); the others are left untitled, not invented.
    static let tease = Flows.PlaybackItem(
        id: "sample-tease",
        kind: .episode,
        title: "the week you started",
        parts: [
            .init(id: 0, title: nil, text: SampleTranscript.tease.lines[0].text, startSeconds: 0),
            .init(id: 1, title: "the first thing i noticed", text: SampleTranscript.tease.lines[1].text, startSeconds: 33),
            .init(id: 2, title: nil, text: SampleTranscript.tease.lines[3].text, startSeconds: 79),
            .init(id: 3, title: nil, text: SampleTranscript.tease.lines[4].text, startSeconds: 104),
        ],
        durationSeconds: 130
    )

    private static func brief(id: String, parts: [Flows.PlaybackItem.Part], duration: Double) -> Flows.PlaybackItem {
        Flows.PlaybackItem(id: id, kind: .brief, title: "today's brief", parts: parts, durationSeconds: duration)
    }

    /// Brief parts carry no title (contract 02 §3), so the scrubber names them "1 of 3".
    private static let threeParts: [Flows.PlaybackItem.Part] = [
        .init(id: 0, title: nil, text: "You saved a piece on sleep and attention on Tuesday and came back to it twice.", startSeconds: 0),
        .init(id: 1, title: nil, text: "Three runs this week, each a little longer than the last.", startSeconds: 48),
        .init(id: 2, title: nil, text: "You said the call with your sister went better than you expected.", startSeconds: 90),
    ]

    private static let quietPart = Flows.PlaybackItem.Part(
        id: 0, title: nil, text: "A quiet day. Nothing new to tell you, and that's fine.", startSeconds: 0
    )

    private static let longParts: [Flows.PlaybackItem.Part] = (0 ..< 12).map { index in
        .init(id: index, title: nil, text: "A sample line for part \(index + 1) of a long brief.", startSeconds: Double(index) * 57.5)
    }
}
