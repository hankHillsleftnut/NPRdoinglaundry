//
//  SampleYou.swift
//  V2.you: the You tab's sample, word for word as Paper draws it (YO-1 1G5Y-0, YO-2 1G8E-0 and K24-0, YO-3 1GAS-0, YO-5 1SZX-0). Dark: only the launcher
//  reads it. The live answers come from the brain later (the attach phase); nothing here persists.
//  Sandbox (founder 27 Oct): debug builds only, never in the product.
//
import Foundation

#if DEBUG
@MainActor
final class SampleYou: YouData {
    func atRest() async -> Flows.YouAtRest {
        Flows.YouAtRest(questionAbout: "sam")
    }

    /// "when do i sleep best?" (any case, with or without the ?) finds Paper's answer; anything else
    /// finds nothing, as K24-0 draws it.
    func ask(_ question: String) async -> Flows.Answer {
        Self.asksSleep(question) ? Self.sleepAnswer : Self.nothingFound
    }

    static let sleepQuestion = "when do i sleep best?"
    /// A question nothing answers, for the launcher's `nothing` state (sample words, not drawn).
    static let unansweredQuestion = "how is my sister doing?"

    static func asksSleep(_ question: String) -> Bool {
        let plain = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "?")))
        return plain == "when do i sleep best"
    }

    /// YO-2 as drawn (1G9Y-0, 1G97-0): two cited findings, one guess, three sources; only the journal
    /// source has a page (YO-3).
    static let sleepAnswer = Flows.Answer(
        kind: .found,
        headline: [.init("after days you run", source: 1), .init(", and when work stops before 9", source: 2), .init(".")],
        secondLine: [.init("a guess: weekends help less than you think", source: 3), .init(".")],
        secondLineIsGuess: true,
        sources: [
            .init(id: 1, meta: "apple health · 14 nights", words: "you slept 40 min longer after a run", backsGuessOnly: false, sourceID: nil),
            .init(id: 2, meta: "journal · 3 entries", words: "\"stopped at 8, slept like a rock\"", backsGuessOnly: false, sourceID: sleepEntry.id),
            .init(id: 3, meta: "calendar · 4 weekends", words: "no early events, no better sleep", backsGuessOnly: true, sourceID: nil),
        ]
    )

    /// c:answer/abstained (K24-0): it says so and doesn't guess, then the closest thing.
    static let nothingFound = Flows.Answer(
        kind: .abstained,
        headline: [.init("nothing you've said answers this yet.")],
        secondLine: [.init("the closest: you mentioned your sister twice in october, both about the move.")],
        secondLineIsGuess: false,
        sources: []
    )

    func source(id: String) async -> Flows.SourceEntry? {
        id == Self.sleepEntry.id ? Self.sleepEntry : nil
    }

    /// YO-3 as drawn (1GAS-0): the journal entry behind source 2 of "when do i sleep best?".
    static let sleepEntry = Flows.SourceEntry(
        id: "entry-14-oct",
        words: "went to bed at 10 for once. woke up before the alarm and actually wanted to run.",
        meta: "tue 14 oct · 7:40 · written · read",
        read: true,
        supports: [
            Flows.Supported(id: "sleep-best", title: "you sleep best after days you run", kind: .knowledge),
            Flows.Supported(id: "goal-midnight", title: "sleep before midnight", kind: .goal(id: "sleep-before-midnight")),
        ]
    )

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
#endif
