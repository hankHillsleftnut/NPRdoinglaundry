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
        /// ON-11, the first episode's tease (Paper 26NO-0): 10 seconds in one part (founder Q5 = B),
        /// playing from the start.
        case tease
        /// The tease playing at 0:04, on the line Paper lights, held still until something is tapped:
        /// the frame compared with Paper.
        case teaseStill
        /// The tease paused at 0:04.
        case teasePaused
        /// The tease played to the end.
        case teaseEnded
        /// PC-2, this week's episode (Paper 1FV9-0): four chapters, 11:30, playing from 4:12 in
        /// chapter 2, "the river".
        case weeklyEpisode
        /// The weekly episode playing at 4:12 on the line Paper lights, held still until something is
        /// tapped: the frame compared with Paper.
        case weeklyEpisodeStill
        /// JR-2 (Paper 1FMG-0): today's brief as Paper draws it, 4:10 in three parts (1:30, 1:20, 1:20),
        /// playing at 0:48 in part 1, held still until something is tapped: the frame compared with Paper.
        case briefPaperPlaying
        /// JR-2 paused (GLN-0): the same brief, paused at 0:48.
        case briefPaperPaused
        /// JR-2 played (GNY-0): the same brief, played to the end.
        case briefPaperPlayed
        /// JR-2 quiet day (GQ9-0): one part, 0:40, playing at 0:12, held still.
        case briefPaperQuiet
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
        if Self.weeklyScenarios.contains(scenario) {
            // Paper 1FV9-0 draws the downloaded stretch ending inside chapter 2
            return Self.weeklyBuffered / duration
        }
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

    // one start per scenario, listed flat so scenarios are only ever added (V2 add-only lease)
    // swiftlint:disable:next cyclomatic_complexity
    init(scenario: Flows.PlaybackScenario, clock: any Clock<Duration>) {
        self.scenario = scenario
        self.clock = clock
        let item = Self.item(for: scenario)
        self.item = item
        duration = item.durationSeconds
        switch scenario {
        case .briefPaused, .briefQuiet, .long, .shortUnderMinute:
            state = .paused
        case .briefPlaying:
            position = 48
            state = .playing
            run()
        case .tease:
            state = .playing
            run()
        case .teaseStill:
            // playing, as drawn, with no ticker: nothing moves until it's paused and played again
            position = Self.teaseLitLine
            state = .playing
        case .teasePaused:
            position = Self.teaseLitLine
            state = .paused
        case .briefPlayed, .teaseEnded:
            position = item.durationSeconds ?? 0
            state = .ended
        case .briefPaperPlaying, .briefPaperQuiet:
            // playing, as drawn, with no ticker (like `teaseStill`): pause and play to move on
            position = scenario == .briefPaperQuiet ? Self.briefPaperQuietAt : Self.briefPaperAt
            state = .playing
        case .briefPaperPaused:
            position = Self.briefPaperAt
            state = .paused
        case .briefPaperPlayed:
            position = item.durationSeconds ?? 0
            state = .ended
        case .buffering:
            state = .buffering
        case .failed:
            state = .failed(Flows.Failure(.network))
        case .offline:
            state = .offline
        case .weeklyEpisode, .weeklyEpisodeStill:
            startWeekly()
        }
    }

    /// The weekly episode's starting points (PC-2), apart from `init` so the tease's lines stay as they were (Paper draws
    /// PC-2 playing only; founder 27 Oct: no undrawn states).
    private func startWeekly() {
        switch scenario {
        case .weeklyEpisode:
            position = Self.weeklyLitLine
            state = .playing
            run()
        case .weeklyEpisodeStill:
            // playing, as drawn, with no ticker (like the tease's still)
            position = Self.weeklyLitLine
            state = .playing
        default:
            break
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
        case .weeklyEpisode, .weeklyEpisodeStill:
            weeklyEpisode
        case .briefPaperPlaying, .briefPaperPaused, .briefPaperPlayed:
            briefPaper
        case .briefPaperQuiet:
            briefPaperQuiet
        }
    }

    /// ON-11's episode: "the week you started", 10 seconds in one untitled part (founder Q5 = B, 26 Oct:
    /// one capsule, "00:00 / −00:10", no chapter name). Its words are all five of Paper's lines.
    static let tease = Flows.PlaybackItem(
        id: SampleTranscript.teaseID,
        kind: .episode,
        title: "the week you started",
        parts: [
            .init(id: 0, title: nil, text: SampleTranscript.tease.lines.map(\.text).joined(separator: " "), startSeconds: 0),
        ],
        durationSeconds: 10
    )

    /// Where the tease reads the line Paper lights (the third, 26PC-0).
    static let teaseLitLine: Double = 4

    /// PC-2's episode (Paper 1FV9-0): "the week you kept choosing the river", 11:30 in four chapters
    /// whose lengths are Paper's capsules (82 : 114 : 62 : 64), so 4:12 falls in chapter 2, "the river",
    /// with 7:18 left. Chapters 1 and 2 carry Paper's five lines (1FWZ-0 … 1FWV-0); chapter 2's title is
    /// Paper's; the other titles and chapters 3 and 4's words are invented sample lines.
    static let weeklyEpisode = Flows.PlaybackItem(
        id: weeklyEpisodeID,
        kind: .episode,
        title: "the week you kept choosing the river",
        parts: [
            .init(id: 0, title: "a quiet start", text: weeklyLines[0 ..< 2].joined(separator: " "), startSeconds: 0),
            .init(id: 1, title: "the river", text: weeklyLines[2 ..< 5].joined(separator: " "), startSeconds: 176),
            .init(id: 2, title: "your sister", text: "A sample line for the third chapter.", startSeconds: 420),
            .init(id: 3, title: "a guess", text: "A sample line for the last chapter.", startSeconds: 553),
        ],
        durationSeconds: 690
    )

    /// The weekly episode's `PlaybackItem.id` (its transcript names it).
    static let weeklyEpisodeID = "sample-weekly"

    /// Paper's five transcript lines on PC-2 (1FWZ-0 … 1FWV-0), word for word.
    static let weeklyLines = [
        "This week started quietly. Two short entries, a long Sunday walk.",
        "On Monday you wrote that the meeting went badly, and that you didn't want to talk about it.",
        "That evening you walked to the river. Then again on Wednesday, and again on Friday.",
        "Each time, you called your sister afterwards, not before.",
        "So here is a guess, and you can tell me if it's wrong.",
    ]

    /// Where the weekly episode reads the line Paper lights (the third, 1FWX-0): 04:12.
    static let weeklyLitLine: Double = 252

    /// How far the weekly episode is downloaded, in seconds (Paper 1FWB-0: the grey stretch ends
    /// 104 of 118 points into chapter 2).
    static let weeklyBuffered: Double = 391

    /// Every scenario that plays the weekly episode.
    static let weeklyScenarios: Set<Flows.PlaybackScenario> = [.weeklyEpisode, .weeklyEpisodeStill]

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

    // MARK: JR-2 as Paper draws it (V2.journal, add-only)

    /// Where Paper's brief is drawn: 0:48 into part 1 (1FNB-0 "00:48", "−03:22").
    static let briefPaperAt: Double = 48
    /// Where Paper's quiet brief is drawn: 0:12 of 0:40 (GQ9-0).
    static let briefPaperQuietAt: Double = 12

    /// Paper's brief (1FMG-0): titled by its headline, three parts whose capsules Paper draws
    /// 90 : 80 : 80 (1FNE-0). The parts carry Paper's short names ("1 of 3 · the article"); the
    /// contract's parts have no title yet (DISCREPANCIES J-20).
    static let briefPaper = Flows.PlaybackItem(
        id: "sample-brief-paper",
        kind: .brief,
        title: "a heavier week than usual, and it shows.",
        parts: [
            .init(id: 0, title: "the article", text: "the fundraise article you sent", startSeconds: 0),
            .init(id: 1, title: "the meetings", text: "four meetings before noon", startSeconds: 90),
            .init(id: 2, title: "the sleep", text: "five hours of sleep, two nights running", startSeconds: 170),
        ],
        durationSeconds: 250
    )

    /// Paper's quiet day (GQ9-0): one untitled part, 40 seconds.
    static let briefPaperQuiet = Flows.PlaybackItem(
        id: "sample-brief-paper-quiet",
        kind: .brief,
        title: "a quiet tuesday",
        parts: [.init(id: 0, title: nil, text: "nothing much moved. enjoy the quiet.", startSeconds: 0)],
        durationSeconds: 40
    )
}
