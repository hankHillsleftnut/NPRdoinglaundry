//
//  YouScreens+Launcher.swift
//  V2 lane 3 (plan-v2.md §3): YO-1 you, YO-2 search, YO-3 a source, YO-4 a node, YO-5 what i know
//  about you, opened with `-Screen YO-<n> -State <state> -Data sample`. Dark: listed here and
//  nowhere in the release root.
//
//  V2.you.a: YO-5 `rest`. V2.you.b: YO-3 `rest`, `editing`. Until YO-1 and YO-2 are built (V2.you.c, d)
//  each page opens at its stack's root, so back has nowhere to go in the launcher (as the account page's
//  launcher). V2.you.c: YO-1 `rest` and YO-2 `found`, `nothing` (c:answer/abstained K24-0): the tab
//  page under a static tab bar (the shell joins in a wiring PR, integrator 26 Oct). Another group's screens
//  (a goal, settings) are not opened from here until the wiring PR (YO-D14).
//
#if DEBUG
import SwiftUI

enum YouScreens: ScreenGroup {
    static let name = "you"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "YO-1", states: ["rest"]) { _ in
            AnyView(YouTabLaunch(asking: nil))
        },
        LaunchableScreen(id: "YO-2", states: YouSearchState.allCases.map(\.rawValue)) { arguments in
            AnyView(YouTabLaunch(asking: YouSearchState(rawValue: arguments.state) ?? .found))
        },
        LaunchableScreen(id: "YO-5", states: ["rest"]) { _ in
            AnyView(WhatIKnowLaunch())
        },
        LaunchableScreen(id: "YO-3", states: ["rest", "editing"]) { arguments in
            AnyView(SourceLaunch(editing: arguments.state == "editing"))
        },
    ]
}

/// YO-2's launcher states.
enum YouSearchState: String, CaseIterable {
    case found, nothing
}

/// The You tab on the sample: the page under a static tab bar (you selected; the other tabs are drawn
/// but this frame has no other page, integrator 26 Oct), inside the You stack so pushes cover the bar.
private struct YouTabLaunch: View {
    let asking: YouSearchState?
    @State private var data = SampleYou()
    @State private var navigator = YouNavigator()
    @State private var model: YouModel?

    var body: some View {
        YouStack(data: data, navigator: navigator) {
            GeometryReader { proxy in
                VStack(spacing: RDimension.space0) {
                    if let model {
                        YouPage(model: model, navigator: navigator)
                    } else {
                        RColor.backgroundCanvas.task { model = await prepared() }
                    }
                    // as the shell: on the home indicator's inset, or 12 above the edge on a phone without one
                    RTabBar(selection: .constant(.you))
                        .padding(.bottom, max(RDimension.space0, RDimension.space3 - proxy.safeAreaInsets.bottom))
                }
            }
            .background(RColor.backgroundCanvas.ignoresSafeArea())
        }
    }

    private func prepared() async -> YouModel {
        let model = YouModel(data: data)
        guard let asking else { return model }
        model.query = asking == .nothing ? SampleYou.unansweredQuestion : SampleYou.sleepQuestion
        await model.ask()
        return model
    }
}

/// YO-3 on the sample, at its stack's root (YO-2 joins below it in V2.you.d).
private struct SourceLaunch: View {
    let editing: Bool
    @State private var data = SampleYou()
    @State private var navigator = YouNavigator()

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
