//
//  YouScreens+Launcher.swift
//  V2 lane 3 (plan-v2.md §3): YO-1 you, YO-2 search, YO-3 a source, YO-4 a node, YO-5 what i know
//  about you, opened with `-Screen YO-<n> -State <state> -Data sample`. Dark: listed here and
//  nowhere in the release root.
//
//  V2.you.a: YO-5 `rest`. V2.you.b: YO-3 `rest`, `editing`. Until YO-1 and YO-2 are built (V2.you.c, d)
//  each page opens at its stack's root, so back has nowhere to go in the launcher (as the account page's
//  launcher). Another group's screen opens only when the registry has it (integrator rule, YO-D14).
//
#if DEBUG
import SwiftUI

enum YouScreens: ScreenGroup {
    static let name = "you"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "YO-5", states: ["rest"]) { _ in
            AnyView(WhatIKnowLaunch())
        },
        LaunchableScreen(id: "YO-3", states: ["rest", "editing"]) { arguments in
            AnyView(SourceLaunch(editing: arguments.state == "editing"))
        },
    ]

    /// This build registers that screen id (a lookup, nothing built).
    static func has(_ id: String) -> Bool {
        ScreenRegistry.screen(id) != nil
    }

    /// Another group's screen by its launcher id, in its first state, when this build registers it.
    static func elsewhere(_ id: String) -> AnyView? {
        guard let screen = ScreenRegistry.screen(id), let state = screen.states.first else { return nil }
        return screen.build(LaunchArguments(screen: id, state: state))
    }
}

/// YO-3 on the sample, at its stack's root (YO-2 joins below it in V2.you.d).
private struct SourceLaunch: View {
    let editing: Bool
    @State private var data = SampleYou()
    @State private var navigator = YouNavigator(has: YouScreens.has, elsewhere: YouScreens.elsewhere)

    var body: some View {
        YouStack(data: data, navigator: navigator) {
            SourceScreen(sourceID: SampleYou.sleepEntry.id, data: data, navigator: navigator, editing: editing)
        }
    }
}

/// YO-5 on the sample.
private struct WhatIKnowLaunch: View {
    @State private var model = WhatIKnowModel(data: SampleYou())

    var body: some View {
        WhatIKnowPage(model: model, back: {})
    }
}
#endif
