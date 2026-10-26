//
//  ShellPage.swift
//  V2 lane 0 · the app shell, built dark (plan-v2.md §1): the four places under the tab bar (RTabBar;
//  Paper 02 · components B18-0, and every tab screen's dock on p-J-0: JR-1, PC-1 1FSA-0, GL-1 1FZR-0,
//  YO-1 1G61-0). The shell owns which tab is showing. A tab's page is built the first time it is shown
//  and then stays mounted, so switching back keeps its scroll and its words (SCREEN-MAP §3.2 row 71);
//  each page is told whether it is the one showing and how often its tab was tapped again, so it can
//  pause what only matters on screen and scroll to its top. Each page owns its top bar, edge and blur.
//
//  It is reachable only from the launcher (`-Screen shell -State tabs -Data sample`): mounting it in
//  the app root is a founder-approved wiring PR, and ReleaseRouteTableTests fences this folder.
//  What each tab shows is passed in, so the shell never names a screen: today the launcher gives it
//  JR-1 on sample data and nothing for the tabs not built yet (no placeholder pages). The drawer (JR-3)
//  is lane 1's: until it is built the journal's drawer button stays as JR-1 has it.
//
//  Layout: the pages, then the bar on the bottom safe area (Paper: the dock 32 above the screen edge,
//  which is the home indicator). A page ends at the bar's top, so its bottom parts (the journal's
//  composer, which its sheet host lets reach into the safe area) sit above the bar, never under it.
//  While the keyboard is up the bar steps aside (it never rides on the keys) and the composer sits on
//  the keyboard as it does in JR-1. The
//  strip under the bar is opaque canvas (build notes, podcasts bottom edge). A tab change cross-fades
//  the page over motion.duration.fast (Reduce Motion: none); the bar plays haptic.tab for a tap.
//
import SwiftUI
import UIKit

/// Which tab is up, which tabs have been opened, and the "tapped again" counts.
@Observable
@MainActor
final class ShellModel {
    var selection: RTab {
        didSet { visited.insert(selection) }
    }

    /// Tabs shown at least once: their pages are built and kept.
    private(set) var visited: Set<RTab>
    /// Counts re-taps of the selected tab, per tab (tab-bar.md rule 4).
    private(set) var reselects: [RTab: Int] = [:]

    init(selection: RTab = .journal) {
        self.selection = selection
        visited = [selection]
    }

    func reselect(_ tab: RTab) {
        reselects[tab, default: 0] += 1
    }

    /// What a tab's page is told.
    func context(for tab: RTab) -> ShellTabContext {
        ShellTabContext(isShown: tab == selection, reselects: reselects[tab, default: 0])
    }
}

/// What the shell tells a tab's page: whether it is the one on screen, and how many times its tab was
/// tapped again (scroll to the top when it changes).
struct ShellTabContext: Equatable {
    var isShown: Bool
    var reselects: Int
}

struct ShellPage: View {
    @Bindable var model: ShellModel
    /// The page for a tab; nil when that tab has nothing built yet (the shell shows the canvas).
    let page: (RTab, ShellTabContext) -> AnyView?

    /// The keyboard is up: the bar steps aside so it never rides on the keys, and the page keeps the room.
    @State private var keyboardUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // the pages, then the bar under them: a page that reaches into the bottom safe area (the
        // journal's sheet host does) stops at the bar instead of sliding under it
        VStack(spacing: RDimension.space0) {
            ZStack {
                ForEach(RTab.allCases) { tab in
                    if model.visited.contains(tab) {
                        let context = model.context(for: tab)
                        Group {
                            if let view = page(tab, context) {
                                view
                            } else {
                                RColor.backgroundCanvas
                            }
                        }
                        .opacity(context.isShown ? 1 : 0)
                        .allowsHitTesting(context.isShown)
                        .accessibilityHidden(!context.isShown)
                    }
                }
            }
            .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast), value: model.selection)
            if !keyboardUp {
                RTabBar(selection: $model.selection) { model.reselect($0) }
            }
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        .accessibilityIdentifier("shell")
    }
}
