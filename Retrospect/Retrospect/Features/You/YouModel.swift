//
//  YouModel.swift
//  V2.you · YO-1 and YO-2 are one tab page: at rest it shows the map and two rows; asking replaces them
//  in place with what was found (SCREEN-MAP row 83: "in place"; clearing the field goes back to rest).
//  One phase enum; the query, "only what's certain" and the cited row being shown live beside it.
//
import Foundation

@MainActor
@Observable
final class YouModel {
    enum Phase: Equatable {
        case rest
        /// Waiting for the answer; a re-ask keeps the answer before it on screen (only clearing brings the
        /// map back). Nothing is drawn for waiting; the sample answers at once.
        case asking(previous: Flows.Answer?)
        case answered(Flows.Answer)
    }

    private(set) var phase: Phase = .rest
    private(set) var atRest = Flows.YouAtRest(questionAbout: nil)
    var query = ""
    /// "only what's certain": hides the guess line and the sources that only back it.
    var onlyCertain = false
    /// The source a citation was tapped for, shown pressed for a beat.
    var highlighted: Int?
    private let data: any YouData

    init(data: any YouData) {
        self.data = data
    }

    func load() async {
        atRest = await data.atRest()
    }

    /// Asks the field's words; an empty field asks nothing.
    func ask() async {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        onlyCertain = false
        highlighted = nil
        phase = .asking(previous: answer)
        let answer = await data.ask(question)
        // a newer question or a cleared field wins: drop an answer for words no longer in the field
        guard case .asking = phase, query.trimmingCharacters(in: .whitespacesAndNewlines) == question else { return }
        phase = .answered(answer)
    }

    /// The field was emptied (× or by hand): back to the map.
    func clear() {
        query = ""
        onlyCertain = false
        highlighted = nil
        phase = .rest
    }

    var answer: Flows.Answer? {
        if case let .answered(answer) = phase {
            return answer
        }
        return nil
    }

    /// The second line, unless it is a guess and only what's certain is on.
    var secondLine: [Flows.Cited]? {
        guard let answer, let line = answer.secondLine else { return nil }
        return answer.secondLineIsGuess && onlyCertain ? nil : line
    }

    var sources: [Flows.SourceResult] {
        guard let answer else { return [] }
        return onlyCertain ? answer.sources.filter { !$0.backsGuessOnly } : answer.sources
    }

    /// The switch is offered only when there is a guess to hide.
    var offersOnlyCertain: Bool {
        answer?.secondLineIsGuess == true
    }

    /// "hides the 1 guess" (the answer has one guess line).
    static let onlyCertainSubline = "hides the 1 guess"
}
