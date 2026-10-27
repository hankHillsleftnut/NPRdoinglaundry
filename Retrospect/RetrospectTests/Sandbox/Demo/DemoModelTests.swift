import Foundation
@testable import Retrospect
import Testing

/// DEMO.app: the full-app demo's stages and hand-offs. The first run is the core flow's own model (its
/// steps and edges are FlowHostTests'/FlowPlanTests'); here: the demo starts, resumes and hands over only
/// where it should, keeps its place apart from the Core Flow scheme's, and welcome back leads either to the
/// app or to a fresh first run.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DemoModelTests {
    private let noWait: DemoModel.Sleep = { _ in }

    private func demo(
        _ store: MemoryDemoStore = MemoryDemoStore(),
        flowStore: MemoryFlowStore = MemoryFlowStore(),
        start: DemoStage? = nil,
        flowStart: FlowStep? = nil,
        handOff: FlowStep? = FirstRunScreen.firstHome.step
    ) -> DemoModel {
        let model = DemoModel(store: store, flowStore: flowStore, launch: DemoLaunch(start: start), flowStart: flowStart, handOff: handOff, sleep: noWait)
        model.started()
        return model
    }

    /// Lets the observation hand-offs (one main-actor hop each) land.
    private func settle(until done: () -> Bool) async {
        for _ in 0 ..< 200 where !done() {
            await Task.yield()
        }
    }

    @Test("the first launch opens the first run at the splash, on the core flow's model")
    func firstLaunch() {
        let store = MemoryDemoStore()
        let model = demo(store)
        #expect(model.stage == .firstRun)
        #expect(model.flow.step == .splash)
        #expect(store.saved == .firstRun)
    }

    @Test("a relaunch resumes the stage, and the first run resumes its step")
    func resumes() {
        let store = MemoryDemoStore(.firstRun)
        let flowStore = MemoryFlowStore(SampleFlowSaved(step: .questions, answers: ["name.place": "sam."]))
        let model = demo(store, flowStore: flowStore)
        #expect(model.stage == .firstRun)
        #expect(model.flow.step == .questions)
        #expect(model.flow.answers[.namePlace] == "sam.")
        #expect(demo(MemoryDemoStore(.app)).stage == .app)
    }

    @Test("-DemoStart opens a stage; a fresh first run keeps nothing")
    func demoStart() {
        let kept = MemoryFlowStore(SampleFlowSaved(step: .questions, answers: ["name.place": "sam."]))
        let fresh = demo(MemoryDemoStore(.app), flowStore: kept, start: .firstRun)
        #expect(fresh.stage == .firstRun)
        #expect(fresh.flow.step == .splash)
        #expect(fresh.flow.answers.isEmpty)
        #expect(demo(start: .app).stage == .app)
        let back = demo(start: .returning)
        #expect(back.stage == .returning)
        #expect(back.returning?.look == .returning)
    }

    @Test("the first run hands over to the app at its hand-off step, and only there")
    func handOff() async {
        let store = MemoryDemoStore()
        // privacy stands in for first home (not a step yet): the rule, not the step, is under test
        let model = demo(store, flowStart: .questions, handOff: .privacy)
        #expect(model.stage == .firstRun)
        model.flow.send(.questionsDone)
        await settle { model.stage == .app }
        #expect(model.stage == .app)
        #expect(store.saved == .app)
        #expect(model.session == 1)
    }

    @Test("a first run already at its hand-off step hands over as soon as the demo starts")
    func handOffAtStart() {
        let model = demo(flowStart: .privacy, handOff: .privacy)
        #expect(model.stage == .app)
    }

    @Test("-FlowStart opens the first run at that step even when the app stage was saved")
    func flowStartWinsOverSavedApp() {
        let model = demo(MemoryDemoStore(.app), flowStart: .questions)
        #expect(model.stage == .firstRun)
        #expect(model.flow.step == .questions)
    }

    @Test("with no hand-off step built, the first run ends where the core flow ends: no bridge to the app")
    func noHandOffYet() async {
        let model = demo(flowStart: .questions, handOff: nil)
        model.flow.send(.questionsDone)
        await settle { model.flow.step == .privacy }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(model.flow.step == .privacy)
        #expect(model.stage == .firstRun)
    }

    @Test("welcome back signs in to the app with a new session")
    func welcomeBackSignsIn() async {
        let store = MemoryDemoStore()
        let model = demo(store, start: .returning)
        let before = model.session
        await model.returning?.appleFinished(.failure(SampleTap()))
        await settle { model.stage == .app }
        #expect(model.stage == .app)
        #expect(model.session == before + 1)
        #expect(model.returning == nil)
        #expect(store.saved == .app)
    }

    @Test("'new here? get started' starts a first run from the splash with nothing kept")
    func newHereStartsFresh() async {
        let flowStore = MemoryFlowStore(SampleFlowSaved(step: .questions, answers: ["name.place": "sam."]))
        let model = demo(flowStore: flowStore, start: .returning)
        let old = model.flow
        model.returning?.startFresh()
        await settle { model.stage == .firstRun }
        #expect(model.stage == .firstRun)
        #expect(model.flow !== old)
        #expect(model.flow.step == .splash)
        #expect(model.flow.answers.isEmpty)
        #expect(model.returning == nil)
    }

    @Test("signing out in the app goes to welcome back; it does nothing elsewhere")
    func signedOut() {
        let store = MemoryDemoStore()
        let model = demo(store, start: .app)
        model.signedOut()
        #expect(model.stage == .returning)
        #expect(model.returning?.look == .returning)
        #expect(store.saved == .returning)
        let first = demo(start: .firstRun)
        first.signedOut()
        #expect(first.stage == .firstRun)
    }

    @Test("a model SwiftUI builds and drops writes nothing")
    func onlyTheKeptModelWrites() {
        let store = MemoryDemoStore(.app)
        _ = DemoModel(store: store, flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .firstRun), sleep: noWait)
        #expect(store.saved == .app)
    }

    @Test("the demo keeps its place in its own suite, never in the Core Flow scheme's")
    func ownSuite() throws {
        let name = "retrospect.demo.tests.\(UUID().uuidString)"
        let suite = try #require(DemoDefaults.suite(named: name))
        defer { UserDefaults.standard.removePersistentDomain(forName: name) }
        let before = UserDefaults.standard.data(forKey: UserDefaultsFlowStore.key)
        UserDefaultsFlowStore(defaults: suite).save(SampleFlowSaved(step: .privacy))
        UserDefaultsDemoStore(defaults: suite).save(.app)
        #expect(UserDefaults.standard.data(forKey: UserDefaultsFlowStore.key) == before)
        #expect(UserDefaultsFlowStore(defaults: suite).load()?.step == .privacy)
        #expect(UserDefaultsDemoStore(defaults: suite).load() == .app)
        #expect(DemoDefaults.suiteName != Bundle.main.bundleIdentifier)
    }

    @Test("the arguments: -Flow demo is a sample flow that is the demo; -DemoStart names a stage")
    func arguments() {
        let demo = FlowLaunch.parse(["-Flow", "demo"])
        #expect(demo.isRequested)
        #expect(demo.isDemo)
        #expect(FlowLaunch.parse(["-Flow", "sample"]).isDemo == false)
        #expect(FlowLaunch.parse(["-Flow", "demo", "-FlowStart", "questions"]).start == .questions)
        #expect(DemoLaunch.parse([]) == DemoLaunch())
        #expect(DemoLaunch.parse(["-DemoStart", "app"]).start == .app)
        #expect(DemoLaunch.parse(["-DemoStart", "returning"]).start == .returning)
        #expect(DemoLaunch.parse(["-DemoStart", "nowhere"]).start == nil)
        #expect(DemoLaunch.parse(["-DemoStart"]).start == nil)
    }
}
