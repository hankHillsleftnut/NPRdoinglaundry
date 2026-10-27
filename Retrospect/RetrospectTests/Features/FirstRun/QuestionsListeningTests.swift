import Foundation
import Observation
@testable import Retrospect
import Testing

/// QU.followups.a: answering out loud on the questions page (Paper 1F6C-0; founder decision 4). The
/// ear's events drive the composer and the words under the question; a quiet sends them as `.voice`;
/// mic off, the mic, back, failure and the page leaving never drop a word or let a late one land.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct QuestionsListeningTests {
    typealias Key = Flows.QuestionKey

    // MARK: Listening → thinking → next

    @Test("an open question listens; words land in order; a quiet sends them as voice and the next question listens")
    func listensAndSendsVoice() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        #expect(model.composer == .typing)
        await model.appear()
        #expect(model.composer == .listening)
        #expect(ear.asked == [.namePlace])

        ear.word("sam.")
        ear.word("i'm in")
        ear.word("london")
        await until { model.heard.count == 3 }
        #expect(model.heard.map(\.text) == ["sam.", "i'm in", "london"])
        #expect(model.draft.isEmpty)

        data.holds = true
        ear.say(.ended)
        await until { data.isHolding }
        // thinking: the words settle under the question while the seam keeps them
        #expect(model.composer == .thinking)
        #expect(model.heardText == "sam. i'm in london")
        data.release()
        await until { model.question?.key == .yearFromNow }
        #expect(data.sent == [Sent(key: .namePlace, text: "sam. i'm in london", given: .voice)])
        #expect(model.answers[.namePlace] == "sam. i'm in london")
        #expect(model.heard.isEmpty)
        #expect(model.composer == .listening)
        #expect(ear.asked == [.namePlace, .yearFromNow])
    }

    @Test("a spoken answer that isn't kept waits in the field, typed, with the offline line")
    func failedVoiceKeepsWords() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        data.failing = true
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.word("sam.")
        ear.say(.ended)
        await until { model.failures == 1 }
        #expect(model.question?.key == .namePlace)
        #expect(model.draft == "sam.")
        #expect(model.heard.isEmpty)
        #expect(model.composer == .typing)
        #expect(model.offline)
    }

    @Test("a quiet with nothing heard never sends and never leaves 'listening…' on")
    func nothingHeard() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.say(.ended)
        await until { model.composer == .typing }
        #expect(data.sent.isEmpty)
    }

    // MARK: Mic off, mic, back, leaving

    @Test("mic off moves the words heard into the field, nothing late lands, and later questions stay typed")
    func micOffKeepsWordsAndTyping() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.word("sam.")
        ear.word("i'm in")
        await until { model.heard.count == 2 }

        model.typeInstead()
        #expect(model.composer == .typing)
        #expect(model.draft == "sam. i'm in")
        #expect(model.heard.isEmpty)
        // a word already on its way from the closed ear never lands
        ear.word("london")
        ear.say(.ended)
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(model.heard.isEmpty)
        #expect(data.sent.isEmpty)

        await model.send(model.draft + " london")
        #expect(data.sent == [Sent(key: .namePlace, text: "sam. i'm in london", given: .typed)])
        #expect(model.question?.key == .yearFromNow)
        #expect(model.composer == .typing)
        #expect(ear.asked == [.namePlace])
    }

    @Test("the mic listens again, carrying on from what was in the field (sent as typed)")
    func micListensAgain() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.word("sam.")
        await until { model.heard.count == 1 }
        model.typeInstead()

        model.talkInstead()
        #expect(model.composer == .listening)
        #expect(model.draft.isEmpty)
        #expect(model.heard.map(\.text) == ["sam."])
        ear.word("london")
        ear.say(.ended)
        await until { model.question?.key == .yearFromNow }
        // words carried in from the field were typed: the answer is labelled typed, never voice
        #expect(data.sent.first == Sent(key: .namePlace, text: "sam. london", given: .typed))
        // the person chose the mic again: the next question listens by itself
        #expect(model.composer == .listening)
    }

    @Test("back while listening keeps the words with their question; coming back they're in the field, typed")
    func backKeepsHeardWords() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.word("sam.")
        ear.say(.ended)
        await until { model.question?.key == .yearFromNow }
        ear.word("a")
        ear.word("quieter")
        await until { model.heard.count == 2 }

        model.back()
        #expect(model.question?.key == .namePlace)
        #expect(model.composer == .typing)
        #expect(model.draft == "sam.")
        await model.send(model.draft)
        #expect(model.question?.key == .yearFromNow)
        #expect(model.draft == "a quieter")
        #expect(model.composer == .typing)
        #expect(ear.asked == [.namePlace, .yearFromNow])
    }

    @Test("back to a question answered in an earlier session (resume) never listens, so it never sends that answer again")
    func backToEarlierAnswerDoesNotListen() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear, answered: [.namePlace])
        let model = QuestionsModel(data: data)
        await model.appear()
        #expect(model.question?.key == .yearFromNow)
        #expect(ear.asked == [.yearFromNow])
        model.back()
        #expect(model.question?.key == .namePlace)
        #expect(model.composer == .typing)
        #expect(ear.asked == [.yearFromNow])
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(data.sent.isEmpty)
    }

    @Test("leaving the screen closes the ear and keeps the words; a model never on screen never listens")
    func disappearStops() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let offScreen = QuestionsModel(data: data)
        await offScreen.send("sam.")
        #expect(ear.asked.isEmpty)
        #expect(offScreen.composer == .typing)

        let model = QuestionsModel(data: EaredFirstRun(ear: ear))
        await model.appear()
        ear.word("sam.")
        await until { model.heard.count == 1 }
        model.disappear()
        #expect(model.composer == .typing)
        #expect(model.draft == "sam.")
        ear.say(.ended)
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(model.question?.key == .namePlace)
    }

    @Test("under VoiceOver a new question never opens the ear by itself; the mic still listens")
    func voiceOverStartsTyped() async {
        let ear = ScriptedEar()
        let model = QuestionsModel(data: EaredFirstRun(ear: ear))
        model.autoListens = false
        await model.appear()
        #expect(model.composer == .typing)
        #expect(ear.asked.isEmpty)
        model.talkInstead()
        #expect(model.composer == .listening)
        #expect(ear.asked == [.namePlace])
    }

    @Test("without an ear the page is typed only, as before")
    func noEar() async {
        let model = QuestionsModel(data: EaredFirstRun(ear: nil))
        await model.appear()
        #expect(!model.canListen)
        #expect(model.composer == .typing)
        model.talkInstead()
        #expect(model.composer == .typing)
    }

    // MARK: The sample ear

    @Test("the sample says Paper's words for Q1, the last soft until the end; a second listen hears nothing new")
    func sampleEar() async {
        let data = SampleFirstRunData(scenario: .questions, clock: NoWaitClock())
        let ear = data.listening(for: .namePlace)
        var events: [Flows.Heard] = []
        if let ear {
            for await event in ear.listen() {
                events.append(event)
            }
        }
        #expect(events.last == .ended)
        #expect(events.dropLast().last == .partial(["sam.", "i'm in", "london"]))
        // the same ear for the question, so a second listen hears nothing new
        #expect(data.listening(for: .namePlace) === ear)
        // ...and ends after a pause, so the mic on an answer already heard never hangs on "listening…"
        var again: [Flows.Heard] = []
        if let ear {
            for await event in ear.listen() {
                again.append(event)
            }
        }
        #expect(again == [.ended])
        // every question the flow asks has words (the struggle question too); Paper's quick-answers one has none
        #expect(Flows.FirstRunQuestion.core.allSatisfy { !(SampleFirstRunData.spoken[$0.key] ?? []).isEmpty })
    }

    @Test("the held still is Paper's frame: Q1's words at once, 'london' soft, never ending")
    func heldStill() async {
        let model = QuestionsModel(data: SampleFirstRunData(scenario: .questionsStill, clock: NoWaitClock()))
        await model.appear()
        for _ in 0 ..< 5000 where model.heard.count < 3 {
            await Task.yield()
        }
        #expect(model.heard.map(\.text) == ["sam.", "i'm in", "london"])
        #expect(model.heard.map(\.isPending) == [false, false, true])
        #expect(model.composer == .listening)
    }

    @Test("the page shows the last word soft while it is still being heard, sharp once the answer ends")
    func pendingLastWord() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        data.holds = true
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.word("sam.")
        ear.word("london")
        await until { model.heard.count == 2 }
        #expect(model.heard.map(\.isPending) == [false, true])
        ear.say(.ended)
        await until { data.isHolding }
        #expect(model.heard.map(\.isPending) == [false, false])
        data.release()
    }

    // MARK: Helpers

    private func until(_ condition: () -> Bool) async {
        for _ in 0 ..< 5000 where !condition() {
            await Task.yield()
        }
    }
}

