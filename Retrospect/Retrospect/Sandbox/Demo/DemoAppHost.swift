//
//  DemoAppHost.swift
//  DEMO.app: `-Flow demo` (debug) opens the app here: the whole app walkable on sample data. One switch on
//  the demo's stage mounts what already exists, and nothing drawn of its own:
//  - the first run: the core flow's `SampleFlowHost` on the demo's `SampleFlowModel` (same steps, same
//    edges as the Core Flow scheme);
//  - the app: the shell (#213) with each tab's page on its group's own stack, joined through the app
//    route table (G0), on one set of samples per session (`DemoShell`, `DemoSamples`);
//  - welcome back: AC-1 (`SignInScreen`, returning look) on sample taps.
//  Every backend guard of `-Flow sample` applies (the demo is a sample flow to `RetrospectApp`): no
//  session, no Keychain, no outbox, no addresses. Sandbox: never in a release build.
//
#if DEBUG
import SwiftUI

struct DemoAppHost: View {
    @State private var demo: DemoModel

    init(launch: DemoLaunch = .current, flowLaunch: FlowLaunch = .current) {
        // the demo's own suite: its place never moves the Core Flow scheme's (`-Flow sample`)
        let suite = DemoDefaults.suite()
        let store: any DemoStageStore = suite.map { UserDefaultsDemoStore(defaults: $0) } ?? MemoryDemoStore()
        let flowStore: any SampleFlowStore = suite.map { UserDefaultsFlowStore(defaults: $0) } ?? MemoryFlowStore()
        _demo = State(initialValue: DemoModel(store: store, flowStore: flowStore, launch: launch, flowStart: flowLaunch.start))
    }

    init(demo: DemoModel) {
        _demo = State(initialValue: demo)
    }

    var body: some View {
        Group {
            switch demo.stage {
            case .firstRun:
                SampleFlowHost(flow: demo.flow)
                    // a fresh first run is a new model: the host takes it, not the last one's
                    .id(ObjectIdentifier(demo.flow))
            case .app:
                // straight from the first run, the journal tab is first home (ON-13) until the next launch
                DemoShell(tab: demo.startTab, firstHome: demo.firstDay ? demo.flow : nil, opened: { demo.takeOutside() }) {
                    demo.follow(signOut: $0)
                }
                // a new session builds every page again on fresh samples
                .id(demo.session)
            case .returning:
                if let returning = demo.returning {
                    SignInScreen(model: returning, sampleTaps: true)
                }
            }
        }
        // the same move between pages as the live root's
        .animation(RMotion.snappy, value: demo.stage)
        // the kept model only: a model SwiftUI built and dropped never writes
        .onAppear { demo.started() }
    }
}

#Preview("demo · from the splash") {
    DemoAppHost(demo: DemoModel(store: MemoryDemoStore(), flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .firstRun)))
}

#Preview("demo · the app") {
    DemoAppHost(demo: DemoModel(store: MemoryDemoStore(), flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .app)))
}

#Preview("demo · welcome back") {
    DemoAppHost(demo: DemoModel(store: MemoryDemoStore(), flowStore: MemoryFlowStore(), launch: DemoLaunch(start: .returning)))
}
#endif
