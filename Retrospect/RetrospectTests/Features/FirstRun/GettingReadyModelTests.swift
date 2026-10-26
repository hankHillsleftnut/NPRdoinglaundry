import Foundation
import Observation
@testable import Retrospect
import Testing

/// A first-run seam that records every answer (key, words, how given) and answers as the test says.
@MainActor @Observable
private final class RecordingFirstRun: Flows.FirstRun {
    struct Sent: Equatable {
        let key: Flows.QuestionKey
        let text: String
        let given: Flows.FirstRunQuestion.Given
    }

    let questions: [Flows.FirstRunQuestion] = []
    private(set) var answeredKeys: Set<Flows.QuestionKey> = []
    private(set) var sent: [Sent] = []
    var outcome: Flows.AnswerOutcome = .saved

    func answer(_ key: Flows.QuestionKey, text: String, given: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        sent.append(Sent(key: key, text: text, given: given))
        if outcome == .saved {
            answeredKeys.insert(key)
        }
        return outcome
    }

    func finishQuestions() async {}
}

/// A first episode that stays where the test puts it, and counts every refresh.
@MainActor @Observable
private final class HeldEpisode: Flows.FirstEpisode {
    var state: Flows.FirstEpisodeState
    private(set) var refreshes = 0

    init(_ state: Flows.FirstEpisodeState) {
        self.state = state
    }

    func refresh() async {
        refreshes += 1
    }
}

/// Listening the test drives by hand; counts listens and stops.
@MainActor
private final class HeldListening: Flows.Listening {
    private(set) var listens = 0
    private(set) var stops = 0
    private var continuation: AsyncStream<Flows.Heard>.Continuation?

    func listen() -> AsyncStream<Flows.Heard> {
        listens += 1
        let (stream, continuation) = AsyncStream<Flows.Heard>.makeStream()
        self.continuation = continuation
        return stream
    }

    func stop() {
        stops += 1
        continuation?.finish()
        continuation = nil
    }
}

/// A clock whose sleeps end at once (the sample listening, without waiting).
private struct ImmediateClock: Clock {
    typealias Instant = ContinuousClock.Instant

