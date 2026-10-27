//
//  YouSource.swift
//  V2.you · YO-3: one source behind an answer (Paper 1GAS-0 "a journal entry"): your words, when and how
//  they were said, and what they support. Pure values; the sample gives them today.
//
import Foundation

extension Flows {
    /// What a source supports (YO-3 "this supports", 1GAU-0): an answer in what Retro knows, or a goal.
    struct Supported: Identifiable, Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            /// One of the answers on YO-5 ("what i know about you").
            case knowledge
            /// A goal (GL-2, the goals group).
            case goal(id: String)
        }

        let id: String
        let title: String
        let kind: Kind

        /// The row's subline, as Paper writes it.
        var subline: String {
            switch kind {
            case .knowledge: "what i know about you"
            case .goal: "a goal"
            }
        }
    }

    /// A journal entry seen as a source (YO-3).
    struct SourceEntry: Identifiable, Hashable, Sendable {
        let id: String
        let words: String
        /// "tue 14 oct · 7:40 · written · read"
        let meta: String
        /// Retro has read it: a ✓ after the meta line.
        let read: Bool
        let supports: [Supported]
    }
}
