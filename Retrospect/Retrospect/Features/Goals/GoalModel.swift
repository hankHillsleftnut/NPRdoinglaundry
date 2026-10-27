//
//  GoalModel.swift
//  V2.goals · GL-2's model: one goal at rest (the only drawn state). Answering its pattern guess takes
//  the card away in place; "turn off" tells the stack to go back to GL-1, where the goal is gone and the
//  ended row counts it (integrator 26 Oct, GL-D3/GL-D4). The turned-off GL-2 isn't drawn, so it isn't built.
//
import Observation
import SwiftUI

@Observable
@MainActor
final class GoalModel {
    enum State: Equatable {
        case idle
        case rest(GoalDetail)
        /// The goal isn't there any more (turned off elsewhere): the stack goes back.
        case gone
    }

    let goalID: String
    private(set) var state: State = .idle
    private let data: any GoalsData

    init(goalID: String, data: any GoalsData) {
        self.goalID = goalID
        self.data = data
    }

    var detail: GoalDetail? {
        if case let .rest(detail) = state {
            return detail
        }
        return nil
    }

    func load() async {
        state = await data.detail(goalID).map(State.rest) ?? .gone
    }

    func answer(_ guess: GoalGuess, accepted: Bool) async {
        _ = await data.answer(guess: guess.id, accepted: accepted)
        await load()
    }

    /// "turn off": the goal leaves the list; the page goes back.
    func turnOff() async {
        _ = await data.turnOff(goalID)
        state = .gone
    }
}
