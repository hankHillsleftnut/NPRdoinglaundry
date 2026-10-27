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
    /// The node in the sheet (YO-4); kept while the sheet closes so its content doesn't vanish mid-motion.
    private(set) var node: Flows.Node?
    /// The sheet is up.
    var sheetOpen = false
    /// Counts submissions (and clears): only the answer to the latest one may land, even when the same
    /// words were asked twice.
    private var submission = 0
    private let data: any YouData

    init(data: any YouData) {
        self.data = data
    }

    func load() async {
        atRest = await data.atRest()
    }

    /// A named orb was tapped: its sheet.
    func openNode(named name: String) async {
        await show(data.node(named: name))
    }

    private func show(_ node: Flows.Node?) {
        guard let node else { return }
        self.node = node
        sheetOpen = true
    }

    /// "still true": kept, and the sheet closes.
    func answer(_ answer: Flows.NodeAnswer) async {
        // once: the sheet stays tappable while it closes, so a second tap must not send it again
        guard let node, sheetOpen else { return }
        sheetOpen = false
        await data.answer(answer, node: node.id)
    }

    /// Asks the field's words; an empty field asks nothing.
    func ask() async {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        onlyCertain = false
        submission += 1
        let mine = submission
        phase = .asking(previous: answer)
        let answer = await data.ask(question)
        // a newer submission or a clear wins: drop an answer that is no longer the latest
        guard mine == submission, case .asking = phase else { return }
        phase = .answered(answer)
    }

    /// The field was emptied (× or by hand): back to the map.
    func clear() {
        query = ""
        onlyCertain = false
        submission += 1
        phase = .rest
    }

    /// The answer on screen: the latest, or the one before while a new question is out (only clearing
    /// brings the map back).
    var answer: Flows.Answer? {
        switch phase {
        case .rest: nil
        case let .asking(previous): previous
        case let .answered(answer): answer
        }
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
