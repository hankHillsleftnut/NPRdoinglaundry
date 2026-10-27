//
//  Goals.swift
//  V2.goals (GL-1 goals, GL-2 one goal): the seam the goals pages talk to. Today only the sample
//  (Features/Goals/Sample) stands behind it; the /v2/goals doors plug in here later. Values are what
//  the pages show, already worded: "did" is a display string so either Paper's units ("4 hours")
//  or the door's counts ("did 2") fit without a page change (GL-D6).
//
import Foundation

/// One side of a goal card's said/did comparison: the bar's share of the track and its words.
struct GoalMeasure: Equatable, Sendable {
    /// 0...1, the bar's share of the 4pt track.
    let fraction: Double
    /// "6 times", "4 hours".
    let label: String
}

/// A goal on GL-1.
struct GoalSummary: Identifiable, Equatable, Sendable {
    let id: String
    /// "ship the first version".
    let title: String
    let said: GoalMeasure
    /// Nil for the first two weeks: the card says "too early to tell" instead of a bar (part 48).
    let did: GoalMeasure?
    /// Retro's one line: "you work on it most on tuesdays."
    let line: String
}

/// A guess Retro asks about: "a goal?" on GL-1, "a pattern" on GL-2.
struct GoalGuess: Identifiable, Equatable, Sendable {
    let id: String
    /// "a guess · a goal?"
    let label: String
    /// "you keep saying you want to see your family more. is that a goal?"
    let question: String
}

/// One row under "did this week" on GL-2.
struct GoalEvidence: Identifiable, Equatable, Sendable {
    let id: String
    /// The source's glyph: "calendar", "doc.text".
    let symbol: String
    /// "tue 14 oct · calendar".
    let meta: String
    /// "2 hours of deep work".
    let words: String
    /// Your own words open their entry (JR-4); nil: nowhere to open yet.
    let entryID: String?
}

/// GL-1's content.
struct GoalsOverview: Equatable, Sendable {
    var guess: GoalGuess?
    var goals: [GoalSummary]
    var turnedOff: Int
    var merged: Int

    /// "turned off 2 · merged 1"; nil when nothing has ended.
    var endedLine: String? {
        guard turnedOff + merged > 0 else { return nil }
        return "turned off \(turnedOff) · merged \(merged)"
    }
}

/// GL-2's content.
struct GoalDetail: Equatable, Sendable {
    let id: String
    let title: String
    /// "said 6 times · first on 6 oct · last on monday".
    let saidLine: String
    /// "did this week · 4 hours".
    let didHeading: String
    let evidence: [GoalEvidence]
    var pattern: GoalGuess?
}

/// What the goals pages read and do. The sample answers at once; a live one goes to the doors.
@MainActor
protocol GoalsData: AnyObject {
    func overview() async -> GoalsOverview
    func detail(_ goalID: String) async -> GoalDetail?
    /// "yes" (accepted) or "not quite" on a guess; returns the overview after it.
    func answer(guess guessID: String, accepted: Bool) async -> GoalsOverview
    /// "turn off" on GL-2; returns the overview after it.
    func turnOff(_ goalID: String) async -> GoalsOverview
}
