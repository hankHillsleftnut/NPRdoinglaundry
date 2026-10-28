//
//  FirstRunShell+Launcher.swift
//  FLOW.edges.d (J3b): the tab shell first home sits in, for the sample flow host. Founder, 27 Oct (FH-Q1,
//  DECISIONS: "show all four tabs from day one"): first home is the journal tab inside the shell, and
//  podcasts, goals and you are live on their samples from the first day. Declared here, with the other
//  launcher wrappers, because it names the shell and the V2 tab pages (the dark folders): the debug sample
//  flow mounts this view, and the release root does not (that is its own founder-approved wiring PR, and
//  ReleaseRouteTableTests still fences the folders). Debug builds only.
//
#if DEBUG
import SwiftUI

/// The four tabs under the shell's bar: the journal tab is whatever the host passes (first home); the
/// others are PC-1, GL-1 and YO-1 on their samples, each built the first time its tab is shown and kept.
struct FirstRunShell<Journal: View>: View {
    @State private var model = ShellModel(selection: .journal)
    @State private var goals = GoalsModel(data: SampleGoals())
    @State private var youData = SampleYou()
    @State private var youNavigator = YouNavigator()
    @State private var you: YouModel?
    @ViewBuilder let journal: () -> Journal

    var body: some View {
        ShellPage(model: model) { tab, _ in
            switch tab {
            case .journal:
                AnyView(journal())
            case .podcasts:
                AnyView(PodcastsLaunch(scenario: .rest))
            case .goals:
                AnyView(GoalsStack(model: goals, canOpen: SampleGoals.drawnDetails.contains))
            case .you:
                AnyView(YouStack(data: youData, navigator: youNavigator) { youRoot })
            }
        }
    }

    @ViewBuilder private var youRoot: some View {
        if let you {
            YouPage(model: you, navigator: youNavigator)
        } else {
            RColor.backgroundCanvas
                .onAppear { you = YouModel(data: youData) }
        }
    }
}
#endif
