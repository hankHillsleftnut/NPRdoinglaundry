//
//  You.swift
//  V2.you: what the You tab reads (Paper area 16IA-0: YO-1 you, YO-2 search, YO-3 a source, YO-4 a node,
//  YO-5 what i know about you). Pure values and the one protocol the pages talk to; today the sample
//  answers (Features/You/Sample), later the brain's doors do. Nothing here loads, logs or persists.
//
import Foundation

extension Flows {
    /// How sure Retro is of something, as YO-5's answer rows show it: the words ("fairly sure") and
    /// a count of lit dots out of `HowSure.scale` (Paper 1T0Z-0: three of four lit for "fairly sure").
    struct HowSure: Hashable, Sendable {
        /// The dots a row draws.
        static let scale = 4

        let words: String
        /// 0…`scale`; clamped, so a bad value can't draw a fifth dot.
        let level: Int

        init(words: String, level: Int) {
            self.words = words
            self.level = min(max(level, 0), Self.scale)
        }
    }

    /// One answer Retro holds about you: the question it answers, the answer, how sure, and how many
    /// things it rests on (YO-5 c:answer-row/rest 1T0Z-0).
    struct KnownAnswer: Identifiable, Hashable, Sendable {
        let id: String
        let question: String
        let answer: String
        let howSure: HowSure
        /// "· from 9 things".
        let restsOn: Int
    }

    /// One area of your life on YO-5 ("work", "health", "family"): its answers, or, when Retro knows
    /// little, the one line it says instead (1SZZ-0: "i don't know much about your family yet…").
    struct KnownArea: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let answers: [KnownAnswer]
        /// Shown when there are no answers yet.
        let quietLine: String?
    }

    /// Everything YO-5 shows: how many answers moved this week, then each area in order.
    struct WhatIKnow: Hashable, Sendable {
        /// "2 answers changed"; nil or 0 hides the row.
        let changedThisWeek: Int?
        let areas: [KnownArea]
    }
}

/// The You tab's seam: the pages ask only this.
@MainActor
protocol YouData: AnyObject {
    /// YO-1 at rest: the question waiting, if any.
    func atRest() async -> Flows.YouAtRest
    /// YO-2: what asking about yourself finds (or that nothing answers it).
    func ask(_ question: String) async -> Flows.Answer
    /// YO-4: a named node of the map.
    func node(named name: String) async -> Flows.Node?
    /// Your answer to a node's sheet.
    func answer(_ answer: Flows.NodeAnswer, node id: String) async
    /// YO-5's areas and answers.
    func whatIKnow() async -> Flows.WhatIKnow
    /// YO-3: one source by id; nil when it doesn't exist.
    func source(id: String) async -> Flows.SourceEntry?
}
