//
//  DemoAppHost.swift
//  DEMO.app: `-Flow demo` (debug) opens the app here: the whole app walkable on sample data. One switch on
//  the demo's stage mounts what already exists, and nothing drawn of its own:
//  - the first run: the core flow's `SampleFlowHost` on the demo's `SampleFlowModel` (same steps, same
//    edges as the Core Flow scheme);
//  - the app: the shell (#213) with each tab's page on its group's sample, as each group's own stack
//    builds it (`DemoShell`);
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
                DemoShell(firstHome: demo.firstDay ? demo.flow : nil)
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

/// The app after the first run: the shell over the four tabs, every tab live, each on its group's sample.
/// Each page is its group's own stack, so the joins inside a group work as that group built them; the
/// joins between groups come through G0's route table (DEMO.app.b).
struct DemoShell: View {
    /// The first run that just ended at first home: the journal tab shows ON-13 on its answers, as the core
    /// flow does (FirstHomePage); nil on any later launch (JR-1).
    var firstHome: SampleFlowModel?
    @State private var model = ShellModel(selection: .journal, available: Set(RTab.allCases))

    var body: some View {
        ShellPage(model: model) { tab, context in
            switch tab {
            case .journal:
                if let flow = firstHome {
                    AnyView(DemoFirstHome(flow: flow, isShown: context.isShown))
                } else {
                    // JR-1 with the drawer (JR-3) and one entry (JR-4), as the journal lane mounts them
                    AnyView(EntriesLaunch(scenario: .flow))
                }
            // PC-1 on the sample library
            case .podcasts: AnyView(PodcastsLaunch(scenario: .rest))
            case .goals: AnyView(DemoGoalsTab())
            case .you: AnyView(DemoYouTab())
            }
        }
    }
}

/// ON-13 first home, built exactly as the core flow builds it (SampleFlowHost's `.firstHome`): the
/// celebration, the recap of the person's own answers, the first-episode card that plays the tease.
private struct DemoFirstHome: View {
    let flow: SampleFlowModel
    let isShown: Bool

    var body: some View {
        FirstHomePage(
            recap: flow.firstHomeRecap,
            celebrate: flow.arrivedHome,
            today: SampleJournalContent.today,
            makePlayer: { onCollapse in flow.makeFirstEpisodePlayer(onCollapse: onCollapse) },
            isShown: isShown
        )
        .environment(\.journalData, flow.journalDay)
    }
}

/// GL-1 → GL-2 on the goals stack, on the sample. Only the goal Paper draws a GL-2 for opens (GL-D11).
private struct DemoGoalsTab: View {
    @State private var model = GoalsModel(data: SampleGoals())

    var body: some View {
        GoalsStack(model: model, canOpen: SampleGoals.drawnDetails.contains)
    }
}

/// YO-1 and the pages it opens (YO-2 in place, YO-3, YO-4 sheet, YO-5) on the You stack, on the sample.
private struct DemoYouTab: View {
    @State private var data = SampleYou()
    @State private var navigator = YouNavigator()
    @State private var model: YouModel?

    var body: some View {
        YouStack(data: data, navigator: navigator) {
            RSheetHost {
                if let model {
                    YouPage(model: model, navigator: navigator)
                } else {
                    RColor.backgroundCanvas.onAppear { model = YouModel(data: data) }
                }
            }
        }
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
