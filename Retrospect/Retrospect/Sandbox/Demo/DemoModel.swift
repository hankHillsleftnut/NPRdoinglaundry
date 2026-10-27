//
//  DemoModel.swift
//  DEMO.app: the demo's one model. It owns which stage is up and hands over between them; it never moves
//  a first-run step itself. The first run is the core flow's `SampleFlowModel` on its `FlowEdge.table`
//  (the FlowPlan engine), so the demo walks exactly the steps and edges the Core Flow scheme walks. The
//  demo's only edges are its own three hand-offs:
//  - first home (`FirstRunScreen.firstHome`, once FH.home.b makes it a step) → the app, journal first;
//  - AC-1 welcome back, signed in → the app;
//  - AC-1 "new here? get started" → the first run from the splash, nothing kept.
//  Until first home is a step the first run ends where the core flow ends (`-DemoStart app` opens the
//  app). No bridge edge, no placeholder page. Every move is saved, so a relaunch lands where it was.
//
#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class DemoModel {
    typealias Sleep = SampleFlowModel.Sleep

    /// The stage on screen.
    private(set) var stage: DemoStage
    /// The first run: the core flow's model, replaced (never reset in place) when the first run starts fresh.
    private(set) var flow: SampleFlowModel
    /// AC-1 welcome back, while the stage is `.returning`.
    private(set) var returning: SignInModel?
    /// Counts signed-in sessions: the app's pages are rebuilt for each, so nothing from the last one shows.
    private(set) var session = 0

    @ObservationIgnored private let store: any DemoStageStore
    @ObservationIgnored private let flowStore: any SampleFlowStore
    @ObservationIgnored private let handOff: FlowStep?
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var hasStarted = false

    /// `launch.start` opens that stage with nothing kept; `flowStart` is `-FlowStart` (the first run's own
    /// reset). `handOff` is the first-run step that hands over to the app: first home, once it is a step.
    init(
        store: any DemoStageStore,
        flowStore: any SampleFlowStore,
        launch: DemoLaunch = DemoLaunch(),
        flowStart: FlowStep? = nil,
        handOff: FlowStep? = FirstRunScreen.firstHome.step,
        sleep: @escaping Sleep = { try? await Task.sleep(for: $0) },
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        // reads only: SwiftUI may build (and drop) this model more than once, so nothing is written here
        // `-FlowStart` asks for a first-run step, so it opens the first run whatever stage was saved
        let stage = launch.start ?? (flowStart == nil ? nil : .firstRun) ?? store.load() ?? .firstRun
        // a fresh first run (`-DemoStart firstRun`) begins at the splash with nothing kept
        let start = flowStart ?? (launch.start == .firstRun ? FlowStep.splash : nil)
        self.store = store
        self.flowStore = flowStore
        self.handOff = handOff
        self.sleep = sleep
        self.clock = clock
        self.stage = stage
        flow = SampleFlowModel(store: flowStore, start: start, sleep: sleep, clock: clock)
        if stage == .returning {
            returning = makeReturning()
        }
    }

    // MARK: - Moves

    /// The host is on screen with this model: the stage is saved once, and the hand-offs are followed.
    /// Later calls do nothing.
    func started() {
        guard !hasStarted else { return }
        hasStarted = true
        store.save(stage)
        // already at the hand-off step (a relaunch there, or `-FlowStart` on it): hand over now
        flowMoved(to: flow.step)
        followFlow()
        followReturning()
    }

    /// The first run reached its hand-off step: the app, journal first.
    func flowMoved(to step: FlowStep) {
        guard stage == .firstRun, let handOff, step == handOff else { return }
        enterApp()
    }

    /// Signed out (ST-9 → AC-2 done): welcome back. The app's pages go with the session.
    func signedOut() {
        guard stage == .app else { return }
        returning = makeReturning()
        stage = .returning
        store.save(stage)
        followReturning()
    }

    // MARK: - Private

    private func enterApp() {
        session += 1
        returning = nil
        stage = .app
        store.save(stage)
    }

    /// "new here? get started": a new first run from the splash, with nothing kept from the last one.
    private func startFresh() {
        returning = nil
        flow = SampleFlowModel(store: flowStore, start: .splash, sleep: sleep, clock: clock)
        stage = .firstRun
        store.save(stage)
        followFlow()
    }

    /// AC-1 on the sample sign-in: the first tap signs the sample person back in.
    private func makeReturning() -> SignInModel {
        let model = SignInModel(
            look: .returning,
            coordinator: SampleSignIn(script: [.signedIn(firstName: SampleInvite.firstName, access: .member)], sleep: sleep)
        )
        model.onSignedIn = { [weak self, weak model] _, _ in
            // welcome back signs in to the app; the splash it can turn into starts a first run instead
            guard let self, let model, model.look == .returning, stage == .returning else { return }
            enterApp()
        }
        return model
    }

    /// Every step the first run moves to reaches `flowMoved`, read after the change lands.
    private func followFlow() {
        let current = flow
        withObservationTracking {
            _ = current.step
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, flow === current else { return }
                flowMoved(to: current.step)
                followFlow()
            }
        }
    }

    /// Welcome back turning into the splash ("new here? get started") starts a fresh first run.
    private func followReturning() {
        guard let current = returning else { return }
        withObservationTracking {
            _ = current.look
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, returning === current else { return }
                if current.look == .splash {
                    startFresh()
                } else {
                    followReturning()
                }
            }
        }
    }
}
#endif
