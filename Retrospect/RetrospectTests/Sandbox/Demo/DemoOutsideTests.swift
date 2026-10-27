import Foundation
@testable import Retrospect
import Testing

/// DEMO.app.c: the ways in from outside the app (`-DemoOutside`), standing in for the share extension,
/// notifications and widgets: the system opens the signed-in app, the app acts on it once, and the sheets
/// it raises are built by their owners (EX-1 by outside, JR-2 by journal).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DemoOutsideTests {
    private func demo(_ launch: DemoLaunch, store: MemoryDemoStore = MemoryDemoStore(.firstRun)) -> DemoModel {
        let model = DemoModel(store: store, flowStore: MemoryFlowStore(), launch: launch, sleep: { _ in })
        model.started()
        return model
    }

    @Test("the arguments name a way in; an unknown one is ignored")
    func arguments() {
        #expect(DemoLaunch.parse(["-DemoOutside", "share"]).outside == .share)
        #expect(DemoLaunch.parse(["-DemoOutside", "brief", "-DemoStart", "app"]) == DemoLaunch(start: .app, outside: .brief))
        #expect(DemoLaunch.parse(["-DemoOutside", "fax"]).outside == nil)
        #expect(DemoLaunch.parse(["-DemoOutside"]).outside == nil)
    }

    @Test("in the app, the app acts on the way in once; it never moves the stage")
    func opensTheAppOnce() {
        let store = MemoryDemoStore(.app)
        let model = demo(DemoLaunch(outside: .share), store: store)
        #expect(model.stage == .app)
        #expect(model.takeOutside() == .share)
        #expect(model.takeOutside() == nil)
        #expect(store.saved == .app)
    }

    @Test("outside the app (first run, welcome back) the way in is dropped and the stage is kept")
    func notInTheApp() {
        let store = MemoryDemoStore(.firstRun)
        let first = demo(DemoLaunch(outside: .brief), store: store)
        #expect(first.stage == .firstRun)
        #expect(first.takeOutside() == nil)
        #expect(store.saved == .firstRun)
        let back = demo(DemoLaunch(start: .returning, outside: .brief))
        #expect(back.stage == .returning)
        #expect(back.takeOutside() == nil)
    }

    @Test("what each way in raises is built by its owner")
    func sheetsAreBuilt() {
        #expect(AppRoutes.isBuilt(.share))
        #expect(AppRoutes.isBuilt(.brief(id: nil)))
    }
}
