//
//  RTopBar.swift
//  M14 C17: the top bar (Paper "c · top bar" B19-0; instances JR-1 1FM0-0, JR-3 1FPD-0,
//  JR-4 1FRR-0, ST-1 1GJ1-0; collapsed B5B-0; editing G8L-0). A 44 bar under the status bar,
//  16 in from the sides, 8 between parts, no background of its own (the page draws its edge).
//  The journal's inky title shrinks into a small centred name once the page scrolls or the
//  composer is focused; the page decides that and passes `collapsed`.
//
import SwiftUI

extension RTextStyle {
    /// The small centred name (settings, the drawer, the journal collapsed): Geist 14 medium,
    /// --tracking-label, 18 line (B5B-0, 1GJ1-0).
    static let barTitle = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: RTextStyle.textMd.leading,
        relativeTo: .subheadline
    )

    /// "cancel · edit this entry · save": Geist 14 medium, leading snug, no tracking (G8L-0).
    static let barEditing = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.textMd.leading,
        relativeTo: .subheadline
    )
}

struct RTopBar: View {
    enum Variant {
        /// JR-1: the drawer button, then the inky title; collapsed, a small centred name.
        case journal(title: String, collapsed: Bool, openDrawer: () -> Void)
        /// JR-3: the drawer button and a small centred name.
        case label(title: String, openDrawer: () -> Void)
        /// Settings pages: back and a small centred name.
        case settings(title: String, back: () -> Void)
        /// JR-4 (and other single-item pages): back and a trailing action; never a title.
        case entry(Entry)
    }

    enum Entry {
        case rest(back: () -> Void, edit: () -> Void)
        /// "cancel · edit this entry · save"; save is plain ink, dimmed until there's a change.
        case editing(canSave: Bool, cancel: () -> Void, save: () -> Void)
    }

    let variant: Variant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: RDimension.sizeNavBar)
            .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy, value: isCollapsed)
            .animation(RMotion.standard(RNumber.motionDurationBase), value: isEditing)
    }

    @ViewBuilder private var content: some View {
        switch variant {
        case let .journal(title, collapsed, openDrawer):
            HStack(spacing: RDimension.space2) {
                drawerButton(openDrawer)
                RJournalTitle(title: title, collapsed: collapsed)
            }
            .padding(.horizontal, RDimension.space4)
        case let .label(title, openDrawer):
            HStack(spacing: RDimension.space2) {
                drawerButton(openDrawer)
                smallTitle(title)
                keylineSpacer
            }
            .padding(.horizontal, RDimension.space4)
        case let .settings(title, back):
            HStack(spacing: RDimension.space2) {
                backButton(back)
                smallTitle(title)
                keylineSpacer
            }
            .padding(.horizontal, RDimension.space4)
        case let .entry(.rest(back, edit)):
            HStack(spacing: RDimension.space2) {
                backButton(back)
                Spacer(minLength: RDimension.space0)
                Button("edit", action: edit)
                    .buttonStyle(RBarTextStyle(style: .barTitle, color: RColor.textPrimary))
                    .padding(.horizontal, RDimension.space2)
            }
            .padding(.horizontal, RDimension.space4)
            .transition(.blurReplace)
        case let .entry(.editing(canSave, cancel, save)):
            HStack(spacing: RDimension.space2) {
                Button("cancel", action: cancel)
                    .buttonStyle(RBarTextStyle(style: .barEditing, color: RColor.textSecondary))
                Spacer(minLength: RDimension.space0)
                Text("edit this entry")
                    .rText(.barEditing)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: RDimension.space0)
                Button("save", action: save)
                    .buttonStyle(RBarTextStyle(style: .barEditing, color: canSave ? RColor.textPrimary : RColor.textTertiary))
                    .disabled(!canSave)
                    .animation(RMotion.standard(RNumber.motionDurationFast), value: canSave)
            }
            .padding(.horizontal, RDimension.space6)
            .transition(.blurReplace)
        }
    }

    /// The small centred name; Increase Contrast lifts it to text.primary.
    private func smallTitle(_ title: String) -> some View {
        RBarSmallTitle(title: title)
    }

    private func drawerButton(_ action: @escaping () -> Void) -> some View {
        RIconButton(symbol: "sidebar.left", label: "all journals", action: action)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        RIconButton(symbol: "chevron.left", label: "back", action: action)
    }

    /// The 44 slot opposite the leading button, so the centred name sits on the bar's centre.
    private var keylineSpacer: some View {
        Color.clear
            .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
            .accessibilityHidden(true)
    }

    private var isCollapsed: Bool {
        if case let .journal(_, collapsed, _) = variant {
            return collapsed
        }
        return false
    }

    private var isEditing: Bool {
        if case .entry(.editing) = variant {
            return true
        }
        return false
    }
}