// MARK: - Test doubles

private struct Sent: Equatable {
    let key: Flows.QuestionKey
    let text: String
    let given: Flows.FirstRunQuestion.Given
}

/// An ear the test speaks into: each word extends the utterance so far (`Heard.partial`).
@MainActor
private final class ScriptedEar: Flows.Listening {
    private(set) var asked: [Flows.QuestionKey] = []
    private(set) var stops = 0
    /// The question the page last asked an ear for (set by the first run).
    var forKey: Flows.QuestionKey?
    private var continuation: AsyncStream<Flows.Heard>.Continuation?
    private var spoken: [String] = []

    func listen() -> AsyncStream<Flows.Heard> {
        if let forKey {
            asked.append(forKey)
        }
        spoken = []
        let (stream, continuation) = AsyncStream.makeStream(of: Flows.Heard.self)
        self.continuation = continuation
        return stream
    }

    func stop() {
        stops += 1
        continuation?.finish()
        continuation = nil
    }

    func word(_ text: String) {
        spoken.append(text)
        continuation?.yield(.partial(spoken))
    }

    func say(_ event: Flows.Heard) {
        continuation?.yield(event)
    }
}

/// A first run with an ear (or none), whose answers succeed or fail on the test's word.
@MainActor
@Observable
private final class EaredFirstRun: Flows.FirstRun {
    let questions = Flows.FirstRunQuestion.core
    var answeredKeys: Set<Flows.QuestionKey> = []
    var failing = false
    @ObservationIgnored private let ear: ScriptedEar?
    @ObservationIgnored var holds = false
    @ObservationIgnored private(set) var sent: [Sent] = []
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    init(ear: ScriptedEar?, answered: Set<Flows.QuestionKey> = []) {
        self.ear = ear
        answeredKeys = answered
    }

    func listening(for key: Flows.QuestionKey) -> (any Flows.Listening)? {
        ear?.forKey = key
        return ear
    }

    var isHolding: Bool {
        waiting != nil
    }

    func release() {
        holds = false
        waiting?.resume()
        waiting = nil
    }

    func answer(_ key: Flows.QuestionKey, text: String, given: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        sent.append(Sent(key: key, text: text, given: given))
        if holds {
            await withCheckedContinuation { waiting = $0 }
        }
        if failing {
            return .failedKept(.network)
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
