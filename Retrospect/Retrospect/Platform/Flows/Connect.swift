//
//  Connect.swift
//  CN.connect: connect's seam (contract 01 §5, ON-6 "i'd love to get to know you."). The page reads
//  the places Retro can learn from, in their two groups, and how full the knows-you meter is, and asks
//  for one to be connected. Sample data first (`SampleConnect`); the live side (`/v2/sources`,
//  `/v2/knows-you`) plugs in behind the same protocol later. The server owns each source's name and
//  purpose line; the app draws them.
//
import Foundation
import Observation

extension Flows {
    /// Where a source sits on ON-6 (contract 01 §5 `group`).
    enum SourceGroup: String, ContractEnum {
        /// "on this iPhone": read on the phone after iOS asks (calendar, health).
        case onThisIphone
        /// "your other apps": an account Retro connects to (google).
        case yourOtherApps
        case unknown
    }

    /// One place Retro can learn from, as ON-6 lists it.
    struct ConnectSource: Hashable, Sendable, Identifiable {
        enum State: Hashable, Sendable {
            /// The raised "connect" pill.
            case available
            /// "● connected".
            case connected
        }

        /// The catalogue id (`apple_calendar`, `google`, …).
        let id: String
        /// "calendar"
        let name: String
        /// Why it's there, never what it reads ("your days, and who's in them").
        let purpose: String
        /// The SF Symbol in its well (Paper's layer name `sf:<name>`).
        let symbol: String
        let group: SourceGroup
        var state: State
    }

    /// The knows-you meter: how many of its steps are filled (Paper `c:knows-you-meter/1-of-6`).
    struct KnowsYou: Hashable, Sendable {
        let filled: Int
        let steps: Int

        /// 0…1 for the track.
        var fraction: Double {
            steps > 0 ? min(max(Double(filled) / Double(steps), 0), 1) : 0
        }
    }

    /// What asking for a connection did. Neither case carries anything the person read or wrote.
    enum ConnectOutcome: Hashable, Sendable {
        /// The source is connected: its row says so and the meter has moved.
        case connected
        /// Not connected; the row stays as it was.
        case notConnected
    }

    /// Everything ON-6 reads and does. Actions never throw to a view.
    @MainActor
    protocol Connect: AnyObject, Observable {
        /// The sources to show, in order; the page groups them by `group`.
        var sources: [ConnectSource] { get }
        /// The meter, as it stands now.
        var knowsYou: KnowsYou { get }

        /// Connects one source. `.connected` has already updated `sources` and `knowsYou`.
        func connect(_ id: ConnectSource.ID) async -> ConnectOutcome
    }
}
