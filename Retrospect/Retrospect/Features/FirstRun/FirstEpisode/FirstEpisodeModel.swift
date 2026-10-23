//
//  FirstEpisodeModel.swift
//  P05.min: the "your first episode" page's decisions, apart from the view so they can be tested
//  on a test clock. While the page is on screen and the episode is still being made it asks the
//  seam every 10 s (never by itself, never off screen); after 15 minutes the wait is "slow" and
//  offers the journal. Once ready it loads the episode into the player, paused: play is the
//  person's tap. Leaving the page pauses the player (0.1 has no mini-player, so audio never plays
//  without a control on screen). Nothing here logs: the title is the person's content.
//
import Foundation
import Observation

@MainActor @Observable
final class FirstEpisodeModel {
    /// How the page was left, for the host.
    enum Exit: Equatable {
        /// "continue" (ready or unavailable): first run is done.
        case continued
        /// "go to my journal" from the slow wait: the episode lands in podcasts later.
        case journal
    }

    /// What the page draws.
    enum Look: Equatable {
        case waiting, slow, ready, unavailable
    }

    /// How often the page asks while waiting.
    static let refreshEvery: Duration = .seconds(10)
    /// How long a wait is before the page calls it slow.
    static let slowAfter: TimeInterval = 15 * 60

    let source: any Flows.FirstEpisode
    let playback: any Flows.Playback

    /// Waiting for longer than `slowAfter`, as of the last check.
    private(set) var isSlow = false
    /// The ready episode is in the player: the scrubber and transport show only then, so they never
    /// draw another item.
    private(set) var isPlayerLoaded = false

    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let finish: (Exit) -> Void
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var loadedID: String?
    @ObservationIgnored private var hasFinished = false

    init(
        source: any Flows.FirstEpisode,
        playback: any Flows.Playback,
        clock: any Clock<Duration>,
        now: @escaping () -> Date = { Date() },
        finish: @escaping (Exit) -> Void
    ) {
        self.source = source
        self.playback = playback
        self.clock = clock
        self.now = now
        self.finish = finish
        // the page's first frame: a wait already past 15 minutes draws slow, not the plain line
        // that then blur-replaces (appear() runs after that frame is built)
        checkSlow()
    }

    isolated deinit {
        watcher?.cancel()
    }

    var look: Look {
        switch source.state {
        case .waiting: isSlow ? .slow : .waiting
        case .ready: .ready
        case .unavailable: .unavailable
        }
    }

    /// The episode's title once there is one.
    var episodeTitle: String? {
        switch source.state {
        case .waiting: nil
        case let .ready(_, title, _): title
        case let .unavailable(title): title
        }
    }

    /// Whether the page is watching (on screen, still waiting).
    var isWatching: Bool {
        watcher != nil
    }

    // MARK: Page events

    /// The page appeared: check where things are, then ask every 10 s until it's made.
    func appear() {
        guard watcher == nil, !hasFinished else { return }
        // back on screen after a while: slow at once, not after the first ask
        checkSlow()
        watcher = Task { [weak self] in
            await self?.watch()
        }
    }

    /// The page left (navigation, the app going away): stop asking and pause the player.
    func leave() {
        stopWatching()
        playback.pause()
    }

    /// "continue": the player stops and the host moves on. Reported once, however many taps.
    func continueTapped() {
        exit(.continued)
    }

    /// "go to my journal" on the slow wait.
    func journalTapped() {
        exit(.journal)
    }

    // MARK: Private

    private func exit(_ how: Exit) {
        guard !hasFinished else { return }
        hasFinished = true
        leave()
        finish(how)
    }

    private func stopWatching() {
        watcher?.cancel()
        watcher = nil
    }

    private var isWaiting: Bool {
        if case .waiting = source.state {
            return true
        }
        return false
    }

    private func watch() async {
        await settle()
        while isWaiting {
            do {
                try await clock.sleep(for: Self.refreshEvery)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await source.refresh()
            guard !Task.isCancelled else { return }
            await settle()
        }
        // a cancelled watch must not clear the watch a later appear started
        if !Task.isCancelled {
            watcher = nil
        }
    }

    private func checkSlow() {
        if case let .waiting(since) = source.state {
            isSlow = now().timeIntervalSince(since) >= Self.slowAfter
        }
    }

    /// Reads the seam's state: the slow check while waiting, the player load once ready.
    private func settle() async {
        switch source.state {
        case .waiting:
            checkSlow()
        case let .ready(item, _, _):
            guard loadedID != item.id else { return }
            loadedID = item.id
            // loaded paused at the start: play waits for the person's tap
            await playback.load(item)
            isPlayerLoaded = true
        case .unavailable:
            break
        }
    }

    /// What VoiceOver says when the page changes under the person (the headline is swapped, not
    /// moved to, so nothing is read on its own): the slow pair, the ready line, or the title when
    /// it arrives without its audio. Nothing for the plain wait (it's the line on arrival).
    static func announcement(for look: Look, title: String?) -> String? {
        switch look {
        case .waiting: nil
        case .slow: "\(slowLine) \(slowDescription)"
        case .ready: readyLine
        case .unavailable: title
        }
    }

    // MARK: Words (ON-10 board copy and the RELEASE 0.1 defaults; the founder may change them)

    static let barTitle = "your first episode"
    static let waitingLine = "i'm putting your first episode together. it takes a few minutes."
    /// The slow line is the board's one sentence pair, drawn as a title and its one description
    /// (screen-rules 1) so the inky title stays within three lines.
    static let slowLine = "this is taking longer than usual."
    static let slowDescription = "you can go to your journal; it will be in your podcasts when it's ready."
    static let journalButton = "go to my journal"
    static let readyLine = "it's ready. here's the first thing i noticed."
    static let continueButton = "continue"
}
