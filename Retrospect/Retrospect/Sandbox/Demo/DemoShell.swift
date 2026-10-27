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
    /// ST-9's sign-out reached its end: the demo shows AC-1 welcome back.
    var signedOut: () -> Void = {}
    @State private var model = ShellModel(selection: .journal, available: Set(RTab.allCases))
    @State private var samples = DemoSamples()

    var body: some View {
        ShellPage(model: model) { tab, _ in
            switch tab {
            case .journal: AnyView(DemoJournalTab(samples: samples))
            // PC-1 on the sample library (its play joins the player once the shared play button lands)
            case .podcasts: AnyView(PodcastsLaunch(scenario: .rest))
            case .goals: AnyView(DemoGoalsTab(samples: samples))
            case .you: AnyView(DemoYouTab(samples: samples))
            }
        }
        .demoSamples(samples)
        .onChange(of: samples.signOut.state) { _, state in
            if state == .done {
                signedOut()
            }
        }
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
        YouStack(data: samples.you, navigator: navigator) {
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
