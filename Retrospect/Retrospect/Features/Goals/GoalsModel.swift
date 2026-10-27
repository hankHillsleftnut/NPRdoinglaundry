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
    /// Guesses with an answer on its way: one answer per guess, whatever stands behind the seam.
    @ObservationIgnored private var answering: Set<String> = []
    /// Bumped by every read or answer; only the newest one may set the state (a slow read never
    /// puts an answered guess back).
    @ObservationIgnored private var generation = 0

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
        generation += 1
        let mine = generation
        let overview = await data.overview()
        if mine == generation {
            state = .rest(overview)
        }
    }

    /// "yes" / "not quite" on GL-1's guess: the card leaves; a "yes" leaves a too-early goal behind.
    /// A second tap while the first is on its way does nothing.
    func answer(_ guess: GoalGuess, accepted: Bool) async {
        guard overview?.guess?.id == guess.id, answering.insert(guess.id).inserted else { return }
        defer { answering.remove(guess.id) }
        generation += 1
        let mine = generation
        let overview = await data.answer(guess: guess.id, accepted: accepted)
        if mine == generation {
            state = .rest(overview)
        }
    }

    /// Back from GL-2 after "turn off": read the list again (the goal is gone, the ended row counts it).
    func refresh() async {
        await load()
    }
}