/// The journal's title in both places at once: the inky title at the leading edge and the small
/// name on the bar's centre. Collapsing moves the inky one to the centre while it shrinks to the
/// small size and fades, and the small one grows out of where the inky one was: one move, on the
/// bar's spring, so a change mid-move retargets from wherever it is. Reduce Motion: a cross-fade.
private struct RJournalTitle: View {
    let title: String
    let collapsed: Bool

    @State private var largeCenter: CGPoint = .zero
    @State private var smallCenter: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How much smaller the small name is than the inky title (from their two text sizes).
    private var ratio: CGFloat {
        RTextStyle.barTitle.size / RTextStyle.inkTitle.size
    }

    private var travel: CGSize {
        reduceMotion ? .zero : CGSize(width: smallCenter.x - largeCenter.x, height: smallCenter.y - largeCenter.y)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(title)
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(2)
                .scaleEffect(collapsed && !reduceMotion ? ratio : 1)
                .offset(collapsed ? travel : .zero)
                .background { center { largeCenter = $0 } }
                .opacity(collapsed ? 0 : 1)
                .accessibilityHidden(collapsed)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            // the small name sits on the bar's centre: the same 44 slot is kept on the right
            HStack(spacing: RDimension.space2) {
                RBarSmallTitle(title: title)
                    .scaleEffect(collapsed || reduceMotion ? 1 : 1 / ratio)
                    .offset(collapsed ? .zero : CGSize(width: -travel.width, height: -travel.height))
                    .background { center { smallCenter = $0 } }
                    .opacity(collapsed ? 1 : 0)
                    .accessibilityHidden(!collapsed)
                Color.clear
                    .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                    .accessibilityHidden(true)
            }
        }
        .coordinateSpace(.named(RJournalTitle.space))
    }

    /// Reads a title's resting centre. It sits in a background attached after the scale and
    /// offset, so it measures where the title lays out, never where it's drawn mid-move (measuring
    /// the moved title fed its own offset back into itself and never settled).
    private func center(_ update: @escaping (CGPoint) -> Void) -> some View {
        Color.clear.onGeometryChange(for: CGPoint.self) { geo in
            let frame = geo.frame(in: .named(RJournalTitle.space))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { update($0) }
    }

    private static let space = "rJournalTitle"
}

private struct RBarSmallTitle: View {
    let title: String
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(title)
            .rText(.barTitle)
            .foregroundStyle(contrast == .increased ? RColor.textPrimary : RColor.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Words-only bar buttons ("edit", "cancel", "save"): the words dim to opacity.pressed while
/// held, in 80 and out over 240. A 44 hit area at every size.
private struct RBarTextStyle: ButtonStyle {
    let style: RTextStyle
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rText(style)
            .foregroundStyle(color)
            .lineLimit(1)
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
    }
}

#if DEBUG
/// Lab page "topbar": every variant at rest, and the journal bar collapsing over a thread.
/// `-DesignLabAutoplay` collapses and expands it (once mid-move), and toggles editing.
struct RTopBarGallery: View {
    @State private var collapsed = false
    @State private var editing = false
    @State private var changed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                section("journal · rest") { RTopBar(variant: .journal(title: "journal", collapsed: false) {}) }
                section("journal · collapsed") { RTopBar(variant: .journal(title: "journal", collapsed: true) {}) }
                section("journal · live") {
                    RTopBar(variant: .journal(title: "journal", collapsed: collapsed) {})
                    RPill(title: collapsed ? "back to the top" : "scroll", style: .raised) { collapsed.toggle() }
                        .padding(.horizontal, RDimension.space4)
                }
                section("drawer · label") { RTopBar(variant: .label(title: "journal") {}) }
                section("settings") { RTopBar(variant: .settings(title: "settings") {}) }
                section("entry · live") {
                    RTopBar(variant: .entry(editing
                            ? .editing(canSave: changed, cancel: { editing = false }, save: { editing = false })
                            : .rest(back: {}, edit: { editing = true })))
                }
                section("entry · editing, changed") {
                    RTopBar(variant: .entry(.editing(canSave: true, cancel: {}, save: {})))
                }
            }
            .padding(.vertical, RDimension.space6)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            // the third change lands mid-move, to show it retargets without a jump
            for (pause, step) in [(2.0, 0), (2.0, 0), (0.12, 0), (2.0, 1), (2.0, 2), (2.0, 1)] {
                do { try await Task.sleep(for: .seconds(pause)) } catch { return }
                switch step {
                case 0: collapsed.toggle()
                case 1: editing.toggle()
                default: changed.toggle()
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            Text(title).rText(.label).foregroundStyle(RColor.textLabel)
                .padding(.horizontal, RDimension.spaceScreenMargin)
            content()
        }
    }
}

#Preview("top bar") { RTopBarGallery() }
#endif
