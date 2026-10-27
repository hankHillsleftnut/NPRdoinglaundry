//
//  RTopBar.swift
//  M14 C17: the top bar (Paper "c · top bar" B19-0; instances JR-1 1FM0-0, JR-3 1FPD-0,
//  JR-4 1FRR-0, ST-1 1GJ1-0; collapsed B5B-0; editing G8L-0). A 44 bar under the status bar,
//  16 in from the sides, 8 between parts, no background of its own (the page draws its edge).
//  The journal's inky title shrinks into a small centred name once the page scrolls or the
//  composer is focused; the page decides that and passes `collapsed`.
//
//  V2 lane 0 · components gap #2: `.title`, the tab pages' bar (c:top-bar/title/rest on PC-1 FZM-0,
//  GL-1 1G3J-0, YO-1 1G7X-0, the 02 · components variant H0D-0): no leading button, the inky title from
//  the screen margin (24), and an optional trailing slot. Paper's insets follow the trailing part: none
//  or a 44 icon button keep 16 on the trailing side (the button's 36 sits 20 in, like the drawer
//  button opposite); 36-tall content (YO-1's "list" pill and picture, 12 apart) sits 24 in.
//
//  V2.goals.parts (GL-D9): `.entry(.back(back:))`, the entry bar with back only, for pages whose "edit" has
//  nothing drawn behind it yet (GL-2's rename mode). The same bar as `.rest` without the word.
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
        /// Tab pages (podcasts, goals, you): the inky title with no leading button, and a trailing part.
        case title(title: String, trailing: TitleTrailing)
    }

    /// What sits at a tab page's trailing edge (Paper draws three).
    enum TitleTrailing {
        /// PC-1: nothing.
        case none
        /// GL-1: one wash icon button in its 44 frame ("+", add).
        case iconButton(symbol: String, label: String, action: () -> Void)
        /// YO-1: 36-tall parts the page builds ("list", the picture), laid 12 apart by the bar, 24 from the edge.
        case content([AnyView])
    }

    enum Entry {
        case rest(back: () -> Void, edit: () -> Void)
        /// Back only: "edit" has no drawn destination yet (GL-2), so it isn't there at all.
        case back(back: () -> Void)
        /// "cancel · edit this entry · save"; save is plain ink, dimmed until there's a change.
        case editing(canSave: Bool, cancel: () -> Void, save: () -> Void)
    }

    let variant: Variant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: RDimension.sizeNavBar)
            .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.snappy, value: isCollapsed)
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
            .rBlurReplace()
        case let .entry(.back(back)):
            HStack(spacing: RDimension.space2) {
                backButton(back)
                Spacer(minLength: RDimension.space0)
            }
            .padding(.horizontal, RDimension.space4)
            .rBlurReplace()
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
            .rBlurReplace()
        case let .title(title, trailing):
            HStack(spacing: RDimension.space2) {
                Text(title)
                    .rText(.inkTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                titleTrailing(trailing)
            }
            .padding(.leading, RDimension.spaceScreenMargin)
            .padding(.trailing, Self.trailingInset(trailing))
        }
    }

    @ViewBuilder private func titleTrailing(_ trailing: TitleTrailing) -> some View {
        switch trailing {
        case .none:
            EmptyView()
        case let .iconButton(symbol, label, action):
            RIconButton(symbol: symbol, label: label, action: action)
        case let .content(parts):
            HStack(spacing: RDimension.space3) {
                ForEach(parts.indices, id: \.self) { parts[$0] }
            }
        }
    }

    /// 16 beside nothing or a 44-framed button; 24 beside 36-tall content (FZM-0, 1G3J-0, 1G7X-0).
    static func trailingInset(_ trailing: TitleTrailing) -> CGFloat {
        switch trailing {
        case .none, .iconButton: RDimension.space4
        case .content: RDimension.spaceScreenMargin
        }
    }

    /// The small centred name; Increase Contrast lifts it to text.primary.
    private func smallTitle(_ title: String) -> some View {
        RBarSmallTitle(title: title)
    }

    private func drawerButton(_ action: @escaping () -> Void) -> some View {
        RIconButton(symbol: "sidebar.left", label: "all journals", action: action)
    }

    /// The back chevron at Paper's size, the same 11.3pt glyph as onboarding's back (ST-1 1GJ7-0, JR-4 1FRX-0
    /// and ON-6 21CA-0 draw one path in a 20 frame; founder, 27 Oct). Only the circle differs: 36 here.
    static let backGlyphScale = RIconButton.backChevronGlyphScale

    /// The bar's back button: the top-bar circle with the chevron at `backGlyphScale`.
    static func back(_ action: @escaping () -> Void) -> RIconButton {
        RIconButton(symbol: "chevron.left", label: "back", glyphScale: backGlyphScale, action: action)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Self.back(action)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How much smaller the small name is than the inky title, at the sizes they're drawn at now.
    private var ratio: CGFloat {
        RTextStyle.barTitle.scaledSize(at: dynamicTypeSize) / RTextStyle.inkTitle.scaledSize(at: dynamicTypeSize)
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
                // collapsed, the hidden title gives up its height, so the bar is the small name's
                // (it matters at large text sizes); the bar's spring animates it with the move
                .frame(height: collapsed ? RDimension.space0 : nil)
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
            .frame(minWidth: RDimension.sizeTouchTarget, minHeight: RDimension.sizeTouchTarget)
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
                section("entry · back only") { RTopBar(variant: .entry(.back {})) }
                section("entry · editing, changed") {
                    RTopBar(variant: .entry(.editing(canSave: true, cancel: {}, save: {})))
                }
                section("title · podcasts") { RTopBar(variant: .title(title: "podcasts", trailing: .none)) }
                section("title · goals, add") {
                    RTopBar(variant: .title(title: "goals", trailing: .iconButton(symbol: "plus", label: "add a goal") {}))
                }
                section("title · you, content") {
                    RTopBar(variant: .title(title: "you", trailing: .content([
                        AnyView(RPill(title: "list", style: .neutral) {}),
                        // stands in for YO-1's 36 picture (1G80-0) so the gap and inset show
                        AnyView(Circle().fill(RColor.surfaceWash)
                            .frame(width: RDimension.sizeControlIcon, height: RDimension.sizeControlIcon)
                            .accessibilityHidden(true)),
                    ])))
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
