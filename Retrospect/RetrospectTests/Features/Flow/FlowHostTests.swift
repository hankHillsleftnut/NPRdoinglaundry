import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// FLOW.host: the sample flow through the real screens' own models (PI0, PI1/PI2, ON-3–9) on their samples:
/// a sample sign-in moves on exactly once with no Apple sheet and no backend, the tear and "begin" reach the
/// questions, every step resumes after a relaunch with the answers kept (decision 9), `-FlowStart` keeps
/// nothing, and the flow ends cleanly at the questions.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FlowHostTests {
    /// The samples' short pretend waits end at once; long ones (the tear's 8 s give-up timer) really wait, so
    /// the sample's answer always wins the race, as it does in the app.
    private let noWait: SampleFlowModel.Sleep = { duration in
        if duration >= .seconds(1) {
            try? await Task.sleep(for: duration)
        }
    }

    /// The model as the host keeps it: built, then started once on screen.
    private func flow(_ store: MemoryFlowStore, start: FlowStep? = nil) -> SampleFlowModel {
        let model = SampleFlowModel(store: store, start: start, sleep: noWait, clock: FlowImmediateClock())
        model.started()
        return model
    }

    @Test("a model SwiftUI builds and drops writes nothing; the kept one saves its start once")
    func onlyTheKeptModelWrites() {
        let kept = SampleFlowSaved(step: .questions, answers: ["name.place": "sam."])
        let store = MemoryFlowStore(kept)
        _ = SampleFlowModel(store: store, start: .splash, sleep: noWait, clock: FlowImmediateClock())
        #expect(store.saved == kept)
        #expect(store.saves == 0)

        let model = SampleFlowModel(store: store, start: .splash, sleep: noWait, clock: FlowImmediateClock())
        model.started()
        model.started()
        #expect(store.saves == 1)
        #expect(store.saved == SampleFlowSaved(step: .splash))
    }

    // MARK: Sign-in

    @Test("a tap on sign-in signs in a sample person and moves the flow on exactly once")
    func sampleSignInOnce() async {
        let store = MemoryFlowStore()
        let model = flow(store)
        #expect(model.step == .splash)
        let savesBefore = store.saves
        // the sample tap the screen plays (no Apple sheet, no backend), twice
        await model.signIn.appleFinished(.failure(SampleTap()))
        await model.signIn.appleFinished(.failure(SampleTap()))
        #expect(model.step == .inviteGate)
        #expect(store.saves == savesBefore + 1)
        #expect(store.saved?.step == .inviteGate)
    }

    // MARK: The whole walk

    @Test("splash → code → tear → you're in → begin → the questions, through the screens' own models")
    func walksToTheQuestions() async {
        let store = MemoryFlowStore()
        let model = flow(store)
        await model.signIn.appleFinished(.failure(SampleTap()))
        #expect(model.invite.phase == .typed)

        // any whole code prints the ticket in the flow
        model.invite.setCode("BATR4DX9M2QK7")
        await model.invite.submitTyped()
        #expect(model.invite.phase == .ready)

        await model.invite.commitTear()
        #expect(model.invite.phase == .youreIn)
        // the model follows the page's phase itself (no view in this test)
        await settle { model.step == .youreIn }
        #expect(model.step == .youreIn)

        model.invite.begin()
        #expect(model.step == .questions)
        #expect(store.saved?.step == .questions)
    }

    /// Lets the main actor run queued work until `done` holds (bounded, never a sleep).
    private func settle(_ done: () -> Bool) async {
        for _ in 0 ..< 200 where !done() {
            await Task.yield()
        }
    }

    @Test("the tear hands off with no view: the phase change alone moves the flow to 'you're in'")
    func tearHandOffWiredInTheModel() async {
        let model = flow(MemoryFlowStore(), start: .inviteGate)
        model.invite.setCode("BATR4DX9M2QK7")
        await model.invite.submitTyped()
        await settle { model.step != .inviteGate }
        #expect(model.step == .inviteGate) // printed and ready: not torn yet
        await model.invite.commitTear()
        await settle { model.step == .youreIn }
        #expect(model.step == .youreIn)
    }

    @Test("the gate hands on only once the stub has come away")
    func tearOnlyMovesFromTheGate() {
        let model = flow(MemoryFlowStore(), start: .inviteGate)
        for phase: InviteModel.Phase in [.typed, .printing, .ready, .sealing, .refused(.used)] {
            model.inviteMoved(to: phase)
            #expect(model.step == .inviteGate, "\(phase)")
        }
        model.inviteMoved(to: .torn)
        #expect(model.step == .youreIn)
    }

    @Test("outside the flow the sample invite still takes only the fixture code")
    func fixtureCodeOutsideTheFlow() async {
        let source = SampleInviteSource(sleep: noWait)
        #expect(await source.type(code: "BATR4DX9M2QK7") == .refused(nil, .invalid))
        #expect(await source.type(code: SampleInvite.code) == .printing(SampleInvite.face))
    }

    // MARK: Resume (decision 9)

    @Test("a relaunch lands on the exact step it left")
    func resumesEachStep() {
        for step in FlowStep.allCases {
            let store = MemoryFlowStore()
            _ = flow(store, start: step)
            #expect(flow(store).step == step, "\(step)")
        }
    }

    @Test("a relaunch after the tear is at 'you're in', shown still, and begin goes on")
    func resumeAfterTheTear() {
        let store = MemoryFlowStore(SampleFlowSaved(step: .youreIn))
        let model = flow(store)
        #expect(model.invite.phase == .youreIn)
        #expect(model.invite.youreIn?.animate == false)
        // the ticket comes back whole: who it's from and its number on the face, the code on the stub
        #expect(model.invite.face == SampleInvite.face)
        #expect(model.invite.printedCode == SampleInvite.code)
        #expect(model.invite.beginVisible)
        model.invite.begin()
        #expect(model.step == .questions)
    }

    @Test("answers are kept on the flow model and across a relaunch; back shows them; resume asks the next one")
    func answersKept() async {
        let store = MemoryFlowStore(SampleFlowSaved(step: .questions))
        let first = flow(store)
        let page = QuestionsModel(data: first.firstRun, kept: first.answers)
        page.onAnswered = { key, words in first.answered(key, words: words) }
        await page.send("sam, in london.")
        #expect(first.answers == [.namePlace: "sam, in london."])
        #expect(page.question?.key == .yearFromNow)

        // relaunch: a new model on the same store, a new page on a fresh seam
        let again = flow(store)
        #expect(again.step == .questions)
        #expect(again.answers == [.namePlace: "sam, in london."])
        let resumed = QuestionsModel(data: again.firstRun, kept: again.answers)
        #expect(resumed.question?.key == .yearFromNow)
        resumed.back()
        #expect(resumed.question?.key == .namePlace)
        #expect(resumed.answer == "sam, in london.")
        #expect(resumed.draft == "sam, in london.")
    }

    @Test("a saved key the app doesn't know is dropped, never asked")
    func unknownKeyDropped() {
        let store = MemoryFlowStore(SampleFlowSaved(step: .questions, answers: ["no.such.key": "x", "people": "priya."]))
        #expect(flow(store).answers == [.people: "priya."])
    }

    @Test("-FlowStart starts there with nothing kept")
    func flowStartKeepsNothing() {
        let store = MemoryFlowStore(SampleFlowSaved(step: .questions, answers: ["name.place": "sam."]))
        let model = flow(store, start: .splash)
        #expect(model.step == .splash)
        #expect(model.answers.isEmpty)
        #expect(store.saved == SampleFlowSaved(step: .splash))
    }

    // MARK: The end

    @Test("the last question ends the flow cleanly: it stays on the questions, nothing new")
    func endsCleanly() async {
        let store = MemoryFlowStore(SampleFlowSaved(step: .questions))
        let model = flow(store)
        let page = QuestionsModel(data: model.firstRun, kept: model.answers)
        page.onAnswered = { key, words in model.answered(key, words: words) }
        var done = 0
        page.onDone = {
            done += 1
            model.send(.questionsDone)
        }
        for question in page.questions {
            await page.send("an answer for \(question.key.rawValue).")
        }
        #expect(done == 1)
        #expect(page.isFinished)
        #expect(model.step == .questions)
        #expect(model.answers.count == page.questions.count)
    }

    @Test("the app's store keeps the flow under its own key and can be cleared")
    func userDefaultsStore() throws {
        let suite = "flow.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsFlowStore(defaults: defaults)
        #expect(store.load() == nil)
        store.save(SampleFlowSaved(step: .youreIn, answers: ["people": "priya."]))
        #expect(UserDefaultsFlowStore(defaults: defaults).load() == SampleFlowSaved(step: .youreIn, answers: ["people": "priya."]))
        store.clear()
        #expect(store.load() == nil)
    }

    // MARK: Getting ready (GR.ready)

    @Test("getting ready: the answer is kept on the flow and comes back after a relaunch; made ends the flow there")
    func gettingReadyKeepsAndEnds() async {
        let store = MemoryFlowStore(SampleFlowSaved(step: .gettingReady))
        let model = flow(store)
        // a relaunch this far on is after the tear: the ticket is spent, shown still
        #expect(model.invite.phase == .youreIn)
        let page = GettingReadyModel(
            firstRun: model.firstRun,
            episode: SampleFirstEpisode(scenario: .ready),
            listening: SampleListening(clock: FlowImmediateClock(), ends: false, waits: false),
            clock: FlowImmediateClock()
        )
        page.onAnswered = { key, words in model.answered(key, words: words) }
        var made = 0
        page.onReady = {
            made += 1
            model.send(.episodeReady)
        }
        await page.sendTyped("the investor call on thursday")
        #expect(model.answers[.thisWeek] == "the investor call on thursday")
        await page.run()
        #expect(made == 1)
        // no row to the tease yet: the flow ends cleanly here
        #expect(model.step == .gettingReady)

        let again = flow(store)
        #expect(again.step == .gettingReady)
        let resumed = GettingReadyModel(
            firstRun: again.firstRun,
            episode: again.episode,
            listening: again.listening,
            kept: again.answers[.thisWeek],
            clock: FlowImmediateClock()
        )
        #expect(resumed.goingIn == "the investor call on thursday")
        #expect(resumed.spokenWords == "the investor call on thursday")
    }
}

/// A clock whose sleeps end at once (the sample's pretend save, without waiting).
private struct FlowImmediateClock: Clock {
    typealias Instant = ContinuousClock.Instant

    var now: Instant {
        ContinuousClock.now
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {}
}