    var now: Instant {
        ContinuousClock.now
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {}
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct GettingReadyModelTests {
    private let clock = TestClock()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    private final class Calls {
        var answered: [String] = []
        var ready = 0
    }

    private let calls = Calls()

    private func make(
        episode: any Flows.FirstEpisode,
        firstRun: RecordingFirstRun? = nil,
        listening: HeldListening? = nil,
        kept: String? = nil,
        secondsIn: TimeInterval = 66
    ) -> GettingReadyModel {
        let now = start.addingTimeInterval(secondsIn)
        let model = GettingReadyModel(
            firstRun: firstRun ?? RecordingFirstRun(),
            episode: episode,
            listening: listening ?? HeldListening(),
            kept: kept,
            clock: clock,
            now: { now }
        )
        let calls = calls
        model.onAnswered = { _, words in calls.answered.append(words) }
        model.onReady = { calls.ready += 1 }
        return model
    }

    private var waiting: HeldEpisode {
        HeldEpisode(.waiting(since: start))
    }

    /// Lets the main actor run queued work until `condition` holds (bounded).
    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 400 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Moves the clock by `seconds`, waiting for the watch to be asleep first and to act after.
    private func tick(_ seconds: Int, then condition: () -> Bool = { true }) async {
        await settle { clock.pendingSleeps >= 1 }
        clock.advance(by: .seconds(seconds))
        await settle(condition)
    }

    // MARK: Words arriving

    @Test("words arrive in order; only the newest is still pending; the chip carries them as they go in")
    func wordsArrive() async {
        let model = make(episode: waiting)
        await model.heard(.partial(["the"]))
        #expect(model.words.map(\.text) == ["the"])
        #expect(model.words.map(\.isPending) == [true])
        await model.heard(.partial(["the", "investor", "call", "on", "thursday"]))
        #expect(model.words.map(\.isPending) == [false, false, false, false, true])
        #expect(model.goingIn == "the investor call on thursday")
        #expect(model.spokenWords == "the investor call on thursday")
    }

    @Test("the end of an utterance sends this.week, given by voice, once; a second end sends nothing")
    func utteranceGoesInOnce() async {
        let firstRun = RecordingFirstRun()
        let model = make(episode: waiting, firstRun: firstRun)
        await model.heard(.partial(["the", "investor", "call"]))
        await model.heard(.ended)
        await model.heard(.ended)
        #expect(firstRun.sent == [.init(key: .thisWeek, text: "the investor call", given: .voice)])
        #expect(calls.answered == ["the investor call"])
        #expect(model.words.allSatisfy { !$0.isPending })
        #expect(model.goingIn == "the investor call")
    }

    @Test("a word that changes arrives again: a new identity, so it blurs in")
    func changedWordIsNew() async {
        let model = make(episode: waiting)
        await model.heard(.partial(["the", "thurs"]))
        let before = model.words.map(\.id)
        await model.heard(.partial(["the", "thursday"]))
        #expect(model.words[0].id == before[0])
        #expect(model.words[1].id != before[1])
    }

    // MARK: Typing

    @Test("a typed send goes in, given typed, trimmed; it shows under the question and on the chip")
    func typedGoesIn() async {
        let firstRun = RecordingFirstRun()
        let model = make(episode: waiting, firstRun: firstRun)
        model.setComposerMode(.muted)
        model.draft = "  the call  "
        await model.sendTyped(model.draft)
        #expect(firstRun.sent == [.init(key: .thisWeek, text: "the call", given: .typed)])
        #expect(model.draft.isEmpty)
        #expect(model.spokenWords == "the call")
        #expect(model.goingIn == "the call")
    }

    @Test("empty words are never sent")
    func emptyNeverSent() async {
        let firstRun = RecordingFirstRun()
        let model = make(episode: waiting, firstRun: firstRun)
        await model.sendTyped("   ")
        await model.heard(.partial([]))
        await model.heard(.ended)
        #expect(firstRun.sent.isEmpty)
        #expect(calls.answered.isEmpty)
    }

    @Test("an answer that isn't kept keeps the words in the field, says so once, and the chip goes back")
    func failureKeepsTheWords() async {
        let firstRun = RecordingFirstRun()
        let model = make(episode: waiting, firstRun: firstRun, kept: "the board meeting")
        firstRun.outcome = .failedKept(.network)
        await model.heard(.partial(["the", "investor", "call"]))
        await model.heard(.ended)
        #expect(model.failures == 1)
        #expect(model.isFailing)
        #expect(model.draft == "the investor call")
        #expect(model.composerMode == .muted)
        #expect(model.goingIn == "the board meeting")
        #expect(calls.answered.isEmpty)

        firstRun.outcome = .saved
        await model.sendTyped(model.draft)
        #expect(!model.isFailing)
        #expect(model.goingIn == "the investor call")
    }

    @Test("switching to typing mid-sentence stops listening and moves the unsent words into the field")
    func muteMidSentence() async {
        let firstRun = RecordingFirstRun()
        let listening = HeldListening()
        let model = make(episode: waiting, firstRun: firstRun, listening: listening)
        await model.heard(.partial(["the", "investor"]))
        model.setComposerMode(.muted)
        #expect(listening.stops >= 1)
        #expect(model.draft == "the investor")
        #expect(model.goingIn == nil)
        #expect(firstRun.sent.isEmpty)
        // a late end of that utterance sends nothing: its words are in the field
        await model.heard(.ended)
        #expect(firstRun.sent.isEmpty)
    }

    @Test("on screen it listens; back to talking after typing listens again; off screen it stops")
    func listensWhileOnScreen() async {
        let listening = HeldListening()
        let model = make(episode: waiting, listening: listening)
        let page = Task { await model.run() }
        await settle { listening.listens == 1 }
        #expect(listening.listens == 1)
        model.setComposerMode(.muted)
        model.setComposerMode(.listening)
        #expect(listening.listens == 2)
        model.pageLeft()
        page.cancel()
        model.setComposerMode(.muted)
        model.setComposerMode(.listening)
        #expect(listening.listens == 2)
    }

    // MARK: The line and the watch

    @Test("the line follows the wait against ~2 min: 55% at 66 s, never full while making")
    func lineFollowsTheWait() {
        #expect(GettingReadyModel.progress(since: start, now: start) == 0)
        #expect(abs(GettingReadyModel.progress(since: start, now: start.addingTimeInterval(66)) - 0.55) < 0.0001)
        #expect(GettingReadyModel.progress(since: start, now: start.addingTimeInterval(600)) == GettingReadyModel.makingCap)
        #expect(GettingReadyModel.progress(since: start, now: start.addingTimeInterval(-5)) == 0)
        #expect(GettingReadyModel.makingCap < 1)
    }

    @Test("the first frame draws the line where the wait is; nothing is handed off before run()")
    func firstFrame() {
        let model = make(episode: waiting)
        #expect(abs(model.episodeProgress - 0.55) < 0.0001)
        #expect(model.phase == .making)
        let made = make(episode: HeldEpisode(SampleFirstEpisode.readyState))
        #expect(made.episodeProgress == 1)
        #expect(made.phase == .making)
        #expect(calls.ready == 0)
    }

    @Test("on screen and making, it asks every 10 seconds; made fills the line and tells the host once")
    func watchesUntilMade() async {
        let episode = waiting
        let model = make(episode: episode)
        let page = Task { await model.run() }
        await tick(9) { clock.pendingSleeps >= 1 }
        #expect(episode.refreshes == 0)
        await tick(1) { episode.refreshes == 1 }
        #expect(episode.refreshes == 1)
        #expect(model.phase == .making)
        episode.state = SampleFirstEpisode.readyState
        await tick(10) { model.phase == .ready }
        #expect(model.phase == .ready)
        #expect(model.episodeProgress == 1)
        #expect(calls.ready == 1)
        await page.value
        #expect(clock.pendingSleeps == 0)
        // a second run of a made page never tells the host again
        await model.run()
        #expect(calls.ready == 1)
        model.pageLeft()
    }

    @Test("made without its audio still hands off (the host decides what opens)")
    func unavailableHandsOff() async {
        let model = make(episode: HeldEpisode(.unavailable(title: "x")))
        await model.run()
        #expect(model.phase == .ready)
        #expect(calls.ready == 1)
        model.pageLeft()
    }

    @Test("leaving the page stops the asking: the clock moves on and nothing more is asked")
    func stopsOffScreen() async {
        let episode = waiting
        let model = make(episode: episode)
        let page = Task { await model.run() }
        await tick(10) { episode.refreshes == 1 }
        page.cancel()
        model.pageLeft()
        await settle { clock.heldSleeps == 0 }
        clock.advance(by: .seconds(60))
        await settle { false }
        #expect(episode.refreshes == 1)
        #expect(model.phase == .making)
    }

    // MARK: Resume, words, the card

    @Test("a kept answer comes back: shown whole under the question and on the chip")
    func resumeShowsKept() {
        let model = make(episode: waiting, kept: "the investor call on thursday")
        #expect(model.goingIn == "the investor call on thursday")
        #expect(model.words.map(\.text) == ["the", "investor", "call", "on", "thursday"])
        #expect(model.words.allSatisfy { !$0.isPending })
    }

    @Test("Paper's words, verbatim")
    func copy() {
        #expect(GettingReadyModel.question == "while i get your first episode ready: what's one thing you want this week to go well?")
        #expect(GettingReadyModel.cardTitle == "your first episode")
        #expect(GettingReadyModel.cardLine == "weaving in what you just said · ~2 min")
        #expect(GettingReadyModel.keepTalking == "keep talking; it all goes in.")
        #expect(GettingReadyModel.progress == FlowProgress(from: 0.55, to: 0.92))
    }

    @Test("the making row has no play, and VoiceOver hears it in words")
    func makingRow() {
        let state = RBriefCard.State.firstEpisodeMaking(line: GettingReadyModel.cardLine, progress: 0.55)
        #expect(!RBriefCard.hasPlay(state))
        #expect(
            RBriefCard.spoken(length: nil, headline: "your first episode", state: state)
                == "your first episode, being made, weaving in what you just said, about 2 minutes"
        )
    }

    // MARK: The sample listening

    @Test("the sample hears Paper's answer word by word, then ends; a second listen hears nothing more")
    func sampleListening() async {
        let listening = SampleListening(clock: ImmediateClock())
        var events: [Flows.Heard] = []
        for await event in listening.listen() {
            events.append(event)
        }
        #expect(events.count == SampleListening.utterance.count + 1)
        #expect(events.last == .ended)
        #expect(events[events.count - 2] == .partial(SampleListening.utterance))
        let again = listening.listen()
        listening.stop()
        var more = 0
        for await _ in again {
            more += 1
        }
        #expect(more == 0)
    }

    @Test("Paper's still: the whole answer at once, the last word pending, and it never ends")
    func sampleStill() async {
        let listening = SampleListening(clock: ImmediateClock(), ends: false, waits: false)
        let stream = listening.listen()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first == .partial(SampleListening.utterance))
        listening.stop()
        let after = await iterator.next()
        #expect(after == nil)
    }
}
