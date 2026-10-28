//
//  DemoShell.swift
//  DEMO.app: the app after the first run: the shell (#213, sheets over the bar: G0b) over the four tabs,
//  every tab live on the session's samples. Each tab is its group's own page on its group's own stack, so
//  the joins inside a group work as that group built them; the joins between groups come through the app
//  route table (G0): a control asks the environment's router, the page is built by its owning group and
//  pushed onto the stack the control is in (so back returns there), and sheets rise over the whole shell.
//  The demo declares no route and builds no page of its own.
//
#if DEBUG
import SwiftUI

struct DemoShell: View {
    /// The first run that just ended at first home: the journal tab shows ON-13 on its answers, as the core
    /// flow does (FirstHomePage); nil on any later launch (JR-1 with its drawer and joins).
    var firstHome: SampleFlowModel?
    /// Hands the session's ST-9 sign-out flow to the host once, which follows it to AC-1 welcome back.
    var followSignOut: (any SignOutFlowing) -> Void = { _ in }
    @State private var model: ShellModel
    @State private var samples = DemoSamples()

    /// Opens on `tab` (`-DemoTab`, journal by default).
    init(
        tab: RTab = .journal,
        firstHome: SampleFlowModel? = nil,
        followSignOut: @escaping (any SignOutFlowing) -> Void = { _ in }
    ) {
        self.firstHome = firstHome
        self.followSignOut = followSignOut
        _model = State(initialValue: ShellModel(selection: tab, available: Set(RTab.allCases)))
    }

    var body: some View {
        ShellPage(model: model) { tab, context in
            switch tab {
            case .journal:
                if let flow = firstHome {
                    AnyView(DemoFirstHome(flow: flow, isShown: context.isShown))
                } else {
                    AnyView(DemoJournalTab(samples: samples))
                }
            // PC-1 on the sample library (its play joins the player once the shared play button lands)
            case .podcasts: AnyView(PodcastsLaunch(scenario: .rest))
            case .goals: AnyView(DemoGoalsTab(samples: samples))
            case .you: AnyView(DemoYouTab(samples: samples))
            }
        }
        .demoSamples(samples)
        // the session's sign-out, followed by the demo model (tested there end to end)
        .onAppear { followSignOut(samples.signOut) }
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

/// JR-1 with the drawer (JR-3): a row pushes JR-4, the foot's "settings" pushes ST-1, and the brief card
/// raises JR-2 over the shell. One stack of app routes, so every back returns to the drawer or JR-1.
private struct DemoJournalTab: View {
    let samples: DemoSamples

    var body: some View {
        AppRouteStack {
            DemoJournalRoot(samples: samples)
        }
    }
}

private struct DemoJournalRoot: View {
    let samples: DemoSamples
    @State private var isOpen = false
    @State private var drawer: DrawerModel?
    @Environment(\.appRouter) private var router

    var body: some View {
        DrawerHost(isOpen: $isOpen) { onHomeIndicator in
            if let drawer {
                DrawerPage(model: drawer, onHomeIndicator: onHomeIndicator) {
                    router.opener(.settings(.hub))?()
                }
            }
        } journal: {
            JournalPageContainer(
                today: SampleJournalContent.today,
                openDrawer: { isOpen = true },
                openBrief: router.presenter(.brief(id: nil))
            )
        }
        .onAppear(perform: makeDrawer)
    }

    /// The drawer on the session's entries, its rows opening JR-4 on this stack.
    private func makeDrawer() {
        guard drawer == nil else { return }
        let model = DrawerModel(data: samples.entries, hereID: SampleEntriesData.hereID)
        let push = router.push
        model.onOpen = { row in push?(.entry(id: row.id)) }
        drawer = model
    }
}

/// GL-1 → GL-2 on the goals stack; GL-2's "your words" pushes JR-4 (built by the journal group) on it.
/// Only the goal Paper draws a GL-2 for opens (GL-D11).
private struct DemoGoalsTab: View {
    @State private var model: GoalsModel

    init(samples: DemoSamples) {
        _model = State(initialValue: GoalsModel(data: samples.goals))
    }

    var body: some View {
        GoalsStack(
            model: model,
            entryPage: AppRoutes.isBuilt(.entry(id: "")) ? { id in AnyView(DemoStackedEntry(id: id)) } : nil,
            canOpen: SampleGoals.drawnDetails.contains
        )
    }
}

/// JR-4 pushed on a group's own typed stack (goals): back pops it the way the stack's own back would.
private struct DemoStackedEntry: View {
    let id: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppRoutes.page(for: .entry(id: id), in: AppRouteContext(back: { dismiss() }))
    }
}

/// YO-1 and the pages it opens (YO-2 in place, YO-3, YO-4 sheet, YO-5) on the You stack; your picture
/// pushes ST-1 (settings group) onto it.
private struct DemoYouTab: View {
    let samples: DemoSamples
    @State private var navigator = YouNavigator()
    @State private var model: YouModel?

    var body: some View {
        YouStack(data: samples.you, navigator: navigator, joinsApp: true) {
            RSheetHost {
                if let model {
                    YouPage(model: model, navigator: navigator)
                } else {
                    RColor.backgroundCanvas.onAppear { model = YouModel(data: samples.you) }
                }
            }
        }
    }
}
#endif
