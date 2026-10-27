//
//  SampleFirstEpisode.swift
//  P05.min: `Flows.FirstEpisode` with no network, one scenario per state the page draws. The
//  episode is invented (not anyone's words); its audio is SamplePlayback's, so the page plays on
//  the injected clock like the rest of the player parts.
//
import Foundation
import Observation

extension Flows {
    /// The sample first episode's starting points.
    enum FirstEpisodeScenario: String, CaseIterable, Sendable {
        /// Waiting; becomes ready after `SampleFirstEpisode.refreshesToReady` refreshes.
        case becomesReady
        /// Waiting for 16 minutes already, and it stays waiting.
        case slow
        /// Ready from the start.
        case ready
        /// Made, but without its audio.
        case unavailable
        /// GR.ready (ON-10): 66 s into the ~2 min wait (Paper's line at 55%), and it stays waiting.
        case making
        /// GR.ready: as `making`, then made after `SampleFirstEpisode.refreshesToReadyOnScreen` refreshes.
        case makingThenReady
    }
}

@MainActor @Observable
final class SampleFirstEpisode: Flows.FirstEpisode {
    /// How many refreshes `becomesReady` waits (at the page's 10 s, about 20 s on the lab page).
    static let refreshesToReady = 2

    private(set) var state: Flows.FirstEpisodeState
    /// Every `refresh()` so far, for tests.
    private(set) var refreshes = 0

    let scenario: Flows.FirstEpisodeScenario

    init(scenario: Flows.FirstEpisodeScenario, now: Date = Date()) {
        self.scenario = scenario
        switch scenario {
        case .becomesReady:
            state = .waiting(since: now)
        case .slow:
            state = .waiting(since: now.addingTimeInterval(-16 * 60))
        case .ready:
            state = Self.readyState
        case .unavailable:
            state = .unavailable(title: Self.title)
        case .making, .makingThenReady:
            state = .waiting(since: now.addingTimeInterval(-Self.makingElapsed))
        }
    }

    /// GR.ready: how far into the wait the sample starts (66 of the ~120 s: Paper's 55% line).
    static let makingElapsed: TimeInterval = 66
    /// GR.ready: refreshes before `makingThenReady` is made (three 10 s asks: about 30 s on screen).
    static let refreshesToReadyOnScreen = 3

    func refresh() async {
        refreshes += 1
        if scenario == .becomesReady, refreshes >= Self.refreshesToReady {
            state = Self.readyState
        }
        if scenario == .makingThenReady, refreshes >= Self.refreshesToReadyOnScreen {
            state = Self.readyState
        }
    }

    // MARK: The sample episode (invented)

    static let title = "the week you started running again"

    static let item = Flows.PlaybackItem(
        id: "sample-first-episode",
        kind: .episode,
        title: title,
        parts: [
            .init(id: 0, title: "the runs", text: "Three runs this week, each a little longer than the last.", startSeconds: 0),
            .init(id: 1, title: "the call", text: "You said the call with your sister went better than you expected.", startSeconds: 96),
            .init(id: 2, title: "what's next", text: "You keep coming back to sleep; it might be the next thing.", startSeconds: 214),
        ],
        durationSeconds: 302
    )

    static var readyState: Flows.FirstEpisodeState {
        .ready(item, title: title, durationSeconds: 302)
    }
}
