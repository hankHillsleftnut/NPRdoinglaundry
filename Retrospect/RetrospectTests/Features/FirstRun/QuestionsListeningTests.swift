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

        ear.say(.level(0.6))
        ear.say(.word("sam."))
        ear.say(.word("i'm in"))
        ear.say(.word("london"))
        await until { model.heard.count == 3 }
        #expect(model.heard.map(\.text) == ["sam.", "i'm in", "london"])
        #expect(model.level == 0.6)
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
        ear.say(.word("sam."))
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
        ear.say(.word("sam."))
        ear.say(.word("i'm in"))
        await until { model.heard.count == 2 }

        model.typeInstead()
        #expect(model.composer == .typing)
        #expect(model.draft == "sam. i'm in")
        #expect(model.heard.isEmpty)
        #expect(model.level == nil)
        // a word already on its way from the closed ear never lands
        ear.say(.word("london"))
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

    @Test("the mic listens again, carrying on from what was in the field")
    func micListensAgain() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.say(.word("sam."))
        await until { model.heard.count == 1 }
        model.typeInstead()

        model.talkInstead()
        #expect(model.composer == .listening)
        #expect(model.draft.isEmpty)
        #expect(model.heard.map(\.text) == ["sam."])
        ear.say(.word("london"))
        ear.say(.ended)
        await until { model.question?.key == .yearFromNow }
        #expect(data.sent.first == Sent(key: .namePlace, text: "sam. london", given: .voice))
        // the person chose the mic again: the next question listens by itself
        #expect(model.composer == .listening)
    }

    @Test("back while listening keeps the words with their question; coming back they're in the field, typed")
    func backKeepsHeardWords() async {
        let ear = ScriptedEar()
        let data = EaredFirstRun(ear: ear)
        let model = QuestionsModel(data: data)
        await model.appear()
        ear.say(.word("sam."))
        ear.say(.ended)
        await until { model.question?.key == .yearFromNow }
        ear.say(.word("a"))
        ear.say(.word("quieter"))
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
        ear.say(.word("sam."))
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

    @Test("the sample ear says Paper's words for Q1 in order, rests the bars, then ends; a word is never heard twice")
    func sampleEar() async {
        let ear = SampleListening(clock: NoWaitClock())
        var words: [String] = []
        var events: [Flows.Heard] = []
        for await event in ear.hear(.namePlace) {
            events.append(event)
            if case let .word(word) = event {
                words.append(word)
            }
        }
        #expect(words == ["sam.", "i'm in", "london"])
        #expect(events.suffix(2) == [.level(nil), .ended])
        #expect(Flows.FirstRunQuestion.core.allSatisfy { !(SampleListening.words[$0.key] ?? []).isEmpty })

        var again: [Flows.Heard] = []
        for await event in ear.hear(.namePlace) {
            again.append(event)
        }
        #expect(again == [.level(nil), .ended])
    }

    @Test("the sample first run carries the sample ear")
    func sampleCarriesTheEar() {
        #expect(SampleFirstRunData(scenario: .questions).listening is SampleListening)
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

/// An ear the test speaks into, one event at a time.
@MainActor
private final class ScriptedEar: Flows.Listening {
    private(set) var asked: [Flows.QuestionKey] = []
    private var continuation: AsyncStream<Flows.Heard>.Continuation?

    func hear(_ key: Flows.QuestionKey) -> AsyncStream<Flows.Heard> {
        asked.append(key)
        let (stream, continuation) = AsyncStream.makeStream(of: Flows.Heard.self)
        self.continuation = continuation
        return stream
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
    @ObservationIgnored let listening: (any Flows.Listening)?
    @ObservationIgnored var holds = false
    @ObservationIgnored private(set) var sent: [Sent] = []
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    init(ear: (any Flows.Listening)?) {
        listening = ear
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
