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

    /// What retro has learned about how you answer (ST-8), in three lines.
    struct Learned: Equatable, Sendable {
        /// The display sentence ("you answer questions about work most, 8 of 10.").
        let headline: String
        /// What retro does about it.
        let detail: String
        /// "last changed on sunday".
        let changed: String
    }
}

extension Flows {
    /// The second half's settings, as ST-5 … ST-9 read and change them. Writes apply at once.
    @MainActor
    protocol SettingsTrustData: AnyObject, Observable {
        var straightness: Settings.Straightness { get }
        /// The choice retro made for you, and why (ST-6 "picked by retro").
        var retroPick: Settings.Straightness { get }
        var retroReason: String { get }
        /// Nil until retro has learned something (that page is undrawn: ST-D25).
        var learned: Settings.Learned? { get }
        /// ST-5 "read in the background": your own ambient switch. Off, retro learns only from what you send.
        var readsInBackground: Bool { get }
        /// ST-5 "where it's processed" ("europe · named providers").
        var processedWhere: String { get }
        /// ST-7: how briefs and episodes play.
        var speed: Settings.Speed { get }

        func setStraightness(_ value: Settings.Straightness)
        func setReadsInBackground(_ isOn: Bool)
        func setSpeed(_ value: Settings.Speed)
        /// ST-5 "delete my data…", confirmed in its dialog.
        func deleteMyData() async
    }
}
