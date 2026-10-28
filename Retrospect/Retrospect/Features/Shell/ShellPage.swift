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
//  A page ends at the bar's top (TABBAR.blend, founder 27 Oct: nothing is cut off by the bar): its
//  own bottom part (the journal's composer) sits above the bar, never under it, and the shell sets
//  every page's tab edge to RProgressiveBlurStyle.tabBarBlend (`\.rShellTabEdge`): over the 90 above
//  where the page's scroll ends, the content blurs (t², to blur.tab.max, colour kept) under canvas
//  easing in on gradient.fadeToCanvas to opaque, and the bar sits on the shell's canvas with no plate,
//  so content dissolves into the bar with no line, light and dark alike. Reduce
//  Transparency: the canvas fade alone (RProgressBlur); Reduce Motion: unchanged. While the keyboard
//  is up the bar steps aside (it never rides on the keys) and the composer sits on the keyboard as it
//  does in JR-1. A tab change cross-fades the page, edge included, over motion.duration.fast (Reduce
//  Motion: none); the bar plays haptic.tab for a tap.
//
//  G0b (plan-glue.md §1c; DISC L0-14, PCD-10): the sheet host and the mini-player are the shell's.
//  One RSheetHost wraps the pages AND the bar, so a sheet (an `AppSheet` from any page, or a page's
//  own `.rSheet`, whose host passes through here) covers the tab bar and the whole shell recedes
//  behind it (SCREEN-MAP §2). The mini-player, when the host gives one, floats space3 (12) above the
//  bar on the 24 margins on every tab (part 45; mini-player.md), stays put on a tab change, rises
//  space3 and fades in over motion.duration.slow (280, Reduce Motion: fade only) and steps aside with
//  the bar for the keyboard. Pages end above it, so it never covers their content.
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
    /// The sheet over the shell (G0b); one at a time, and only one whose page is built.
    private(set) var sheet: AppSheet?
    /// The last sheet presented, kept after it is dismissed so it doesn't vanish while it slides away.
    private(set) var presented: AppSheet?
    /// Counts presentations: each one is its own request to the sheet host.
    private(set) var presentation = 0

    /// Opens on `selection` if it has a page, else on the first tab that does (journal first).
    /// Whether a sheet has a page (the route table's answer; tests stand in for groups not built yet).
    private let sheetIsBuilt: (AppSheet) -> Bool

    init(
        selection: RTab = .journal,
        available: Set<RTab> = Set(RTab.allCases),
        sheetIsBuilt: ((AppSheet) -> Bool)? = nil
    ) {
        // the default is formed here, on the main actor (a default argument isn't)
        self.sheetIsBuilt = sheetIsBuilt ?? { AppRoutes.isBuilt($0) }
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

    /// Shows `sheet` over the shell (tab bar included). A sheet with nothing built, or a second sheet
    /// while one is up, is ignored (never two sheets at once).
    func present(_ sheet: AppSheet) {
        guard self.sheet == nil, sheetIsBuilt(sheet) else { return }
        self.sheet = sheet
        presented = sheet
        presentation += 1
    }

    /// Dismisses the sheet up, or only if it is still `presentation` (a late close never takes the next one).
    func dismissSheet(_ presentation: Int? = nil) {
        if let presentation, presentation != self.presentation {
            return
        }
        sheet = nil
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
    /// What's playing, floating above the bar on every tab (an RMiniPlayer); nil when nothing is loaded.
    var miniPlayer: AnyView?
    /// The page for a tab; nil when that tab has nothing built yet (the shell shows the canvas).
    let page: (RTab, ShellTabContext) -> AnyView?

    /// The keyboard is up: the bar steps aside so it never rides on the keys, and the page keeps the room.
    @State private var keyboardUp = false
    /// The mini-player's height, so the pages end above it.
    @State private var miniPlayerHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // one host over the pages and the bar: every sheet covers the tab bar (L0-14)
        RSheetHost {
            // the screen's bottom inset: the home indicator's, 0 on a phone with a home button (iPhone SE)
            GeometryReader { proxy in
                shell(bottomInset: proxy.safeAreaInsets.bottom)
            }
            // the shell's own request sits BESIDE the pages, not on them: a preference set on a view
            // replaces the ones its subtree sent, so on the pages it would hide every page's sheet
            // (the same reason AccountPage asks from a background). One request per presentation.
            .background {
                ShellSheetRequest(model: model, presentation: model.presentation)
                    .id(model.presentation)
            }
        }
    }

    private func shell(bottomInset: CGFloat) -> some View {
        // The pages, then the bar under them, with no plate and no background of its own: a page ends
        // at the bar's top (its own bottom part, the journal's composer, sits above the bar, and its
        // shadow falls over the bar as Paper draws it) and the page's tab edge is the shell's
        // `tabBarBlend` (TABBAR.blend): blur and canvas rising over blur.tabBlend.rise to opaque
        // exactly where the page ends, so content dissolves into the bar's canvas instead of being
        // cut by it. Nothing is drawn under the bar: what the band hides is gone.
        VStack(spacing: RDimension.space0) {
            pages
                .environment(\.rShellTabEdge, .tabBarBlend)
                .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast), value: model.selection)
                // the pages end above the mini-player: it never covers their content (mini-player.md rule)
                .safeAreaPadding(.bottom, floatingMiniPlayer == nil ? RDimension.space0 : miniPlayerHeight + RDimension.space3)
                .overlay(alignment: .bottom) {
                    if let floatingMiniPlayer {
                        floatingMiniPlayer
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { miniPlayerHeight = $0 }
                            .padding(.horizontal, RDimension.spaceScreenMargin)
                            .padding(.bottom, RDimension.space3)
                            .frame(maxWidth: .infinity)
                            // the player's room is opaque canvas: the page's edge ends opaque at the
                            // room's top and the player floats on the same canvas the bar sits on
                            .background(RColor.backgroundCanvas)
                            .transition(miniPlayerArrives)
                    }
                }
                .animation(RMotion.standard(RNumber.motionDurationSlow), value: floatingMiniPlayer == nil)
            if !keyboardUp {
                bar(bottomInset: bottomInset)
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

    /// The tabs' pages, every visited one kept and only the selected one shown.
    private var pages: some View {
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
                    // the shell's host draws the page's sheets (over the bar); pages present AppSheets here
                    .environment(\.rSheetHostAbove, true)
                    .appSheetPresent { model.present($0) }
                    .opacity(context.isShown ? 1 : 0)
                    .allowsHitTesting(context.isShown)
                    .accessibilityHidden(!context.isShown)
                }
            }
        }
    }

    /// The bar on the bottom safe area (Paper: the dock 32 above the screen edge), on the shell's
    /// canvas: the page's edge reaches full canvas at the bar's top, so the two meet with no line.
    private func bar(bottomInset: CGFloat) -> some View {
        RTabBar(
            selection: Binding(get: { model.selection }, set: { model.select($0) }),
            available: model.available
        ) { model.reselect($0) }
            .padding(.bottom, max(RDimension.space0, RDimension.space3 - bottomInset))
    }

    /// The mini-player while it may show: something is loaded and the keyboard is down.
    private var floatingMiniPlayer: AnyView? {
        keyboardUp ? nil : miniPlayer
    }

    /// Rises space3 and fades in (mini-player.md motion); Reduce Motion: the fade only.
    private var miniPlayerArrives: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: RDimension.space3))
    }
}

/// The shell's request for one presentation of an AppSheet. Keyed by the presentation, so a sheet asked
/// for while the last one slides away is a new request (the host opens it once the last has closed), and
/// the closing one keeps its own page and can only dismiss itself.
private struct ShellSheetRequest: View {
    let model: ShellModel
    let presentation: Int

    var body: some View {
        let sheet = model.presented
        Color.clear
            .rSheet(isPresented: shown, detent: sheet.map { AppRoutes.detent(for: $0) } ?? .full) {
                if let sheet {
                    AppRoutes.sheet(for: sheet, in: AppRouteContext(back: { model.dismissSheet(presentation) }))
                }
            }
    }

    private var shown: Binding<Bool> {
        Binding(get: { model.sheet != nil && model.presentation == presentation }, set: { isShown in
            if !isShown {
                model.dismissSheet(presentation)
            }
        })
    }
}
