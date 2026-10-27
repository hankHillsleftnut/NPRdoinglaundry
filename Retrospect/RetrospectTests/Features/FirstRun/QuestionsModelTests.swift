import Foundation
import Observation
@testable import Retrospect
import Testing

/// P02.min: the questions page's rules (order, resume, back, failure, finish once, empty send,
/// unknown keys, no words in what the seam hands back), through `Flows.FirstRun`.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct QuestionsModelTests {
    typealias Key = Flows.QuestionKey

    private let coreKeys: [Key] = [.namePlace, .yearFromNow, .careMost, .onYourMind, .struggle, .workingOn, .keepMeaning, .highLow, .people]

    // MARK: Order and resume

    @Test("0.1 asks the 9 core keys in order (the struggle question right after on.your.mind), each with words")
    func coreOrder() {
        #expect(Flows.FirstRunQuestion.core.map(\.key) == coreKeys)
        #expect(Flows.FirstRunQuestion.core.allSatisfy { !$0.text.isEmpty })
        #expect(Flows.FirstRunQuestion.core.first?.text == "first, what should i call you, and where are you based?")
        #expect(
            Flows.FirstRunQuestion.core.first { $0.key == .struggle }?.text
                == "what's one thing you're really struggling with these days that could be really important?"
        )
        // the new key round-trips by its contract name (the sample flow keeps answers by key)
        #expect(Key(rawValue: "struggle") == .struggle)
        let data = try? JSONEncoder().encode([Key.struggle])
        #expect(data.flatMap { try? JSONDecoder().decode([Key].self, from: $0) } == [.struggle])
    }

    @Test("fresh starts at the first question; resume starts at the first key not answered")
    func resume() {
        #expect(QuestionsModel(data: ScriptedFirstRun()).question?.key == .namePlace)
        #expect(QuestionsModel(data: SampleFirstRunData(scenario: .questionsResume)).question?.key == .onYourMind)
        // not a count: a gap earlier in the order is asked first
        let gap = ScriptedFirstRun(answered: [.namePlace, .careMost, .onYourMind])
        #expect(QuestionsModel(data: gap).question?.key == .yearFromNow)
    }

    @Test("a saved answer moves to the next unanswered question, skipping ones answered before")
    func advancesToNextUnanswered() async {
        let data = ScriptedFirstRun(answered: [.yearFromNow])
        let model = QuestionsModel(data: data)
        await model.send("sam, in london.")
        #expect(model.question?.key == .careMost)
        #expect(data.calls == [.namePlace])
        #expect(model.draft.isEmpty)
    }

    @Test("the bar is the whole first run's: 14% on the first question to 41% on the last; VoiceOver reads 'step n of 9'")
    func progress() async {
        let model = QuestionsModel(data: ScriptedFirstRun(answered: Set(coreKeys.dropFirst().dropLast())))
        #expect(model.stepLabel == "step 1 of 9")
        #expect(abs(model.progress - 0.14) < 0.0001)
        await model.send("sam.")
        #expect(model.stepLabel == "step 9 of 9")
        #expect(abs(model.progress - 0.41) < 0.0001)
        // even steps between, and a host can hand the page its own part of the bar
        #expect(abs(QuestionsModel.progress(index: 1, count: 9) - (0.14 + 0.27 / 8)) < 0.0001)
        #expect(QuestionsModel(data: ScriptedFirstRun(), flowRange: 0.2 ... 0.6).progress == 0.2)
    }

    // MARK: Back

    @Test("back shows the previous question with its answer kept, and re-answering moves on to the first unanswered")
    func backKeepsTheAnswer() async {
        let data = ScriptedFirstRun()
        let model = QuestionsModel(data: data)
        await model.send("sam, in london.")
        await model.send("a quieter life.")
        #expect(model.question?.key == .careMost)
        #expect(model.answer == nil)

        model.back()
        #expect(model.question?.key == .yearFromNow)
        #expect(model.answer == "a quieter life.")
        model.back()
        #expect(model.answer == "sam, in london.")
        #expect(!model.canGoBack)
        model.back()
        #expect(model.question?.key == .namePlace)

        await model.send("sam, in leeds now.")
        #expect(model.answer == nil)
        #expect(model.question?.key == .careMost)
        #expect(data.calls == [.namePlace, .yearFromNow, .namePlace])
    }

    @Test("back puts the kept answer in the composer; sent unchanged, it moves on without resending")
    func backPrefillsAndMovesOnUnchanged() async {
        let data = ScriptedFirstRun()
        let model = QuestionsModel(data: data)
        await model.send("sam, in london.")
        await model.send("a quieter life.")

        model.back()
        #expect(model.question?.key == .yearFromNow)
        #expect(model.draft == "a quieter life.")
        await model.send(model.draft)
        #expect(model.question?.key == .careMost)
        #expect(model.draft.isEmpty)
        #expect(data.calls == [.namePlace, .yearFromNow])

        // two back: the unchanged first answer goes straight on to the first unanswered question
        model.back()
        model.back()
        #expect(model.draft == "sam, in london.")
        await model.send(" sam, in london.\n")
        #expect(model.question?.key == .careMost)
        #expect(data.calls == [.namePlace, .yearFromNow])
    }

    @Test("VoiceOver hears where you are and the new question when it replaces the last")
    func announcement() async {
        let model = QuestionsModel(data: ScriptedFirstRun())
        await model.send("sam.")
        #expect(model.announcement == "step 2 of 9. \(Flows.FirstRunQuestion.core[1].text)")
    }

    @Test("words typed but not sent stay with their question when going back and forth")
    func draftsStayWithTheirQuestion() async {
        let model = QuestionsModel(data: ScriptedFirstRun())
        await model.send("sam.")
        model.draft = "half a thought"
        model.back()
        #expect(model.draft == "sam.")
        model.draft = "sam, really"
        await model.send(model.draft)
        #expect(model.question?.key == .yearFromNow)
        #expect(model.draft == "half a thought")
    }

    // MARK: Failure

    @Test("a send that isn't kept keeps the words in the composer, shows the offline line and stays put")
    func failureKeepsWords() async {
        let data = ScriptedFirstRun()
        data.failing = true
        let model = QuestionsModel(data: data)
        model.draft = ""
        await model.send("sam, in london.")
        #expect(model.question?.key == .namePlace)
        #expect(model.draft == "sam, in london.")
        #expect(model.offline)
        #expect(model.failures == 1)
        #expect(model.answer == nil)

        data.failing = false
        await model.send(model.draft)
        #expect(!model.offline)
        #expect(model.question?.key == .yearFromNow)
    }

    @Test("the offline sample keeps the words and never advances")
    func offlineSample() async {
        let model = QuestionsModel(data: SampleFirstRunData(scenario: .questionsOffline, clock: ImmediateTestClock()))
        await model.send("sam.")
        #expect(model.question?.key == .namePlace)
        #expect(model.draft == "sam.")
        #expect(model.offline)
    }

    @Test("a send while one is on its way keeps its words in the composer")
    func sendWhileSending() async {
        let data = ScriptedFirstRun()
        data.holds = true
        let model = QuestionsModel(data: data)
        let first = Task { await model.send("sam.") }
        for _ in 0 ..< 1000 where !data.isHolding {
            await Task.yield()
        }
        #expect(data.isHolding)
        await model.send("and london.")
        #expect(model.draft == "and london.")
        data.release()
        await first.value
        #expect(data.calls == [.namePlace])
        #expect(model.question?.key == .yearFromNow)
    }

    // MARK: Empty, unknown, finish

    @Test("empty or blank words are never sent")
    func emptySendRefused() async {
        let data = ScriptedFirstRun()
        let model = QuestionsModel(data: data)
        await model.send("")
        await model.send("   \n ")
        #expect(data.calls.isEmpty)
        #expect(model.question?.key == .namePlace)
    }

    @Test("an unknown key decodes as unknown and is never asked")
    func unknownNeverAsked() throws {
        let decoded = try JSONDecoder().decode([Key].self, from: Data(#"["people", "some.new.key"]"#.utf8))
        #expect(decoded == [.people, .unknown])

        let questions = [Flows.FirstRunQuestion(key: .unknown, text: "?")] + Flows.FirstRunQuestion.core
        let model = QuestionsModel(data: ScriptedFirstRun(questions: questions))
        #expect(model.questions.map(\.key) == coreKeys)
        #expect(model.question?.key == .namePlace)
    }

    @Test("answering the last question finishes the seam exactly once and tells the host once")
    func finishOnce() async {
        let data = ScriptedFirstRun(answered: Set(coreKeys.dropLast()))
        let model = QuestionsModel(data: data)
        var done = 0
        model.onDone = { done += 1 }
        #expect(model.question?.key == .people)
        await model.send("my sister.")
        await model.appear()
        await model.send("and my dad.")
        #expect(data.finishCount == 1)
        #expect(done == 1)
        #expect(data.calls == [.people])
        // words sent after the end are kept, never dropped
        #expect(model.draft == "and my dad.")
    }

    @Test("going back while the last answer is on its way still finishes once (never stuck with nothing to answer)")
    func backDuringLastSendStillFinishes() async {
        let data = ScriptedFirstRun(answered: Set(coreKeys.dropLast()))
        data.holds = true
        let model = QuestionsModel(data: data)
        var done = 0
        model.onDone = { done += 1 }
        let send = Task { await model.send("my sister.") }
        for _ in 0 ..< 1000 where !data.isHolding {
            await Task.yield()
        }
        model.back()
        #expect(model.question?.key == .highLow)
        data.release()
        await send.value
        #expect(data.finishCount == 1)
        #expect(done == 1)
    }

    @Test("opening with everything answered finishes once, however often the page appears")
    func allAnsweredOnOpen() async {
        let data = ScriptedFirstRun(answered: Set(coreKeys))
        let model = QuestionsModel(data: data)
        var done = 0
        model.onDone = { done += 1 }
        await model.appear()
        await model.appear()
        #expect(data.finishCount == 1)
        #expect(done == 1)
        #expect(data.calls.isEmpty)
    }

    @Test("a fresh page does not finish on appear")
    func freshDoesNotFinish() async {
        let data = ScriptedFirstRun()
        let model = QuestionsModel(data: data)
        await model.appear()
        #expect(data.finishCount == 0)
    }

    // MARK: Privacy

    @Test("what the seam hands back carries no words, saved or failed")
    func outcomesCarryNoWords() async {
        let sample = SampleFirstRunData(scenario: .questions, clock: ImmediateTestClock())
        let saved = await sample.answer(.namePlace, text: "sam, in london.", given: .typed)
        sample.isOffline = true
        let failed = await sample.answer(.yearFromNow, text: "a quieter life.", given: .typed)
        #expect(saved == .saved)
        #expect(failed == .failedKept(.network))
        for outcome in [saved, failed] {
            #expect(ContentCheck.values(in: outcome).isEmpty, "\(outcome) carries content")
        }
    }
}

// MARK: - Test doubles

/// A first run whose answers succeed or fail on the test's word, and can be held mid-send.
@MainActor
@Observable
private final class ScriptedFirstRun: Flows.FirstRun {
    let questions: [Flows.FirstRunQuestion]
    var answeredKeys: Set<Flows.QuestionKey>
    var failing = false
    @ObservationIgnored var holds = false
    @ObservationIgnored private(set) var calls: [Flows.QuestionKey] = []
    @ObservationIgnored private(set) var finishCount = 0
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    init(questions: [Flows.FirstRunQuestion] = Flows.FirstRunQuestion.core, answered: Set<Flows.QuestionKey> = []) {
        self.questions = questions
        answeredKeys = answered
    }

    var isHolding: Bool {
        waiting != nil
    }

    func release() {
        waiting?.resume()
        waiting = nil
    }

    func answer(_ key: Flows.QuestionKey, text _: String, given _: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        calls.append(key)
        if holds {
            await withCheckedContinuation { waiting = $0 }
        }
        if failing {
            return .failedKept(.network)
        }
        answeredKeys.insert(key)
        return .saved
    }

    func finishQuestions() async {
        finishCount += 1
    }
}

/// A clock whose sleeps end at once (the sample's pretend save, without waiting).
private struct ImmediateTestClock: Clock {
    typealias Instant = ContinuousClock.Instant

    var now: Instant {
        ContinuousClock.now
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {}
}
