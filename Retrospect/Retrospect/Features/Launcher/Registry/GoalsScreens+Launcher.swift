//
//  GoalsScreens+Launcher.swift
//  V2 lane 5 (plan-v2.md §3): GL-1 goals and GL-2 one goal, opened with
//  `-Screen GL-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//
//  GL-1 `rest`: the tab page on SampleGoals with the tab bar under it (goals selected). The bar is the
//  real RTabBar standing in for the shell's: picking another tab shows the plain canvas, as the shell
//  does for a tab with nothing built, and picking goals again comes back to the page as it was.
//  GL-2 `rest`: the same stack with "ship the first version" pushed, so back lands on GL-1. A pushed
//  page hides the tab bar. Your-words rows open JR-4 only when a group registers it (YO-D14 rule);
//  until then they are plain rows.
//
#if DEBUG
import SwiftUI

enum GoalsScreens: ScreenGroup {
    static let name = "goals"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "GL-1", states: ["rest"]) { _ in
            AnyView(GoalsLaunch(path: []))
        },
        LaunchableScreen(id: "GL-2", states: ["rest"]) { _ in
            AnyView(GoalsLaunch(path: [.goal(id: "goal.ship")]))
        },
    ]
}

/// The goals stack over the tab bar, on the sample.
struct GoalsLaunch: View {
    let path: [GoalsRoute]
    @State private var model = GoalsModel(data: SampleGoals())
    @State private var tab = RTab.goals
    @State private var pushed = false

    var body: some View {
        VStack(spacing: RDimension.space0) {
            ZStack {
                GoalsStack(model: model, path: path, entryPage: entryPage) { pushed = $0 }
                    .opacity(tab == .goals ? 1 : 0)
                    .allowsHitTesting(tab == .goals)
                    .accessibilityHidden(tab != .goals)
                if tab != .goals {
                    RColor.backgroundCanvas
                }
            }
            if !pushed {
                RTabBar(selection: $tab)
            }
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }

    /// JR-4 when a group registers it (pushed on the goals stack); nil (plain rows) until then.
    private var entryPage: ((String) -> AnyView)? {
        guard let jr4 = ScreenRegistry.screen("JR-4") else { return nil }
        return { _ in jr4.build(LaunchArguments()) }
    }
}
#endif
