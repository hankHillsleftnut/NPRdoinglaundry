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

        /// ST-1's value. Paper draws only "honest"; the other three are provisional (ST-D30).
        var shortName: String {
            switch self {
            case .justWhatHappened: "what happened"
            case .gentleQuestions: "gentle"
            case .honestObservations: "honest"
            case .dontHoldBack: "plain"
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

        func setStraightness(_ value: Settings.Straightness)
    }
}
