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

    /// PI0 on the sample sign-in: the first tap signs in (no scripted failure in the flow).
    let signIn: SignInModel
    /// PI1 + PI2: one model for the gate and "you're in", so the ticket is one instance.
    let invite: InviteModel
    /// ON-3–9's seam.
    let firstRun: SampleFirstRunData

    @ObservationIgnored private let store: any SampleFlowStore
    @ObservationIgnored private let table: [FlowEdge]
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
        step = saved.step
        answers = Self.keyed(saved.answers)
        signIn = SignInModel(
            look: .splash,
            coordinator: SampleSignIn(script: [.signedIn(firstName: SampleInvite.firstName, access: .waitlisted)], sleep: sleep)
        )
        invite = Self.inviteModel(at: saved.step, sleep: sleep)
        firstRun = SampleFirstRunData(scenario: .questions, clock: clock)
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
        guard let next = FlowStep.next(from: step, event: event, table: table) else { return }
        step = next
        save()
    }

    /// The invite page's phase moved: once the stub has come away, the flow is at "you're in".
    func inviteMoved(to phase: InviteModel.Phase) {
        if phase == .torn || phase == .youreIn {
            send(.ticketTorn)
        }
    }

    /// An answer the questions page's seam kept.
    func answered(_ key: Key, words: String) {
        answers[key] = words
        save()
    }

    // MARK: - Private

    private func save() {
        let words = Dictionary(answers.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { first, _ in first })
        store.save(SampleFlowSaved(step: step, answers: words))
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

    /// The gate opens at the typed ticket (signed in, no code), as the live root does; a relaunch after the
    /// tear comes back at "you're in" (the ticket is already spent, `InviteModel.relaunched`).
    private static func inviteModel(at step: FlowStep, sleep: @escaping Sleep) -> InviteModel {
        var script = SampleInviteSource.Script()
        script.acceptsAnyCode = true
        let source = SampleInviteSource(script: script, sleep: sleep)
        let torn = step == .youreIn || step == .questions
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
