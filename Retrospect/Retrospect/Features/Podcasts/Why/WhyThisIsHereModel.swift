//
//  WhyThisIsHereModel.swift
//  V2.podcasts.b · PC-3 why this is here (Paper p-J-0 1FXG-0 = 05 NDK-0 "asked", NBD-0 "stated"):
//  what Retro thinks, what it rests on, and where in the episode it says it. Sample only: the claim
//  arrives with the episode later (contract 03 chapters carry a claim id); until then the launcher
//  hands the page Paper's words.
//
import Foundation
import Observation

/// One claim, as PC-3 shows it.
struct WhyThisIsHere: Equatable {
    struct Evidence: Equatable, Identifiable {
        enum Kind: Equatable {
            case words, calendar

            /// The kind well's glyph (Paper c:icon/journal, c:icon/calendar).
            var symbol: String {
                switch self {
                case .words: "text.page"
                case .calendar: "calendar"
                }
            }
        }

        let id: String
        let kind: Kind
        /// "14 oct · your words".
        let meta: String
        let words: String
    }

    /// Where in the episode Retro says (or asks) it.
    struct Moment: Equatable {
        let quote: String
        /// "at 4:12 in this week's".
        let at: String
        let seconds: Double
    }

    let episodeTitle: String
    let kind: RClaim.Kind
    let claim: String
    let meta: String
    /// The rows shown (three at most, as drawn).
    let evidence: [Evidence]
    /// How many more sources there are beyond the rows shown.
    let more: Int
    let moment: Moment?

    /// "a guess" / "what it rests on" sit above; the moment's label follows the claim's kind.
    var momentLabel: String {
        kind == .asked ? "where retro asks it" : "where retro says it"
    }
}

@MainActor
@Observable
final class WhyThisIsHereModel {
    static let notAvailableYet = "not available yet"

    let content: WhyThisIsHere
    /// Back to the player (PC-2, SCREEN-MAP row 77); nil until the player hosts this page.
    @ObservationIgnored let back: (() -> Void)?
    /// Down: the sheet goes away (row 78).
    @ObservationIgnored let dismiss: () -> Void
    /// "hear it": the player at the moment (row 79); nil until the player hosts this page.
    @ObservationIgnored let hearIt: ((Double) -> Void)?

    init(content: WhyThisIsHere, back: (() -> Void)? = nil, dismiss: @escaping () -> Void, hearIt: ((Double) -> Void)? = nil) {
        self.content = content
        self.back = back
        self.dismiss = dismiss
        self.hearIt = hearIt
    }

    func playMoment() {
        guard let moment = content.moment else { return }
        hearIt?(moment.seconds)
    }
}
