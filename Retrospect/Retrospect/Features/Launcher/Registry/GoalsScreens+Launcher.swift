//
//  GoalsScreens+Launcher.swift
//  V2 lane 5 (plan-v2.md §3): GL-1 goals and GL-2 one goal, opened with
//  `-Screen GL-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//
//  GL-1 `rest`: the tab page on SampleGoals with the tab bar under it (goals selected). The bar is the
//  real RTabBar standing in for the shell's: picking another tab shows the plain canvas, as the shell
//  does for a tab with nothing built, and picking goals again comes back to the page as it was.
//
#if DEBUG
import SwiftUI

enum GoalsScreens: ScreenGroup {
    static let name = "goals"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "GL-1", states: ["rest"]) { _ in
            AnyView(GoalsLaunch())
        },
    ]
}

/// GL-1 over the tab bar, on the sample.
struct GoalsLaunch: View {
    @State private var model = GoalsModel(data: SampleGoals())
    @State private var tab = RTab.goals

    var body: some View {
        VStack(spacing: RDimension.space0) {
            ZStack {
                GoalsPage(model: model)
                    .opacity(tab == .goals ? 1 : 0)
                    .allowsHitTesting(tab == .goals)
                    .accessibilityHidden(tab != .goals)
                if tab != .goals {
                    RColor.backgroundCanvas
                }
            }
            RTabBar(selection: $tab)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }
}
#endif
