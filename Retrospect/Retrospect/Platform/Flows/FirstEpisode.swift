//
//  FirstEpisode.swift
//  P05.min (Alpha 0.1): the seam the "your first episode" page reads (ON-10 getting ready, ON-11
//  the first listen). Views build against SampleFirstEpisode; the live watch of the podcasts
//  library (PL3.4.a.min / PL3.4.b.min) sits behind the same protocol later. No job steps in 0.1:
//  the brain makes the first episode on its own, so the page only asks "is it there yet?".
//
import Foundation
import Observation

extension Flows {
    /// Where the person's first episode is.
    enum FirstEpisodeState: Hashable, Sendable {
        /// Still being made; `since` is when the wait began (the page turns "slow" after 15 minutes).
        case waiting(since: Date)
        /// Made, with audio the player can load.
        case ready(PlaybackItem, title: String, durationSeconds: Int?)
        /// Made, but its audio isn't there: the page shows the title and "continue", never a dead
        /// play button. (Widened from the scope's bare `.unavailable` so the title can show.)
        case unavailable(title: String)
    }

    /// The first episode, as the page sees it.
    @MainActor
    protocol FirstEpisode: AnyObject, Observable {
        var state: FirstEpisodeState { get }
        /// Asks once whether the episode is ready and updates `state`. The page calls it every 10 s
        /// while it is on screen; the seam never polls by itself.
        func refresh() async
    }
}

extension Flows.FirstEpisodeState: CustomStringConvertible, CustomDebugStringConvertible {
    /// Only which state it is: an episode's title is the person's own content, so a state that
    /// ends up interpolated into a line (a log, a crash note) never carries it.
    var description: String {
        switch self {
        case .waiting: "waiting"
        case .ready: "ready"
        case .unavailable: "unavailable"
        }
    }

    var debugDescription: String {
        description
    }
}
