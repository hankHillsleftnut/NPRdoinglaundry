//
//  GettingReadyModel.swift
//  GR.ready, ON-10 getting ready (Paper p-J-0 26LG-0): the page's decisions, apart from the view so
//  they can be tested on a test clock. Retro asks one more question while the first episode is made.
//  The person keeps answering, by voice or by typing; each answer goes in (`this.week` on
//  `Flows.FirstRun`) and the "going in" chip shows what was just said. While the page is on screen
//  it asks `Flows.FirstEpisode` every 10 s whether the episode is made (the watch from #191's
//  FirstEpisodeModel, moved here); the card's line follows the wait against "~2 min". Once made, the
//  host hears `onReady` exactly once (the tease, ON-11, opens there). No back, no slow, no failed
//  look (founder decision 10). Nothing here logs: the words are the person's.
//
import Foundation
import Observation

@MainActor @Observable
final class GettingReadyModel {
    typealias Key = Flows.QuestionKey

    /// The page's one state. `making` is the drawn one; `ready` is the moment before the host moves on.
    enum Phase: Equatable {
        /// The episode is being made; the person keeps talking.
        case making
        /// The episode is made: the line is full and the host has been told.
        case ready
    }

    /// One word heard (or typed), as the page shows it under the question.
    struct Word: Identifiable, Equatable {
        /// Unique per utterance, place and spelling, so a word that changes arrives again.
        let id: String
        let text: String
        /// Still being recognised: drawn soft (Paper 26MY-0: blur 2, opacity.pending) until final.
        var isPending: Bool
    }

    /// ON-10's place in the flow: 92% in Paper (26NC-0), arriving from connect's 55% (21CF-0).
    static let progress = FlowProgress(from: 0.55, to: 0.92)
    /// How often the page asks while the episode is being made (#191's watch).
    static let refreshEvery: Duration = .seconds(10)
    /// The wait the card promises ("~2 min"); the line follows it.
    static let expectedWait: TimeInterval = 120
    /// While making, the line never reaches the end on its own: only "made" fills it.
    static let makingCap = 0.95

    private(set) var phase: Phase = .making
    /// The words under the question: the utterance being heard, or the last typed answer.
    private(set) var words: [Word] = []
    /// What the chip shows: the words going in now, or the last answer kept.
    private(set) var goingIn: String?
    /// The card's line, 0…1.
    private(set) var episodeProgress: Double = 0
    /// Counts answers that weren't kept, so the page says so once each.
    private(set) var failures = 0
    /// The last answer handed over wasn't kept (until one is): the error haptic fires once per run.
    private(set) var isFailing = false
    /// The composer's words while typing.
    var draft = ""
    /// The composer's look: listening on arrival; muted (the field) after the mic-off corner.
    private(set) var composerMode: RVoiceComposer.Mode = .listening

    /// Each answer the seam kept, for a host that keeps the words (the sample flow).
    @ObservationIgnored var onAnswered: (Key, String) -> Void = { _, _ in }
    /// The episode is made. Called once.
    @ObservationIgnored var onReady: () -> Void = {}

    @ObservationIgnored private let firstRun: any Flows.FirstRun
    @ObservationIgnored private let episode: any Flows.FirstEpisode
    @ObservationIgnored private let listening: any Flows.Listening
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let now: () -> Date
    /// The last answer the seam kept: the chip falls back to it when a send isn't kept.
    @ObservationIgnored private var kept: String?
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private var isOnScreen = false
    /// Words heard but not sent yet (the utterance hasn't ended).
    @ObservationIgnored private var utteranceOpen = false
    @ObservationIgnored private var utterance = 0
    /// Counts sends, so a late outcome of an older one never overwrites a newer answer.
    @ObservationIgnored private var sends = 0

    /// `kept`: the `this.week` answer from an earlier launch (resume): it shows, and the chip holds it.
    init(
        firstRun: any Flows.FirstRun,
        episode: any Flows.FirstEpisode,
        listening: any Flows.Listening,
        kept: String? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.firstRun = firstRun
        self.episode = episode
        self.listening = listening
        self.clock = clock
        self.now = now
        if let kept, !kept.isEmpty {
            self.kept = kept
            goingIn = kept
            words = Self.words(Self.split(kept), utterance: 0, pendingLast: false)
        }
        // the first frame draws the line where the wait is, not at 0; the hand-off waits for `run()`,
        // after the host has set `onReady`
        if case let .waiting(since) = episode.state {
            episodeProgress = Self.progress(since: since, now: now())
        } else {
            episodeProgress = 1
        }
    }

    isolated deinit {
        listener?.cancel()
    }

    // MARK: - Pure rules

    /// The card's line while making: the wait against `expectedWait`, never past `makingCap`.
    static func progress(since: Date, now: Date) -> Double {
        let share = now.timeIntervalSince(since) / expectedWait
        return min(max(share, 0), makingCap)
    }

    /// Words for one utterance; the last is pending while it is still being recognised.
    static func words(_ texts: [String], utterance: Int, pendingLast: Bool) -> [Word] {
        texts.enumerated().map { index, text in
            Word(id: "\(utterance)-\(index)-\(text)", text: text, isPending: pendingLast && index == texts.count - 1)
        }
    }

