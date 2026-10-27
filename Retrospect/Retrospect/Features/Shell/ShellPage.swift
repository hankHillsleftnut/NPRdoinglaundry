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
//  JR-1 on sample data. Only the tabs that have a page are live: the others are drawn in the bar but
//  inert (no selection, no haptic, "not built yet" to VoiceOver), so there is never a blank page.
//  The drawer (JR-3) is lane 1's: until it is built the journal's drawer button opens the account page,
//  as it does in the app today.
//
//  Layout: the pages, then the bar on the bottom safe area (Paper: the dock 32 above the screen edge,
//  which is the home indicator). A phone with no home indicator (iPhone SE: a bottom inset of 0) keeps
//  space3 (12) under the bar instead of ending flush at the edge: compact, not Paper's 32 (logged).
//  A page ends at the bar's top, so its bottom parts (the journal's composer, which its sheet host
//  lets reach into the safe area) sit above the bar, never under it. While the keyboard is up the bar
//  steps aside (it never rides on the keys) and the composer sits on the keyboard as it does in JR-1.
//  The strip under the bar is opaque canvas (build notes, podcasts bottom edge). A tab change cross-fades
//  the page over motion.duration.fast (Reduce Motion: none); the bar plays haptic.tab for a tap.
//
import SwiftUI
import UIKit

/// Which tab is up, which tabs have been opened, and the "tapped again" counts.
@Observable
@MainActor
final class ShellModel {
    /// Changed only through `select(_:)`, which ignores a tab with no page.
    private(set) var selection: RTab {
        didSet { visited.insert(selection) }
    }

    /// The tabs that have a page; the bar shows the rest as inert.
    let available: Set<RTab>
    /// Tabs shown at least once: their pages are built and kept.
    private(set) var visited: Set<RTab>
    /// Counts re-taps of the selected tab, per tab (tab-bar.md rule 4).
    private(set) var reselects: [RTab: Int] = [:]

    /// Opens on `selection` if it has a page, else on the first tab that does (journal first).
    init(selection: RTab = .journal, available: Set<RTab> = Set(RTab.allCases)) {
        let start = available.contains(selection) ? selection : RTab.allCases.first(where: available.contains) ?? selection
        self.available = available
        self.selection = start
        visited = [start]
    }

    /// Shows `tab`, if it has a page. A tab with nothing built leaves the selection as it is.
    func select(_ tab: RTab) {
        guard available.contains(tab) else { return }
        selection = tab
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
/// tapped again (scroll to the top when it changes). A page gets it in its builder and, for any view
/// inside it, in the environment (`\.shellTab`). A kept page that isn't shown is still mounted
/// (opacity 0): a page that plays, polls or animates pauses on `isShown == false`.
struct ShellTabContext: Equatable {
    var isShown: Bool
    var reselects: Int
}

extension EnvironmentValues {
    /// The shell's word to the page this view is in. Outside the shell: shown, never re-tapped.
    @Entry var shellTab = ShellTabContext(isShown: true, reselects: 0)
}

struct ShellPage: View {
    @Bindable var model: ShellModel
    /// The page for a tab; nil when that tab has nothing built yet (the shell shows the canvas).
    let page: (RTab, ShellTabContext) -> AnyView?

    /// The keyboard is up: the bar steps aside so it never rides on the keys, and the page keeps the room.
    @State private var keyboardUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // the screen's bottom inset: the home indicator's, 0 on a phone with a home button (iPhone SE)
        GeometryReader { proxy in
            shell(bottomInset: proxy.safeAreaInsets.bottom)
        }
    }

    private func shell(bottomInset: CGFloat) -> some View {
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
                        .environment(\.shellTab, context)
                        .opacity(context.isShown ? 1 : 0)
                        .allowsHitTesting(context.isShown)
                        .accessibilityHidden(!context.isShown)
                    }
                }
            }
            .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast), value: model.selection)
            if !keyboardUp {
                RTabBar(
                    selection: Binding(get: { model.selection }, set: { model.select($0) }),
                    available: model.available
                ) { model.reselect($0) }
                    .padding(.bottom, max(RDimension.space0, RDimension.space3 - bottomInset))
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
