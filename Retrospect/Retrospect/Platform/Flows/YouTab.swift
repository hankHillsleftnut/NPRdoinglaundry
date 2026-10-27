//
//  YouTab.swift
//  V2.you · YO-1 and YO-2: what the tab page shows at rest (the question waiting for you) and what asking
//  gives back (Paper c:answer/found 1G9Y-0, c:answer/abstained K24-0, c:source-result 1G9P-0).
//  Pure values; the sample answers today.
//
import Foundation

extension Flows {
    /// YO-1 at rest: the one question Retro is waiting on, if any ("one question waiting · about sam").
    struct YouAtRest: Hashable, Sendable {
        /// "about sam"; nil hides the row.
        let questionAbout: String?
    }

    /// A run of an answer's words, with the source number it cites ("after days you run¹").
    struct Cited: Hashable, Sendable {
        let text: String
        /// 1-based source number, drawn as a superscript after the text.
        let source: Int?

        init(_ text: String, source: Int? = nil) {
            self.text = text
            self.source = source
        }
    }

    /// One source under an answer (c:source-result/rest): its number, where and how much, and one line.
    struct SourceResult: Identifiable, Hashable, Sendable {
        /// 1-based, the number the answer cites.
        let id: Int
        /// "apple health · 14 nights"
        let meta: String
        /// One line of what it says.
        let words: String
        /// It only backs the guess line, so "only what's certain" hides it.
        let backsGuessOnly: Bool
        /// The source's page (YO-3), when one is drawn; nil: the row opens nothing yet (YO-D7).
        let sourceID: String?
    }

    /// What asking about yourself gives back (YO-2).
    struct Answer: Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            /// Something was found: the answer, maybe a guess, and its sources.
            case found
            /// Nothing answers it: Retro says so and offers the closest thing, never a guess.
            case abstained
        }

        let kind: Kind
        /// The headline, in the inky face.
        let headline: [Cited]
        /// "a guess: …" (found) or "the closest: …" (abstained), in body/secondary.
        let secondLine: [Cited]?
        /// The second line is a guess, which "only what's certain" hides.
        let secondLineIsGuess: Bool
        let sources: [SourceResult]
    }
}
