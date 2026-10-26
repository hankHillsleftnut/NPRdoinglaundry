//
//  ShellPage.swift
//  V2 lane 0 · the app shell, built dark (plan-v2.md §1): the four places under the tab bar (RTabBar;
//  Paper 02 · components B18-0, and every tab screen's dock on p-J-0: JR-1, PC-1 1FSA-0, GL-1 1FZR-0,
//  YO-1 1G61-0). The shell owns which tab is showing and keeps each tab's page alive while another is
//  up (state kept, SCREEN-MAP §3.2 row 71); each page owns its own top bar, scroll edge and blur.
//
//  It is reachable only from the launcher (`-Screen shell -State tabs -Data sample`): mounting it in
//  the app root is a founder-approved wiring PR, and ReleaseRouteTableTests fences this folder.
//  What each tab shows is passed in, so the shell never names a screen: today the launcher gives it
//  JR-1 on sample data and nothing for the tabs not built yet (no placeholder pages). The drawer (JR-3)
//  is lane 1's: until it is built the journal's drawer button stays as JR-1 has it.
//
//  Layout: the bar sits on the bottom safe area (Paper: the dock 32 above the screen edge, which is the
//  home indicator), so a page's own bottom inset (the journal's composer) rises above it; the page under
//  the bar is opaque canvas (build notes, podcasts bottom edge). A tab change cross-fades the page over
//  motion.duration.fast (tab-bar.md "change"; Reduce Motion: no fade) and plays haptic.tab (RTabBar).
//
import SwiftUI

/// Which tab is up, and the "tapped again" signal a page can follow to scroll to its top.
@Observable
@MainActor
final class ShellModel {
    var selection: RTab
    /// Counts re-taps of the selected tab, per tab (tab-bar.md rule 4).
    private(set) var reselects: [RTab: Int] = [:]

    init(selection: RTab = .journal) {
        self.selection = selection
    }

    func reselect(_ tab: RTab) {
        reselects[tab, default: 0] += 1
    }
}

struct ShellPage: View {
    @Bindable var model: ShellModel
    /// The page for a tab; nil when that tab has nothing built yet (the shell shows the canvas).
    let page: (RTab) -> AnyView?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RColor.backgroundCanvas.ignoresSafeArea()
            // every built page stays mounted, so switching back keeps its scroll and its words
            ForEach(RTab.allCases) { tab in
                let shown = tab == model.selection
                Group {
                    if let view = page(tab) {
                        view
                    } else {
                        RColor.backgroundCanvas
                    }
                }
                .opacity(shown ? 1 : 0)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
            }
        }
        .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast), value: model.selection)
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) {
            RTabBar(selection: $model.selection) { model.reselect($0) }
                .background(RColor.backgroundCanvas.ignoresSafeArea(edges: .bottom))
        }
        .accessibilityIdentifier("shell")
    }
}
