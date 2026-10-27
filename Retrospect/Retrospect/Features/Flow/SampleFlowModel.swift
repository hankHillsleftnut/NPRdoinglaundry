//
//  SampleFlowModel.swift
//  FLOW.host: the sample flow's one model. It holds the step and every answer (answers live on the flow
//  model, not in a page), owns the existing screens' own models on their existing samples (PI0 on
//  `SampleSignIn`, PI1/PI2 on `SampleInviteSource`, ON-3–9 on `SampleFirstRunData`), and moves only where
//  `FlowEdge.table` says. Every change is saved, so a relaunch lands on the exact step with the answers kept
//  (founder decision 9). No backend, no session, no Keychain. Debug builds only.
//
#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class SampleFlowModel {
    typealias Key = Flows.QuestionKey
    typealias Sleep = @Sendable (Duration) async -> Void

    /// The step on screen.
    private(set) var step: FlowStep
    /// The words sent for each question, kept across launches.
    private(set) var answers: [Key: String]
    /// The step on screen was reached by a page's back (ON-5 back to the questions), not forward: the
    /// questions then open on the last one instead of finishing at once. Saved, so a relaunch keeps it.
    private(set) var cameBack = false
    /// The questions page finished `firstRun` (its `finishQuestions()` ran) in this launch: a later pass
    /// after back only hands on. In memory, like the seam it describes.
    private(set) var questionsFinished = false

    /// PI0 on the sample sign-in: the first tap signs in (no scripted failure in the flow).
    let signIn: SignInModel
    /// PI1 + PI2: one model for the gate and "you're in", so the ticket is one instance.
    let invite: InviteModel
    /// ON-3–9's seam (ON-10's answers go through it too).
    let firstRun: SampleFirstRunData
    /// ON-6's sample sources: one for the whole flow, so a connection made there is still made on a
    /// later visit.
    let connect: SampleConnect
    /// ON-10's simulated listening.
    let listening: SampleListening
    /// ON-10's episode, built the first time the page asks (see `gettingReadyEpisode()`).
    @ObservationIgnored private var episode: SampleFirstEpisode?
    /// ON-11's sheet for this visit (see `teaseSheet()`).
    @ObservationIgnored private var tease: PlayerSheetModel?

    /// The step whose page handed on to a screen that isn't built yet: the end of what's built. The host
    /// shows its "start over" pill while the flow is still there.
    private(set) var endedAt: FlowStep?

    /// The walk has reached the end of what's built (the page on screen handed on and nothing follows).
    var isAtEnd: Bool {
        endedAt == step
    }

    @ObservationIgnored private let store: any SampleFlowStore
    @ObservationIgnored private let table: [FlowEdge]
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var hasStarted = false

    /// `start` begins at that step with nothing kept (`-FlowStart`); nil resumes what the store holds.
    init(
        store: any SampleFlowStore,
        start: FlowStep? = nil,
        table: [FlowEdge] = FlowEdge.table,
        sleep: @escaping Sleep = { try? await Task.sleep(for: $0) },
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        // reads only: SwiftUI may build (and drop) this model more than once, so nothing is written here
        let saved = start.map { SampleFlowSaved(step: $0) } ?? store.load() ?? SampleFlowSaved()
        self.store = store
        self.table = table
        self.sleep = sleep
        self.clock = clock
        step = saved.step
        answers = Self.keyed(saved.answers)
        cameBack = saved.cameBack ?? false
        signIn = SignInModel(
            look: .splash,
            coordinator: SampleSignIn(script: [.signedIn(firstName: SampleInvite.firstName, access: .waitlisted)], sleep: sleep)
        )
        invite = Self.inviteModel(at: saved.step, sleep: sleep)
        firstRun = SampleFirstRunData(scenario: .questions, clock: clock)
        listening = SampleListening(clock: clock)
        connect = SampleConnect()
        signIn.onSignedIn = { [weak self] _, _ in self?.send(.signedIn) }
        invite.onFinish = { [weak self] in self?.send(.begin) }
        followInvite()
    }

    /// The tear hand-off, wired here (not in a view) like sign-in and "begin": every change of the invite
    /// page's phase reaches `inviteMoved`, read after the change lands.
    private func followInvite() {
        withObservationTracking {
            _ = invite.phase
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                inviteMoved(to: invite.phase)
                followInvite()
            }
        }
    }

    // MARK: - Moves

    /// The host is on screen with this model: the starting point is saved once (a `-FlowStart` start
    /// replaces what was kept). Later calls do nothing.
    func started() {
        guard !hasStarted else { return }
        hasStarted = true
        save()
    }

    /// A screen handed off: move where the table says, or stay (no edge: the flow ends here).
    func send(_ event: FlowEvent) {
        guard let next = FlowStep.next(from: step, event: event, table: table) else {
            // the page handed on to a screen the map plans but that isn't built: the walk ends here
            if Self.reachesUnbuilt(from: step, event: event) {
                endedAt = step
            }
            return
        }
        if step == .questions, event == .questionsDone {
            questionsFinished = true
        }
        cameBack = event == .back
        step = next
        save()
    }

    /// "start over": a fresh flow from the splash on the same store with nothing kept (every page's model
    /// is new, as on a first launch). The host swaps it in.
    func startedOver() -> SampleFlowModel {
        let fresh = SampleFlowModel(store: store, start: .splash, table: table, sleep: sleep, clock: clock)
        fresh.started()
        return fresh
    }

    /// The map plans a hand-off from `step` on `event` into a screen that isn't a step yet.
    private static func reachesUnbuilt(from step: FlowStep, event: FlowEvent) -> Bool {
        FlowPlan.edges.contains { $0.from.rawValue == step.rawValue && $0.event == event.rawValue && $0.to.step == nil }
    }

    /// The invite page's phase moved: once the stub has come away, the flow is at "you're in".
    func inviteMoved(to phase: InviteModel.Phase) {
        if phase == .torn || phase == .youreIn {
            send(.ticketTorn)
        }
    }

    /// ON-10's sample episode, started when the page first shows (so a walk from the splash opens it
    /// where Paper draws the line, 66 s into the wait, however long the walk took); the same one after.
    func gettingReadyEpisode() -> SampleFirstEpisode {
        if let episode {
            return episode
        }
        let made = SampleFirstEpisode(scenario: .makingThenReady)
        episode = made
        return made
    }

    /// ON-11's sheet: the 10-second sample tease (PS.sheet Q5 = B), playing from 0:00 as it rises, made
    /// the first time the host asks and kept for the visit. Its end (or its collapse) sends `teaseEnded`;
    /// the end is watched here, not in a view, like the tear.
    func teaseSheet() -> PlayerSheetModel {
        if let tease {
            return tease
        }
        let playback = SamplePlayback(scenario: .tease, clock: clock)
        let made = PlayerSheetModel(
            playback: playback,
            transcript: SampleTranscript.tease,
            onCollapse: { [weak self, weak playback] in
                // never sound under what comes next (the paywall): the tease stops as it hands on
                playback?.pause()
                self?.send(.teaseEnded)
            }
        )
        tease = made
        followTease(playback)
        return made
    }

    /// Hands `teaseEnded` on once the sample tease reaches its end.
    private func followTease(_ playback: SamplePlayback) {
        withObservationTracking {
            _ = playback.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if playback.state == .ended {
                    send(.teaseEnded)
                } else {
                    followTease(playback)
                }
            }
        }
    }

    /// ON-5 for one visit, on the sample read-aloud (about 8 s, decision 3). A left page never fires again,
    /// so each visit gets a fresh model: Retro finishing (or a tap) sends `privacyDone`, the back chevron
    /// sends `back` to the last question. `clock` is the page's reading clock (tests pass an instant one).
    func makePrivacy(clock: any Clock<Duration> = ContinuousClock()) -> PrivacyModel {
        PrivacyModel(
            readAloud: SamplePrivacyReadAloud(clock: clock),
            onAdvance: { [weak self] in self?.send(.privacyDone) },
            onBack: { [weak self] in self?.send(.back) }
        )
    }

    /// An answer the questions page's seam kept.
    func answered(_ key: Key, words: String) {
        answers[key] = words
        save()
    }

    // MARK: - Private

    private func save() {
        let words = Dictionary(answers.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { first, _ in first })
        store.save(SampleFlowSaved(step: step, answers: words, cameBack: cameBack ? true : nil))
    }

    /// Saved answers back to keys; a key the app doesn't know is dropped.
    private static func keyed(_ saved: [String: String]) -> [Key: String] {
        var answers: [Key: String] = [:]
        for (raw, words) in saved {
            if let key = Key(rawValue: raw), key != .unknown {
                answers[key] = words
            }
        }
        return answers
    }

    /// A step's place in the app's order (`FlowStep` lists them in order).
    private static func order(of step: FlowStep) -> Int {
        FlowStep.allCases.firstIndex(of: step) ?? 0
    }

    /// The gate opens at the typed ticket (signed in, no code), as the live root does; a relaunch after the
    /// tear comes back at "you're in" (the ticket is already spent, `InviteModel.relaunched`).
    private static func inviteModel(at step: FlowStep, sleep: @escaping Sleep) -> InviteModel {
        var script = SampleInviteSource.Script()
        script.acceptsAnyCode = true
        let source = SampleInviteSource(script: script, sleep: sleep)
        // every step from "you're in" on comes after the tear
        let torn = Self.order(of: step) >= Self.order(of: .youreIn)
        // already torn on an earlier launch: shown still, not replayed
        let sample = SampleInvite.youreIn
        let stub = Session.YoureIn(invitedBy: sample.invitedBy, serial: sample.serial, redeemedOn: sample.redeemedOn, animate: false)
        let model = InviteModel(
            phase: torn ? .youreIn : .typed,
            source: source,
            signIn: source,
            // the typed ticket wears Paper's header before the check, in the sample only (founder, 26 Oct)
            face: SampleInvite.face,
            firstName: SampleInvite.firstName,
            youreIn: torn ? stub : nil,
            sleep: sleep
        )
        if torn {
            // the kept ticket comes back whole, as `-Screen PI2 -State youreIn` draws it: who it's from, its
            // number and the code on the stub (the sample's; the words typed before the relaunch aren't kept)
            model.applySample(InviteSetup(phase: .youreIn))
        }
        return model
    }
}
#endif