    /// What the words say, as one line.
    var spokenWords: String {
        words.map(\.text).joined(separator: " ")
    }

    // MARK: - Page events

    /// The page's `.task`: listen, and watch the episode until it is made or the page goes away.
    func run() async {
        isOnScreen = true
        if composerMode == .listening {
            startListening()
        }
        await watch()
    }

    /// The page went off screen: no listening without the page; the watch ends with the `.task`.
    func pageLeft() {
        isOnScreen = false
        stopListening()
    }

    /// The composer's corner switched talking and typing. Muted: listening stops and any words heard
    /// but not sent move into the field, so nothing said is lost. Listening again: it listens.
    func setComposerMode(_ mode: RVoiceComposer.Mode) {
        guard mode != composerMode else { return }
        composerMode = mode
        if mode == .muted {
            stopListening()
            if utteranceOpen {
                utteranceOpen = false
                draft = QuestionsModel.restored(failed: spokenWords, typed: draft)
                goingIn = kept
                // the half-heard words now live in the field; the page shows the last kept answer
                words = Self.words(Self.split(kept), utterance: utterance, pendingLast: false)
            }
        } else if mode == .listening, isOnScreen {
            startListening()
        }
    }

    /// One thing heard.
    func heard(_ event: Flows.Heard) async {
        switch event {
        case let .partial(texts):
            if !utteranceOpen {
                utteranceOpen = true
                utterance += 1
            }
            words = Self.words(texts, utterance: utterance, pendingLast: true)
            // what you're saying is going in as you say it (Paper draws the chip beside the live words)
            goingIn = texts.isEmpty ? kept : spokenWords
        case .ended:
            guard utteranceOpen else { return }
            utteranceOpen = false
            for index in words.indices {
                words[index].isPending = false
            }
            await send(spokenWords, given: .voice)
        }
    }

    /// The composer's send (typing).
    func sendTyped(_ text: String) async {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        draft = ""
        utterance += 1
        words = Self.words(Self.split(typed), utterance: utterance, pendingLast: false)
        goingIn = typed
        await send(typed, given: .typed)
    }

    // MARK: - Private

    /// Hands one answer to the seam. Kept: the chip holds it. Not kept: the chip goes back to the
    /// last kept answer, the words wait in the field (typing), and the page says so once.
    /// Sends can overlap (a voice answer still saving when a typed one goes): only the newest
    /// decides what the chip, the kept answer and the field show; an older one's outcome is the
    /// seam's alone (it already holds or keeps those words).
    private func send(_ text: String, given: Flows.FirstRunQuestion.Given) async {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        sends += 1
        let attempt = sends
        let outcome = await firstRun.answer(.thisWeek, text: words, given: given)
        guard attempt == sends else { return }
        switch outcome {
        case .saved:
            kept = words
            goingIn = words
            isFailing = false
            onAnswered(.thisWeek, words)
        case .failedKept:
            failures += 1
            isFailing = true
            goingIn = kept
            draft = QuestionsModel.restored(failed: words, typed: draft)
            // the words are in the field now: show it
            setComposerMode(.muted)
        }
    }

    /// Words of a line, for the page.
    private static func split(_ line: String?) -> [String] {
        line?.split(separator: " ").map(String.init) ?? []
    }

    private func startListening() {
        listener?.cancel()
        let stream = listening.listen()
        listener = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                await heard(event)
            }
        }
    }

    private func stopListening() {
        listener?.cancel()
        listener = nil
        listening.stop()
    }

    /// #191's watch: settle, then ask every `refreshEvery` until made; a cancelled page ends it.
    private func watch() async {
        await settle()
        while phase == .making {
            do {
                try await clock.sleep(for: Self.refreshEvery)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await episode.refresh()
            guard !Task.isCancelled else { return }
            await settle()
        }
    }

    /// Reads the seam: the line while waiting; made (with or without its audio) hands off.
    private func settle() async {
        switch episode.state {
        case let .waiting(since):
            episodeProgress = Self.progress(since: since, now: now())
        case .ready, .unavailable:
            await becomeReady()
        }
    }

    /// Made: a sentence still being heard goes in first (the host may leave at once), then the line
    /// fills and the host hears it, once. Listening carries on while the page stays: what is said
    /// after this still reaches the seam (it informs the next episodes), as "it all goes in" says.
    private func becomeReady() async {
        guard phase == .making else { return }
        phase = .ready
        if utteranceOpen {
            utteranceOpen = false
            for index in words.indices {
                words[index].isPending = false
            }
            await send(spokenWords, given: .voice)
        }
        episodeProgress = 1
        onReady()
    }

    // MARK: - Words (Paper ON-10 26LG-0, verbatim; lowercase is the design system's)

    static let question = "while i get your first episode ready: what's one thing you want this week to go well?"
    static let cardTitle = "your first episode"
    static let cardLine = "weaving in what you just said · ~2 min"
    static let keepTalking = "keep talking; it all goes in."
    /// Read when the page arrives: where you are, then the question.
    static let arrival = "getting your first episode ready. \(question)"
    /// Read when the episode is made.
    static let readyAnnouncement = "your first episode is ready."
}
