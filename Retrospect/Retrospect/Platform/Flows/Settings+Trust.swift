//
//  Settings+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): what those pages read and change, as a screen sees it.
//  Added beside the first half's `Flows.Settings` (never editing it), so live data can conform later
//  without a page changing. V2 has a SAMPLE implementation only (SampleSettings+Trust.swift): nothing
//  here talks to the server or saves anything.
//
import Foundation
import Observation

extension Flows.Settings {
    /// How straight retro is with you (ST-6), Paper 1GQM-0's four choices in order.
    enum Straightness: String, CaseIterable, Sendable {
        case justWhatHappened, gentleQuestions, honestObservations, dontHoldBack

        var title: String {
            switch self {
            case .justWhatHappened: "just what happened"
            case .gentleQuestions: "gentle questions"
            case .honestObservations: "honest observations"
            case .dontHoldBack: "don't hold back"
            }
        }

        var subline: String {
            switch self {
            case .justWhatHappened: "no reading between the lines"
            case .gentleQuestions: "i ask, i don't tell"
            case .honestObservations: "i say what i see, kindly"
            case .dontHoldBack: "i say it plainly"
            }
        }

        /// ST-1's value. Paper draws only "honest"; the other three are provisional (ST-D40).
        var shortName: String {
            switch self {
            case .justWhatHappened: "what happened"
            case .gentleQuestions: "gentle"
            case .honestObservations: "honest"
            case .dontHoldBack: "plain"
            }
        }
    }

    /// How fast briefs and episodes play (ST-7 "speed"). Paper draws only "1×"; the other speeds are
    /// provisional (ST-D24).
    enum Speed: Double, CaseIterable, Sendable {
        case slower = 0.8
        case normal = 1
        case faster = 1.25
        case fastest = 1.5

        /// "1×", "1.25×"
        var label: String {
            switch self {
            case .slower: "0.8×"
            case .normal: "1×"
            case .faster: "1.25×"
            case .fastest: "1.5×"
            }
        }
    }

    /// Reading in the background (contract 06 `AmbientSettings`): your own switch, whether it is
    /// actually reading, and the founder's paused-for-everyone switch (its look is undrawn: ST-D20).
    struct Ambient: Equatable, Sendable {
        /// Your switch (ST-5 "read in the background").
        var enabled: Bool
        /// Whether retro is reading now (off when paused for everyone, even with yours on).
        var effective: Bool
        var pausedForEveryone: Bool
    }

    /// Who set how straight retro is (contract 06 §2 `straightness.source`).
    enum StraightnessSource: Sendable {
        /// You chose it on ST-6.
        case yours
        /// Retro picked it for you (ST-6 "picked by retro").
        case picked
    }

    /// How straight retro is, who set it, and (only when retro picked it) why (contract 06 §2).
    struct StraightnessSetting: Equatable, Sendable {
        /// Nil for a level this app doesn't know yet (the contract's "unknown").
        var level: Straightness?
        var source: StraightnessSource
        /// Retro's reason; present only when `source == .picked`.
        var why: String?
    }

    /// What retro has learned about how you answer (ST-8; contract 06 §3).
    struct Learned: Equatable, Sendable {
        enum State: Sendable {
            /// Something is learned: the page Paper draws.
            case learning
            /// Too early to say (undrawn: ST-D25).
            case tooEarly
            /// Learning is off (undrawn: ST-D25).
            case off
            /// A state this app doesn't know yet.
            case unknown
        }

        let state: State
        /// The display sentence ("you answer questions about work most, 8 of 10.").
        let headline: String?
        /// What retro does about it (the contract's `why`).
        let detail: String?
        /// When it last changed; the page says "last changed on sunday".
        let changedAt: Date?
    }
}

extension Flows {
    /// The second half's settings, as ST-5 … ST-9 read and change them (the shape of contract 06).
    /// Writes apply at once.
    @MainActor
    protocol SettingsTrustData: AnyObject, Observable {
        var straightness: Settings.StraightnessSetting { get }
        var learned: Settings.Learned { get }

        var ambient: Settings.Ambient { get }
        /// ST-7: how briefs and episodes play.
        var speed: Settings.Speed { get }

        /// Your choice, or nil to let retro decide again.
        func setStraightness(_ level: Settings.Straightness?)
        /// Your ambient switch. Throws when it couldn't be saved; `ambient` then still says what is true,
        /// so the switch snaps back (contract 06 §1).
        func setAmbient(enabled: Bool) async throws
        func setSpeed(_ value: Settings.Speed)
        /// ST-5 "delete my data…", confirmed in its dialog. Throws when it didn't happen, so the dialog
        /// stays up with its error line.
        func deleteMyData() async throws
    }
}
