//
//  SampleYou.swift
//  V2.you: the You tab's sample, word for word as Paper draws it (YO-5 1SZX-0). Dark: only the launcher
//  reads it. The live answers come from the brain later (the attach phase); nothing here persists.
//
import Foundation

@MainActor
final class SampleYou: YouData {
    func whatIKnow() async -> Flows.WhatIKnow {
        Self.whatIKnow
    }

    /// YO-5 as drawn: two answers moved this week; work (two answers), health (one), family (quiet).
    static let whatIKnow = Flows.WhatIKnow(
        changedThisWeek: 2,
        areas: [
            Flows.KnownArea(
                id: "work",
                title: "work",
                answers: [
                    Flows.KnownAnswer(
                        id: "drives",
                        question: "what drives you most?",
                        answer: "building things people use.",
                        howSure: .init(words: "fairly sure", level: 3),
                        restsOn: 9
                    ),
                    Flows.KnownAnswer(
                        id: "works-best",
                        question: "when do you work best?",
                        answer: "early, before anyone is online.",
                        howSure: .init(words: "very sure", level: 4),
                        restsOn: 14
                    ),
                ],
                quietLine: nil
            ),
            Flows.KnownArea(
                id: "health",
                title: "health",
                answers: [
                    Flows.KnownAnswer(
                        id: "sleep",
                        question: "what helps you sleep?",
                        answer: "running, and stopping work before 9.",
                        howSure: .init(words: "fairly sure", level: 3),
                        restsOn: 6
                    ),
                ],
                quietLine: nil
            ),
            Flows.KnownArea(
                id: "family",
                title: "family",
                answers: [],
                quietLine: "i don't know much about your family yet. tell me about them whenever you like."
            ),
        ]
    )
}
