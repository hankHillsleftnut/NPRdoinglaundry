//
//  RTabBar.swift
//  V2 lane 0 · components gap #1: the tab bar (Paper 02 · components, "c · tab bar" B18-0, master
//  c:tab-bar/system/rest B3X-0; items c:tab-bar/item/selected B4A-0 and /rest B46-0, B42-0, B3Y-0;
//  spec components/tab-bar.md, approved 20 Oct, version A). The four places: journal · podcasts ·
//  goals · you. No plate and no line: the page's own progressive blur (`.rProgressiveBlur(.tabEdge)`)
//  and canvas tint sit under it, so this view is only the slots.
//
//  Paper, 1:1: four slots of 72 × 48 (`size.tabItemWidth/Height`), 12 apart (`space3`), centred; each a
//  22 icon (`size.tabIcon`) over a Geist 11 label (`.tab` / `.tabSelected`: text-xs, tracking-label,
//  leading-snug), 2 apart (`size.borderRing`). Selected: icon and label `text.primary`, label medium,
//  icon at the emphasis weight. Rest: icon `icon.muted`, label `text.label`, regular. Selection is
//  weight, never colour (rule 3). The dock sits 32 above the screen's bottom edge in Paper (B3W-0),
//  which is the home-indicator inset: the host places the bar on the bottom safe area.
//
//  Icons: SF Symbols (founder, 21 Oct: Apple's symbols for every icon) standing in for Paper's inked
//  glyphs; logged as discrepancy L0-10. Pressed dims to opacity.pressed at once and back in 240ms; a
//  change plays haptic.tab; tapping the selected tab again asks the page to scroll to the top (rule 4).
//  On a small phone the slots share the width down to 64 (`size.tabItemMinWidth`); at accessibility
//  sizes the labels hide and a long press shows the large-content viewer (iOS behaviour).
//
import SwiftUI

/// The four places, in the bar's order.
enum RTab: String, CaseIterable, Identifiable, Sendable {
    case journal, podcasts, goals, you

    var id: String {
        rawValue
    }

    /// The label (lowercase, key 2).
    var title: String {
        rawValue
    }

    /// The SF Symbol standing in for Paper's glyph (B4C-0, B48-0, B44-0, B40-0).
    var symbol: String {
        switch self {
        case .journal: "text.page"
        case .podcasts: "dot.radiowaves.left.and.right"
        case .goals: "target"
        case .you: "point.3.connected.trianglepath.dotted"
        }
    }
}

struct RTabBar: View {
    @Binding var selection: RTab
    /// The selected tab was tapped again: its page scrolls to the top.
    var reselect: (RTab) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: RDimension.space3) {
            ForEach(RTab.allCases) { tab in
                Button {
                    choose(tab)
                } label: {
                    RTabBarItem(tab: tab, selected: tab == selection, showsLabel: !typeSize.isAccessibilitySize)
                }
                .buttonStyle(RTabPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selection ? [.isSelected] : [])
                .accessibilityShowsLargeContentViewer {
                    Label(tab.title, systemImage: tab.symbol)
                }
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        // centred like the system bar (B3W-0: justify-content center)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(RHaptic.tab, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    private func choose(_ tab: RTab) {
        guard tab != selection else {
            reselect(tab)
            return
        }
        withAnimation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast)) {
            selection = tab
        }
    }
}

/// One slot: the icon over its label, the pair centred in 72 × 48 (Paper's flex centring).
private struct RTabBarItem: View {
    let tab: RTab
    let selected: Bool
    let showsLabel: Bool

    var body: some View {
        VStack(spacing: RDimension.sizeBorderRing) {
            RSymbol(
                name: tab.symbol,
                size: .tab,
                tint: selected ? RColor.textPrimary : RColor.iconMuted,
                // the emphasis outline (2.2 against 1.75) as the symbol's next weight up
                weight: selected ? .semibold : .regular
            )
            if showsLabel {
                Text(tab.title)
                    .rText(selected ? .tabSelected : .tab)
                    .foregroundStyle(selected ? RColor.textPrimary : RColor.textLabel)
                    .lineLimit(1)
            }
        }
        // shares the width on a small phone, never below 64; 48 tall (a 44 target and then some)
        .frame(minWidth: RDimension.sizeTabItemMinWidth, maxWidth: RDimension.sizeTabItemWidth)
        .frame(minHeight: RDimension.sizeTabItemHeight)
        .contentShape(Rectangle())
    }
}

/// Pressed: the slot dims to opacity.pressed at once, and comes back over 240ms.
private struct RTabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                configuration.isPressed ? nil : RMotion.standard(RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
/// Lab page "tabbar": the master (journal selected) on Paper's bottom-240 phone crop, each tab
/// selected in turn, and a live bar to tap (the "again" count shows a reselect).
struct RTabBarGallery: View {
    @State private var live = RTab.journal
    @State private var reselects = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                Text("tab bar · master").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RTabBar(selection: .constant(.journal))
                Text("each selected").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                ForEach(RTab.allCases) { tab in
                    RTabBar(selection: .constant(tab))
                }
                Text("live · tapped again \(reselects)×").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RTabBar(selection: $live) { _ in reselects += 1 }
            }
            .padding(.vertical, RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("tab bar") { RTabBarGallery() }
#endif
