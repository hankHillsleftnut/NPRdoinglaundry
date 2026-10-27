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
        #expect(DemoLaunch.parse(["-DemoOutside", "talk"]).outside == .talk)
        #expect(DemoLaunch.parse(["-DemoOutside", "fax"]).outside == nil)
        #expect(DemoLaunch.parse(["-DemoOutside"]).outside == nil)
    }

    @Test("the system opens the signed-in app, and the app acts on the way in once")
    func opensTheAppOnce() {
        let model = demo(DemoLaunch(outside: .share))
        #expect(model.stage == .app)
        #expect(model.takeOutside() == .share)
        #expect(model.takeOutside() == nil)
    }

    @Test("an explicit stage wins; outside the app the way in is dropped")
    func explicitStageWins() {
        let model = demo(DemoLaunch(start: .returning, outside: .brief))
        #expect(model.stage == .returning)
        #expect(model.takeOutside() == nil)
    }

    @Test("what each way in raises is built by its owner")
    func sheetsAreBuilt() {
        #expect(AppRoutes.isBuilt(.share))
        #expect(AppRoutes.isBuilt(.brief(id: nil)))
    }
}
