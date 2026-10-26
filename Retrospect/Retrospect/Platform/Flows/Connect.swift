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
        /// Behind "see all" (hidden until its page is drawn: founder decision 5), so not listed.
        case seeAll
        case unknown
    }

    /// How a source connects (contract 01 §5 `kind`): iOS asks on the phone, or an account's own
    /// sign-in opens. The sample connects either at once.
    enum SourceKind: String, ContractEnum {
        case onDevice
        case account
        case unknown
    }

    /// One place Retro can learn from, as ON-6 lists it.
    struct ConnectSource: Hashable, Sendable, Identifiable {
        /// Contract 01 §5 `state` (`hidden` sources never reach the page). Paper draws two looks
        /// at hi-fi, the "connect" pill and "● connected"; the others show the pill until their
        /// drawings exist (QUESTION Q3).
        enum State: String, ContractEnum {
            /// The raised "connect" pill.
            case available
            /// Started elsewhere and not finished (an account sign-in left open): the pill.
            case connecting
            /// "● connected".
            case connected
            /// It stopped working: the pill, so it can be connected again.
            case problem
            case unknown

            /// Whether "+ connect" may start a connection from this state.
            var canConnect: Bool {
                self == .available || self == .connecting || self == .problem
            }
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
        let kind: SourceKind
        var state: State
    }

    /// The knows-you meter: how many of its steps are filled (Paper `c:knows-you-meter/1-of-6`)
    /// and the contract's `level` (`GET /v2/knows-you`), which picks its words.
    struct KnowsYou: Hashable, Sendable {
        /// Contract 01 §5: computed by the server from sources and answers.
        enum Level: String, ContractEnum {
            case little, better, well, unknown
        }

        let filled: Int
        let steps: Int
        var level: Level = .little

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
