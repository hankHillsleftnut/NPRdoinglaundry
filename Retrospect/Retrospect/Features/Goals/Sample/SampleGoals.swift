//
//  SampleGoals.swift
//  V2.goals: the goals on sample data, Paper's words exactly (GL-1 1FZO-0, GL-2 1G3Z-0). Answers and
//  "turn off" change only what is drawn (integrator 26 Oct, GL-D3/GL-D4): a "yes" turns the guess into
//  a too-early goal card, "not quite" takes the guess away, "turn off" takes the goal off the list and
//  counts it in the ended row. No networking, no persistence: a new launch starts as Paper draws it.
//
import Foundation

// Sample data is sandbox only (founder 27 Oct; SandboxFenceTests): never in a Release build.
#if DEBUG
@MainActor
final class SampleGoals: GoalsData {
    private(set) var state: GoalsOverview
    /// Goals whose GL-2 pattern guess was answered (it leaves in place).
    private var answeredPatterns: Set<String> = []

    init() {
        state = Self.paper
    }

    func overview() async -> GoalsOverview {
        state
    }

    func detail(_ goalID: String) async -> GoalDetail? {
        guard state.goals.contains(where: { $0.id == goalID }), var detail = Self.detail(for: goalID) else { return nil }
        if answeredPatterns.contains(goalID) {
            detail.pattern = nil
        }
        return detail
    }

    func answer(guess guessID: String, accepted: Bool) async -> GoalsOverview {
        if state.guess?.id == guessID {
            state.guess = nil
            if accepted {
                // "yes makes it a goal" (part 48): a new goal starts too early to tell
                state.goals.append(Self.acceptedGuess)
            }
        } else if let goalID = Self.patternOwner[guessID] {
            // GL-2's pattern guess leaves in place, whichever the answer
            answeredPatterns.insert(goalID)
        }
        return state
    }

    func turnOff(_ goalID: String) async -> GoalsOverview {
        if state.goals.contains(where: { $0.id == goalID }) {
            state.goals.removeAll { $0.id == goalID }
            state.turnedOff += 1
        }
        return state
    }

    // MARK: - Paper's words

    static let paper = GoalsOverview(
        guess: GoalGuess(
            id: "guess.family",
            label: "a guess · a goal?",
            question: "you keep saying you want to see your family more. is that a goal?"
        ),
        goals: [
            GoalSummary(
                id: "goal.ship",
                title: "ship the first version",
                said: GoalMeasure(fraction: 0.8, label: "6 times"),
                did: GoalMeasure(fraction: 0.6, label: "4 hours"),
                line: "you work on it most on tuesdays."
            ),
            GoalSummary(
                id: "goal.sleep",
                title: "sleep before midnight",
                said: GoalMeasure(fraction: 0.45, label: "3 times"),
                did: GoalMeasure(fraction: 0.15, label: "1 night"),
                line: "late nights cluster before demos."
            ),
            GoalSummary(
                id: "goal.run",
                title: "run twice a week",
                said: GoalMeasure(fraction: 0.3, label: "2 times"),
                did: nil,
                line: "9 days in. i'll know more next week."
            ),
        ],
        turnedOff: 2,
        merged: 1
    )

    /// The goal a "yes" makes. The line is the contract's fixed one (copy approval pending, founder-review).
    static let acceptedGuess = GoalSummary(
        id: "goal.family",
        title: "see your family more",
        said: GoalMeasure(fraction: 0.3, label: "3 times"),
        did: nil,
        line: "just started. i'll know more in two weeks."
    )

    /// GL-2's pattern guess id → the goal it sits on.
    private static let patternOwner = ["pattern.late-nights": "goal.ship"]

    /// The goals Paper draws a GL-2 for. Founder 27 Oct: only drawn screens; the other cards open nothing.
    static let drawnDetails: Set<String> = ["goal.ship"]

    /// GL-2 as Paper draws it (1G3Z-0), for "ship the first version" only.
    static func detail(for goalID: String) -> GoalDetail? {
        guard goalID == "goal.ship" else { return nil }
        return GoalDetail(
            id: goalID,
            title: "ship the first version",
            saidLine: "said 6 times · first on 6 oct · last on monday",
            didHeading: "did this week · 4 hours",
            evidence: [
                GoalEvidence(id: "e1", symbol: "calendar", meta: "tue 14 oct · calendar", words: "2 hours of deep work", entryID: nil),
                GoalEvidence(id: "e2", symbol: "calendar", meta: "thu 16 oct · calendar", words: "demo with priya", entryID: nil),
                GoalEvidence(
                    id: "e3", symbol: "doc.text", meta: "fri 17 oct · your words",
                    words: "\"finally fixed the sync bug\"", entryID: "entry.sync-bug"
                ),
            ],
            pattern: GoalGuess(
                id: "pattern.late-nights",
                label: "a guess · a pattern",
                question: "you get most done after a late night, then sleep badly the next day."
            )
        )
    }
}
#endif
