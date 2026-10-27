//
//  OutsideScreens+Launcher.swift
//  V2 lane 5 (plan-v2.md §3): the views of EX-1 share, EX-2 lock screen, EX-3 notifications, EX-4
//  widgets (the views only; the extension targets wait on the founder's entitlements), opened with
//  `-Screen EX-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//
//  EX-1 `ready` / `typed`: the share sheet's content over the scrim, standing in for the system's
//  share presentation (the real one is the extension's). `typed` has your why filled in. Cancel and
//  save close it; a quiet line says which, as the core launch stand-ins do.
//  EX-4 `rest`: both widgets at their system sizes on the page colour (the views a widget target will show).
//  EX-2 and EX-3 are drawn by the system: their content is code with tests, not a launcher screen.
//
#if DEBUG
import SwiftUI

enum OutsideScreens: ScreenGroup {
    static let name = "outside the app"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "EX-1", states: ["ready", "typed"]) { arguments in
            AnyView(ShareLaunch(why: arguments.state == "typed" ? "for the raise, the bit on angels" : ""))
        },
        LaunchableScreen(id: "EX-4", states: ["rest"]) { _ in
            AnyView(WidgetsPreviewPage())
        },
    ]
}

/// EX-1 over the scrim, on the sample.
struct ShareLaunch: View {
    @State private var model: ShareModel

    /// Paper 1H1M-0: the system share sheet starts 28 under the status bar (the app behind shows in that strip).
    private static let sheetTop = RDimension.space6 + RDimension.space1

    init(why: String) {
        _model = State(initialValue: ShareModel(data: SampleShare(), why: why))
    }

    var body: some View {
        if case let .closed(saved) = model.state {
            Text(saved ? "saved (sample: nothing was sent)" : "share cancelled")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas.ignoresSafeArea())
                .accessibilityIdentifier("share.closed")
        } else {
            ZStack(alignment: .top) {
                RColor.backgroundScrim.ignoresSafeArea()
                // the sheet's paper runs under the home indicator; its content stays above it
                RShape.top(RDimension.radiusSheet)
                    .fill(RColor.backgroundCanvas)
                    .padding(.top, Self.sheetTop)
                    .ignoresSafeArea(.container, edges: .bottom)
                SharePage(model: model)
                    .padding(.top, Self.sheetTop)
            }
            .background(RColor.backgroundCanvas.ignoresSafeArea())
        }
    }
}
#endif
