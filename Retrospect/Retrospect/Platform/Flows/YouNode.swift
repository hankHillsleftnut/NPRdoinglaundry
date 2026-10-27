//
//  YouNode.swift
//  V2.you · YO-4: one node of your map in its sheet (Paper 1GC2-0 "a person"): what Retro believes about it,
//  what that rests on, what it is linked to. (The guess state is not drawn: not built, founder 27 Oct, YO-D12.)
//
import Foundation

extension Flows {
    /// One thing a belief rests on (c:evidence-row/rest): where it came from, when, and the words.
    struct Evidence: Identifiable, Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            case yourWords, calendar

            /// The kind well's glyph (as the evidence row's lab page).
            var symbol: String {
                switch self {
                case .yourWords: "doc.text"
                case .calendar: "calendar"
                }
            }
        }

        let id: String
        let kind: Kind
        /// "12 oct · your words"
        let meta: String
        let words: String
    }

    /// A node of the map in its sheet.
    struct Node: Identifiable, Hashable, Sendable {
        let id: String
        /// "person"
        let kind: String
        /// "priya"
        let name: String
        /// What Retro believes (c:claim/stated) and how sure: "fairly sure · from 5 things · moved last week".
        let belief: String
        let meta: String
        let restsOn: [Evidence]
        let linked: [String]

        /// The sheet's header, "person · priya".
        var header: String {
            "\(kind) · \(name)"
        }
    }

    /// Your answer to the sheet's pills ("not right" is not drawn yet).
    enum NodeAnswer: Hashable, Sendable {
        /// "still true"
        case stillTrue
    }
}
