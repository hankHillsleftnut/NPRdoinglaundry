import Foundation
import Observation
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
        // the flow's questions carry no chips until the founder names them (QC-1)
        // a key path here doesn't compile inside #expect (rethrows), so a closure
        // swiftformat:disable:next preferKeyPath
        #expect(Flows.FirstRunQuestion.core.allSatisfy { $0.quickAnswers.isEmpty })
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
    }

    @Test("a chip tap after words were heard: the words first, then the chip; the ear is stopped")
    func heardWordsComeFirst() async {
        let ear = WordsEar()
        let data = ChipFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.say(.partial(["podcasts"]))
        for _ in 0 ..< 5000 where model.heard.isEmpty {
            await Task.yield()
        }
        model.toggle("tech")
        #expect(model.draft == "podcasts, tech")
        #expect(model.composer == .typing)
        #expect(ear.stops >= 1)
        // a late word from the stopped ear never lands
        ear.say(.partial(["podcasts", "mostly"]))
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(model.heard.isEmpty)
        #expect(model.draft == "podcasts, tech")
    }

    @Test("a chip tap while an answer is on its way does nothing (the words would land on a question being answered)")
    func noChipWhileSending() async {
        let data = ChipFirstRun(ear: nil)
        data.holds = true
        let model = QuestionsModel(data: data)
        let send = Task { await model.send("tech") }
        for _ in 0 ..< 5000 where !data.isHolding {
            await Task.yield()
        }
        model.toggle("markets")
        #expect(model.draft.isEmpty)
        data.release()
        await send.value
    }

    @Test("chips match the field whatever the case: 'Tech' chooses tech, and a tap removes it, never a duplicate")
    func caseInsensitive() {
        let (model, _) = quickModel()
        model.draft = "Tech"
        #expect(model.isChosen("tech"))
        model.toggle("tech")
        #expect(model.draft.isEmpty)
        // typed twice by hand: one tap clears every spelling, so the chip really turns off
        model.draft = "tech, Tech"
        model.toggle("tech")
        #expect(model.draft.isEmpty)
        #expect(!model.isChosen("tech"))
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

/// An ear the test speaks into.
@MainActor
private final class WordsEar: Flows.Listening {
    private(set) var stops = 0
    private var continuation: AsyncStream<Flows.Heard>.Continuation?

    func listen() -> AsyncStream<Flows.Heard> {
        let (stream, continuation) = AsyncStream.makeStream(of: Flows.Heard.self)
        self.continuation = continuation
        return stream
    }

    func stop() {
        stops += 1
        continuation?.finish()
        continuation = nil
    }

    func say(_ event: Flows.Heard) {
        continuation?.yield(event)
    }
}

/// Paper's quick-answers question with an ear the test drives, and a send that can be held.
@MainActor
@Observable
private final class ChipFirstRun: Flows.FirstRun {
    let questions = [Flows.FirstRunQuestion.paperQuickAnswers]
    var answeredKeys: Set<Flows.QuestionKey> = []
    @ObservationIgnored private let ear: WordsEar?
    @ObservationIgnored var holds = false
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    init(ear: WordsEar?) {
        self.ear = ear
    }

    var isHolding: Bool {
        waiting != nil
    }

    func release() {
        holds = false
        waiting?.resume()
        waiting = nil
    }

    func listening(for _: Flows.QuestionKey) -> (any Flows.Listening)? {
        ear
    }

    func answer(_ key: Flows.QuestionKey, text _: String, given _: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        if holds {
            await withCheckedContinuation { waiting = $0 }
        }
        answeredKeys.insert(key)
        return .saved
    }

    func finishQuestions() async {}
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
