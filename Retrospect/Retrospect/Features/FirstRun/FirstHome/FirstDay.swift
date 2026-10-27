//
//  FirstDay.swift
//  FH.home, ON-13 first home (Paper p-J-0 1FI8-0): what the journal shows on the person's first day,
//  as plain values the page draws. The recap is made on the phone from the first-run answers (founder,
//  26 Oct night, FH-Q2 A: the person's own words, first sentence, with Paper's prefixes): line 1 is the
//  name-and-place answer, "wants: " the year-from-now answer, "this week: " ON-10's answer. The name is
//  the first word of the name-and-place answer. The count is every answer given (8 questions + this
//  week = 9 on the sample; it grows with the questions, never a literal). Nothing here logs: the words
//  are the person's own.
//
import Foundation

/// The setup recap card's content (Paper c:entry/setup-recap 1FJ6-0).
struct SetupRecap: Equatable {
    /// "sam"; nil when the name answer is missing (the welcome then says "welcome.").
    let name: String?
    /// Up to three lines, in Paper's order; an unanswered one is left out (never "wants: .").
    let lines: [String]
    /// How many answers the person gave.
    let count: Int

    /// "9 answers".
    var countLine: String {
        count == 1 ? "1 answer" : "\(count) answers"
    }

    /// Paper's sample words, verbatim, for the 1:1 still (1FJB-0, 1FJA-0, 1FJ9-0, 1FJD-0).
    static let paper = SetupRecap(
        name: "sam",
        lines: ["sam, in london.", "wants: raise the seed, sleep before midnight.", "this week: the investor call on thursday."],
        count: 9
    )

    /// The recap from the answers the person gave while setting up.
    static func make(answers: [Flows.QuestionKey: String]) -> SetupRecap {
        let given = answers.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let lines = [
            given[.namePlace].map { sentence($0) },
            given[.yearFromNow].map { "wants: " + sentence($0) },
            given[.thisWeek].map { "this week: " + sentence($0) },
        ].compactMap(\.self)
        return SetupRecap(name: given[.namePlace].flatMap(firstWord), lines: lines, count: given.count)
    }

    /// The first sentence, trimmed, ending in a full stop.
    static func sentence(_ words: String) -> String {
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = trimmed.firstIndex { ".!?\n".contains($0) }
        var first = end.map { String(trimmed[...$0]) } ?? trimmed
        first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.last == "\n" {
            first.removeLast()
        }
        if let last = first.last, !".!?".contains(last) {
            first += "."
        }
        return first
    }

    /// "sam." / "Sam, in London" → "sam" / "Sam": the first word without its punctuation.
    static func firstWord(_ words: String) -> String? {
        let word = words.split { $0.isWhitespace || $0 == "," }.first.map(String.init)
        let bare = word?.trimmingCharacters(in: .punctuationCharacters)
        return (bare?.isEmpty ?? true) ? nil : bare
    }
}

/// Everything first home adds to the journal page.
struct FirstDay {
    let recap: SetupRecap
    /// "the week you started · 2 min" (Paper 1FJN-0, verbatim: FH-Q3 A).
    var cardLine = FirstDay.paperCardLine
    /// Pop the card once (the first time a person sees first home).
    var celebrate = false
    /// The card plays the first episode (the host opens the player sheet).
    var play: () -> Void = {}

    static let cardTitle = "your first episode is ready"
    static let paperCardLine = "the week you started · 2 min"
    static let welcomeLine = "this is your journal. say anything, any time; i'll keep it and find the threads."
    static let recapTitle = "what you told retro while setting up"

    /// "welcome, sam." (1FJJ-0); "welcome." without a name.
    static func welcome(name: String?) -> String {
        name.map { "welcome, \($0)." } ?? "welcome."
    }
}
