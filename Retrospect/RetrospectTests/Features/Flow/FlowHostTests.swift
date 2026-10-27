import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// FLOW.host: the sample flow through the real screens' own models (PI0, PI1/PI2, ON-3–9) on their samples:
/// a sample sign-in moves on exactly once with no Apple sheet and no backend, the tear and "begin" reach the
/// questions, every step resumes after a relaunch with the answers kept (decision 9), `-FlowStart` keeps
/// nothing, the questions hand on to privacy (FLOW.edges), and the flow ends cleanly at privacy.
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

    // MARK: SI.gate.b

    @Test("the typed gate wears the sample header before the check; the code still prints, the edge is unchanged")
    func typedGateHeader() async {
        let model = flow(MemoryFlowStore(), start: .inviteGate)
        #expect(model.invite.phase == .typed)
        #expect(model.invite.face == SampleInvite.face)
        #expect(model.invite.waitlistPlace == .foot)
        model.invite.setCode(SampleInvite.code)
        await model.invite.submitTyped()
        #expect(model.invite.phase == .ready)
        #expect(model.step == .inviteGate)
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
        // an unanswered question opens empty (only an all-answered page opens with words in the composer)
        #expect(resumed.draft.isEmpty)
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

    @Test("the last question hands on to privacy; privacy's end goes on to connect")
    func questionsToPrivacyToConnect() async {
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
        #expect(model.step == .privacy)
        #expect(store.saved?.step == .privacy)
        #expect(model.answers.count == page.questions.count)

        // Retro reads to the end (instant clock): privacy is done, on to connect; not the end of the walk
        let privacy = model.makePrivacy(clock: FlowImmediateClock())
        await privacy.run()
        #expect(privacy.hasLeft)
        #expect(model.step == .connect)
        #expect(model.isAtEnd == false)
    }

    @Test("privacy: a tap moves on early to connect; connect's back returns to privacy; privacy's back to the questions")
    func privacyMoves() {
        let model = flow(MemoryFlowStore(), start: .privacy)
        let tapped = model.makePrivacy(clock: FlowImmediateClock())
        tapped.tapAnywhere()
        #expect(tapped.hasLeft)
        #expect(model.step == .connect)
        // a left page never fires again: a later back on it moves nothing
        tapped.back()
        #expect(model.step == .connect)

        model.send(.connectBack)
        #expect(model.step == .privacy)
        let visit = model.makePrivacy(clock: FlowImmediateClock())
        visit.back()
        #expect(visit.hasLeft)
        #expect(model.step == .questions)
    }

    // MARK: The end of what's built

    @Test("the tease's end ends the walk: the start-over pill shows there, and starting over is a fresh splash")
    func endOfWhatsBuilt() {
        let store = MemoryFlowStore()
        let model = flow(store, start: .tease)
        model.answered(.namePlace, words: "sam.")
        #expect(model.isAtEnd == false)
        model.send(.teaseEnded)
        #expect(model.step == .tease)
        #expect(model.endedAt == .tease)
        #expect(model.isAtEnd)
        // a relaunch at the end shows the pill at once
        #expect(store.saved?.endedAt == .gettingReady)
        #expect(flow(store).isAtEnd)

        let fresh = model.startedOver()
        #expect(fresh.step == .splash)
        #expect(fresh.answers.isEmpty)
        #expect(fresh.isAtEnd == false)
        #expect(store.saved == SampleFlowSaved(step: .splash))
    }

    // MARK: The tease (J2)

    @Test("the tease plays on its own from 0:00 and its end hands on once: the walk ends there for now")
    func teasePlaysAndEnds() async {
        let model = flow(MemoryFlowStore(), start: .gettingReady)
        model.send(.episodeReady)
        #expect(model.step == .tease)
        let sheet = model.teaseSheet()
        #expect(model.teaseSheet() === sheet)
        // it rises playing, from 0:00
        #expect(sheet.state == .playing)
        #expect(sheet.playback.position == 0)
        // its end, without racing 40 beats against a bounded settle
        sheet.playback.seek(to: 10)
        await settle { model.isAtEnd }
        #expect(sheet.state == .ended)
        #expect(model.step == .tease)
        #expect(model.endedAt == .tease)
    }

    @Test("the tease's collapse hands on like its end (row 39 default until the founder answers)")
    func teaseCollapseHandsOn() {
        let model = flow(MemoryFlowStore(), start: .tease)
        let sheet = model.teaseSheet()
        sheet.collapse()
        #expect(model.endedAt == .tease)
        // the tease stops as it hands on
        #expect(sheet.state == .paused)
        // a second tap does nothing more
        sheet.collapse()
        #expect(sheet.hasCollapsed)
    }

    @Test("a stray event with no planned hand-off never shows the pill (the invite's phase after 'you're in')")
    func strayEventIsNotTheEnd() {
        let model = flow(MemoryFlowStore(), start: .youreIn)
        model.send(.ticketTorn)
        model.send(.connectDone)
        #expect(model.endedAt == nil)
        #expect(model.isAtEnd == false)
        // a real hand-off still moves on as before
        model.send(.begin)
        #expect(model.step == .questions)
        #expect(model.isAtEnd == false)
    }

    @Test("back from privacy opens the last question with its words in the composer; sent unchanged, on to privacy")
    func backFromPrivacyKeepsTheAnswers() async throws {
        let model = flow(MemoryFlowStore(SampleFlowSaved(step: .questions)))
        let page = QuestionsModel(data: model.firstRun, kept: model.answers)
        page.onAnswered = { key, words in model.answered(key, words: words) }
        page.onDone = { model.send(.questionsDone) }
        for question in page.questions {
            await page.send("an answer for \(question.key.rawValue).")
        }
        #expect(model.step == .privacy)
        model.makePrivacy(clock: FlowImmediateClock()).back()
        #expect(model.step == .questions)

        #expect(model.cameBack)

        // the host mounts a new questions page on the same seam with the kept words, as the host does
        let last = try #require(page.questions.last)
        #expect(model.questionsFinished)
        let again = QuestionsModel(data: model.firstRun, kept: model.answers, cameBack: model.cameBack, seamFinished: model.questionsFinished)
        var done = 0
        again.onDone = {
            done += 1
            model.send(.questionsDone)
        }
        // everything is answered, yet the page stays (no bounce straight back to privacy)
        await again.appear()
        #expect(done == 0)
        #expect(model.step == .questions)
        #expect(again.question?.key == last.key)
        #expect(again.answer == "an answer for \(last.key.rawValue).")
        #expect(again.draft == "an answer for \(last.key.rawValue).")
        await again.send(again.draft)
        #expect(done == 1)
        // the seam was finished on the first pass: back and on again doesn't finish it twice
        #expect(model.firstRun.finishCount == 1)
        #expect(model.step == .privacy)
        #expect(model.cameBack == false)

        // guard: without `cameBack` the all-answered page finishes at once (the bounce this prevents)
        let bounced = QuestionsModel(data: model.firstRun, kept: model.answers)
        var bounces = 0
        bounced.onDone = { bounces += 1 }
        await bounced.appear()
        #expect(bounces == 1)
        #expect(bounced.draft.isEmpty)
    }

    @Test("a relaunch after back from privacy keeps the questions open on the last one")
    func relaunchAfterBackKeepsTheReturn() {
        let store = MemoryFlowStore(SampleFlowSaved(step: .privacy))
        let model = flow(store)
        model.makePrivacy(clock: FlowImmediateClock()).back()
        #expect(store.saved?.cameBack == true)
        #expect(flow(store).cameBack)
        // forward again clears it
        model.send(.questionsDone)
        #expect(store.saved?.cameBack == nil)
        #expect(flow(store).cameBack == false)
    }

    @Test("started at privacy, back, then every question answered: the seam is finished once, not skipped")
    func startedAtPrivacyStillFinishesTheSeam() async {
        let model = flow(MemoryFlowStore(), start: .privacy)
        model.makePrivacy(clock: FlowImmediateClock()).back()
        #expect(model.step == .questions)
        #expect(model.questionsFinished == false)
        let page = QuestionsModel(data: model.firstRun, kept: model.answers, cameBack: model.cameBack, seamFinished: model.questionsFinished)
        page.onDone = { model.send(.questionsDone) }
        for question in page.questions {
            await page.send("an answer for \(question.key.rawValue).")
        }
        #expect(model.firstRun.finishCount == 1)
        #expect(model.step == .privacy)
    }

    @Test("a relaunch at privacy comes back to privacy, after the tear, with the answers kept")
    func resumeAtPrivacy() {
        let model = flow(MemoryFlowStore(SampleFlowSaved(step: .privacy, answers: ["name.place": "sam."])))
        #expect(model.step == .privacy)
        #expect(model.invite.phase == .youreIn)
        #expect(model.answers == [.namePlace: "sam."])
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

    @Test("getting ready: the answer is kept on the flow and comes back after a relaunch; made raises the tease")
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
        // made: the tease rises over getting ready
        #expect(model.step == .tease)

        // a relaunch at the tease keeps getting ready's words under it
        let again = flow(store)
        #expect(again.step == .tease)
        let resumed = GettingReadyModel(
            firstRun: again.firstRun,
            episode: again.gettingReadyEpisode(),
            listening: again.listening,
            kept: again.answers[.thisWeek],
            clock: FlowImmediateClock()
        )
        #expect(resumed.goingIn == "the investor call on thursday")
        #expect(resumed.spokenWords == "the investor call on thursday")
    }

    @Test("connect: continue or later moves on to getting ready and is kept; back goes to privacy; a connection lasts the flow")
    func connectMovesOnToGettingReady() async {
        let store = MemoryFlowStore()
        let model = flow(store, start: .connect)
        #expect(model.step == .connect)
        await ConnectModel(data: model.connect, onDone: { _ in }, onBack: {}).connect("apple_health")
        #expect(model.connect.knowsYou.filled == 2)
        model.send(.connectBack)
        #expect(model.step == .privacy)
        model.send(.privacyDone)
        #expect(model.step == .connect)
        model.send(.connectDone)
        #expect(model.step == .gettingReady)
        #expect(store.saved?.step == .gettingReady)
        // the page's own exits are the flow's one event: later goes on too
        let later = flow(MemoryFlowStore(), start: .connect)
        let page = ConnectModel(data: later.connect, onDone: { _ in later.send(.connectDone) }, onBack: { later.send(.connectBack) })
        page.later()
        #expect(later.step == .gettingReady)
    }

    @Test("getting ready's sample episode starts when the page first asks, not at launch, and stays the same one")
    func episodeStartsWithThePage() {
        let model = flow(MemoryFlowStore(), start: .splash)
        let first = model.gettingReadyEpisode()
        #expect(model.gettingReadyEpisode() === first)
        guard case let .waiting(since) = first.state else {
            Issue.record("the sample episode should be waiting")
            return
        }
        // Paper's 55%: 66 s into the wait as the page opens
        #expect(abs(Date().timeIntervalSince(since) - SampleFirstEpisode.makingElapsed) < 5)
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
