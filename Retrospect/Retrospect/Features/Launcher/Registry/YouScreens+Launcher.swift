//
//  YouScreens+Launcher.swift
//  V2 lane 3 (plan-v2.md §3): YO-1 you, YO-2 search, YO-3 a source, YO-4 a node, YO-5 what i know
//  about you, opened with `-Screen YO-<n> -State <state> -Data sample`. Dark: listed here and
//  nowhere in the release root.
//
//  V2.you.a: YO-5 `rest`. Until YO-1 is built (V2.you.c) the page opens on its own and back has
//  nowhere to go in the launcher (the account page's launcher does the same).
//
#if DEBUG
import SwiftUI

enum YouScreens: ScreenGroup {
    static let name = "you"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "YO-5", states: ["rest"]) { _ in
            AnyView(WhatIKnowLaunch())
        },
    ]
}

/// YO-5 on the sample.
private struct WhatIKnowLaunch: View {
    @State private var model = WhatIKnowModel(data: SampleYou())

    var body: some View {
        WhatIKnowPage(model: model, back: {})
    }
}
#endif
