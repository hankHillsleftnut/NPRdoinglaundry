//
//  GoalsModel.swift
//  V2.goals · GL-1's model. One state enum; only the drawn state is built (rest). Loading, empty, error
//  and offline aren't drawn (GL-D1): until the first answer the page shows the plain canvas, which the
//  sample replaces at once. Answers and "turn off" come back as the new overview from the seam.
//
import Observation
import SwiftUI

@Observable
@MainActor
final class GoalsModel {
    enum State: Equatable {
        /// Nothing read yet: the canvas alone (no undrawn loading look).
        case idle
        case rest(GoalsOverview)
    }

    private(set) var state: State = .idle
    let data: any GoalsData

    init(data: any GoalsData) {
        self.data = data
    }

    var overview: GoalsOverview? {
        if case let .rest(overview) = state {
            return overview
        }
        return nil
    }

    func load() async {
        state = await .rest(data.overview())
    }

    /// "yes" / "not quite" on GL-1's guess: the card leaves; a "yes" leaves a too-early goal behind.
    func answer(_ guess: GoalGuess, accepted: Bool) async {
        state = await .rest(data.answer(guess: guess.id, accepted: accepted))
    }

    /// Back from GL-2 after "turn off": read the list again (the goal is gone, the ended row counts it).
    func refresh() async {
        state = await .rest(data.overview())
    }
}
