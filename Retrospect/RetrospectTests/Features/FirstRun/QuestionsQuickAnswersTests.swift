import Foundation
@testable import Retrospect
import Testing

/// QU.followups.b: quick answers on a question (Paper ON-4a quick answers MGZ-0). A chip adds or
/// removes its words in the field, the field is the one truth for which chips are chosen, the ear
/// closes on a tap, and nothing is ever sent without the send.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct QuestionsQuickAnswersTests {
    private func quickModel() -> (QuestionsModel, SampleFirstRunData) {
        let data = SampleFirstRunData(scenario: .questionsQuick, clock: NoWaitClock())
        return (QuestionsModel(data: data), data)
    }

    @Test("Paper's frame: 'what news do you actually follow?' with its five chips, word for word")
    func paperFrame() {
        let (model, _) = quickModel()
        #expect(model.question?.text == "what news do you actually follow?")
        #expect(model.quickAnswers == ["tech", "markets", "football", "climate", "not really any"])
        #expect(model.question?.key == .readingWatching)
        // the 9 questions of the flow carry no chips until the founder names them (QC-1)
        #expect(Flows.FirstRunQuestion.core.allSatisfy(\.quickAnswers.isEmpty))
    }

    @Test("tapping chips builds 'tech, markets' in the field in tap order; tapping again removes one")
    func toggleBuildsTheAnswer() {
        let (model, data) = quickModel()
        model.toggle("tech")
        model.toggle("markets")
        #expect(model.draft == "tech, markets")
        #expect(model.isChosen("tech"))
        #expect(model.isChosen("markets"))
        #expect(!model.isChosen("football"))
        model.toggle("tech")
        #expect(model.draft == "markets")
        #expect(!model.isChosen("tech"))
        // never sends by itself
        #expect(data.answerCount == 0)
        #expect(model.question?.key == .readingWatching)
    }

    @Test("typed words stay; editing the field by hand chooses and clears chips")
    func fieldIsTheTruth() {
        let (model, _) = quickModel()
        model.draft = "podcasts mostly"
        model.toggle("climate")
        #expect(model.draft == "podcasts mostly, climate")
        model.draft = "podcasts mostly"
        #expect(!model.isChosen("climate"))
        model.draft = "tech,  climate "
        #expect(model.isChosen("tech"))
        #expect(model.isChosen("climate"))
        #expect(QuestionsModel.parts(of: " , a ,, b ") == ["a", "b"])
    }

    @Test("send carries the chips' words, typed, and moves on")
    func sendCarriesChips() async {
        let (model, data) = quickModel()
        var done = 0
        model.onDone = { done += 1 }
        model.toggle("tech")
        model.toggle("markets")
        await model.send(model.draft)
        #expect(data.answerCount == 1)
        #expect(data.answeredKeys == [.readingWatching])
        #expect(done == 1)
    }

    @Test("a chip tap while listening closes the ear and types; heard words come first in the field")
    func chipStopsListening() async {
        let (model, _) = quickModel()
        await model.appear()
        #expect(model.composer == .listening)
        model.toggle("tech")
        #expect(model.composer == .typing)
        #expect(model.draft == "tech")
        #expect(model.level == nil)
    }

    @Test("a word that isn't one of the question's chips does nothing")
    func unknownChipIgnored() {
        let (model, _) = quickModel()
        model.toggle("cooking")
        #expect(model.draft.isEmpty)
        let plain = QuestionsModel(data: SampleFirstRunData(scenario: .questions, clock: NoWaitClock()))
        plain.toggle("tech")
        #expect(plain.draft.isEmpty)
        #expect(plain.quickAnswers.isEmpty)
    }
}

/// A clock whose sleeps end at once.
private struct NoWaitClock: Clock {
    typealias Instant = ContinuousClock.Instant

    var now: Instant {
        ContinuousClock.now
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {}
}
