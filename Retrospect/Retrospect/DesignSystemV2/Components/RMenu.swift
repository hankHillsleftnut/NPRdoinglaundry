//
//  RMenu.swift
//  M14 C20: the menu (design-system/components/title-menu.md, reference §C20; the legacy
//  filmstrip "c4 · title menu" 102-0 for the measured choreography, and part 08's long-press
//  state C3A-0 for the message menu). Choices grow out of the thing you touched: the source
//  dims to opacity.sourcePressed over motion.duration.sourceDim, then the panel appears at
//  motion.scale.popoverFrom with motion.blur.enter and grows on motion.spring.popover,
//  sharpening, while a veil (background.veil) settles over the page; `select` on settle.
//  Choosing slides the wash pill on snappy, and the menu closes 120ms later, faster than it
//  opened (motion.duration.popoverExit on curve.exit, shrinking back into the source).
//  Two kinds: the title menu (rows size.popoverRow 50, radius.popover 22) and the message menu
//  (Paper C3A-0: rows 44, radius.card 20), both padded 4 with a concentric pill under the
//  highlighted or selected row and a thin ink check on the chosen one. The menu hugs its
//  longest row, at least 196 wide, at most layout.popoverMax, and grows toward the leading
//  edge when it would run off the trailing one. A page installs `.rMenuHost()` once; a source
//  publishes its menu with `.rMenuSource(isPresented:kind:rows:)`, and a bubble with
//  `.rMessageMenu(isPresented:rows:)` (long press 0.4s lifts it; VoiceOver gets a "more" action).
//
import SwiftUI

// MARK: - Rows and placement (pure)

struct RMenuRow: Identifiable {
    let id: String
    let title: String
    var symbol: String?
    /// Leads to more ("open this entry ›").
    var opensMore = false
    var selected = false
    /// Says why the row can't be chosen; the row dims and reads the reason.
    var disabledReason: String?
    let action: () -> Void
}

enum RMenuKind {
    /// The title menu (measured): rows 50, panel radius 22.
    case title
    /// The message long-press menu (Paper C3A-0): rows 44, panel radius 20.
    case message

    var rowHeight: CGFloat {
        switch self {
        case .title: RDimension.sizePopoverRow
        case .message: RDimension.sizeRowCompact
        }
    }

    var radius: CGFloat {
        switch self {
        case .title: RDimension.radiusPopover
        case .message: RDimension.radiusCard
        }
    }

    /// Concentric: the panel's radius less its 4 inner padding.
    var pillRadius: CGFloat {
        radius - RDimension.space1
    }
}

/// Where the panel goes, from the source's frame and the container.
enum RMenuPlacement {
    /// The narrowest a menu gets (title-menu.md, measured).
    static let minWidth: CGFloat = 196

    /// A menu grows toward the leading edge when its width from the source's leading edge
    /// would pass the container's trailing margin.
    static func growsTowardLeading(sourceMinX: CGFloat, containerWidth: CGFloat, menuWidth: CGFloat) -> Bool {
        sourceMinX + menuWidth > containerWidth - RDimension.spaceScreenMargin
    }

    /// The panel's x inside the container: from the source's leading edge, or ending at its
    /// trailing edge when it grows toward leading; never past the margins.
    static func x(source: CGRect, containerWidth: CGFloat, menuWidth: CGFloat) -> CGFloat {
        let leading = growsTowardLeading(sourceMinX: source.minX, containerWidth: containerWidth, menuWidth: menuWidth)
        let x = leading ? source.maxX - menuWidth : source.minX
        let furthest = Swift.max(containerWidth - RDimension.spaceScreenMargin - menuWidth, RDimension.spaceScreenMargin)
        return Swift.min(Swift.max(x, RDimension.spaceScreenMargin), furthest)
    }

    /// The panel's y: 4 below the source, or above it when it wouldn't fit below.
    static func y(source: CGRect, containerHeight: CGFloat, menuHeight: CGFloat) -> CGFloat {
        let below = source.maxY + RDimension.space1
        if below + menuHeight <= containerHeight - RDimension.spaceScreenMargin {
            return below
        }
        return Swift.max(source.minY - RDimension.space1 - menuHeight, RDimension.spaceScreenMargin)
    }

    /// The panel's width: hugging the rows, between the minimum and layout.popoverMax, and at
    /// accessibility sizes the container inside its margins.
    static func width(hugging ideal: CGFloat, containerWidth: CGFloat, accessibilitySize: Bool) -> CGFloat {
        let inside = Swift.max(containerWidth - 2 * RDimension.spaceScreenMargin, minWidth)
        if accessibilitySize {
            return inside
        }
        return Swift.min(Swift.max(ideal, minWidth), Swift.min(RDimension.layoutPopoverMax, inside))
    }

    /// Which row a finger over the rows is on, from its y inside the panel's rows.
    static func row(at y: CGFloat, rowHeight: CGFloat, count: Int) -> Int? {
        guard rowHeight > 0, count > 0, y >= 0 else { return nil }
        let index = Int(y / rowHeight)
        return index < count ? index : nil
    }
}

// MARK: - The request a source makes

struct RMenuRequest: Identifiable {
    let id: UUID
    let isPresented: Binding<Bool>
    let kind: RMenuKind
    let rows: [RMenuRow]
    let anchor: Anchor<CGRect>
}

private struct RMenuRequestKey: PreferenceKey {
    static let defaultValue: [RMenuRequest] = []
    static func reduce(value: inout [RMenuRequest], nextValue: () -> [RMenuRequest]) {
        value.append(contentsOf: nextValue())
    }
}

/// The 120ms the chosen pill is shown before the menu closes (title-menu.md, measured).
private let chosenPause: Duration = .milliseconds(120)

private struct RMenuSource: ViewModifier {
    @Binding var isPresented: Bool
    let kind: RMenuKind
    let rows: [RMenuRow]
    @State private var id = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // 0–66ms: the source dims; nothing else moves yet
            .opacity(isPresented ? RNumber.opacitySourcePressed : 1)
            .animation(RMotion.standard(RNumber.motionDurationSourceDim), value: isPresented)
            .anchorPreference(key: RMenuRequestKey.self, value: .bounds) { anchor in
                isPresented ? [RMenuRequest(id: id, isPresented: $isPresented, kind: kind, rows: rows, anchor: anchor)] : []
            }
    }
}

extension View {
    /// Publishes this view's menu to the page's `rMenuHost` while `isPresented` is true. The
    /// source dims as the menu grows out of it.
    func rMenuSource(isPresented: Binding<Bool>, kind: RMenuKind = .title, rows: [RMenuRow]) -> some View {
        modifier(RMenuSource(isPresented: isPresented, kind: kind, rows: rows))
    }

    /// The message variant: a 0.4s long press lifts the bubble (raised, 1.02) with the
    /// `longPress` haptic and opens its menu; VoiceOver opens the same menu with a "more" action.
    func rMessageMenu(isPresented: Binding<Bool>, rows: [RMenuRow]) -> some View {
        modifier(RMessageMenuSource(isPresented: isPresented, rows: rows))
    }

    /// Draws the page's open menu (and its veil) over everything on the page. Install once.
    func rMenuHost() -> some View {
        modifier(RMenuHost())
    }
}

private struct RMessageMenuSource: ViewModifier {
    @Binding var isPresented: Bool
    let rows: [RMenuRow]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The press that opens the menu (title-menu.md: the haptic fires at the threshold).
    static let threshold: TimeInterval = 0.4
    /// The lifted bubble's scale (message.md "the line lifts"); no scale under Reduce Motion.
    static let lift: CGFloat = 1.02

    func body(content: Content) -> some View {
        content
            .background {
                // the raised card tier under the wash bubble while it's lifted
                RShape.rect(RDimension.radiusMessage)
                    .fill(RColor.backgroundRaised)
                    .rRaised(RDimension.radiusMessage)
                    .opacity(isPresented ? 1 : 0)
            }
            .scaleEffect(isPresented && !reduceMotion ? Self.lift : 1)
            .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.popover, value: isPresented)
            .onLongPressGesture(minimumDuration: Self.threshold) {
                isPresented = true
            }
            .sensoryFeedback(RHaptic.longPress, trigger: isPresented) { old, new in !old && new }
            .accessibilityAction(named: Text("more")) {
                isPresented = true
            }
            .anchorPreference(key: RMenuRequestKey.self, value: .bounds) { anchor in
                isPresented ? [RMenuRequest(id: UUID(), isPresented: $isPresented, kind: .message, rows: rows, anchor: anchor)] : []
            }
    }
}

// MARK: - The host

private struct RMenuHost: ViewModifier {
    @State private var settled = 0
    @State private var changes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The menu grows on popover after the source has dimmed (a 140 fade under Reduce Motion).
    private var grow: Animation {
        reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.popover.delay(RNumber.motionDurationSourceDim)
    }

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(RMenuRequestKey.self) { requests in
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        if let request = requests.first {
                            veil(request)
                            RMenuPanel(
                                request: request,
                                source: proxy[request.anchor],
                                container: proxy.size,
                                onSettle: { settled += 1 },
                                onHighlightChange: { changes += 1 }
                            )
                            .transition(reduceMotion
                                ? .opacity
                                : .modifier(active: RMenuGrow(grown: false), identity: RMenuGrow(grown: true)))
                        }
                    }
                    .animation(grow, value: requests.first?.id)
                }
            }
            // `select` as the menu settles, and on each row the finger slides onto
            .sensoryFeedback(RHaptic.select, trigger: settled)
            .sensoryFeedback(RHaptic.select, trigger: changes)
    }

    private func veil(_ request: RMenuRequest) -> some View {
        RColor.backgroundVeil
            .ignoresSafeArea()
            .transition(.opacity)
            .contentShape(Rectangle())
            .onTapGesture {
                request.isPresented.wrappedValue = false
            }
            .accessibilityHidden(true)
    }
}

/// Appears at motion.scale.popoverFrom with motion.blur.enter, grows and sharpens; leaves the
/// same way (the host's exit animation is faster than its entrance).
private struct RMenuGrow: ViewModifier {
    let grown: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(grown ? 1 : RNumber.motionScalePopoverFrom, anchor: .top)
            .blur(radius: grown ? RDimension.space0 : RDimension.motionBlurEnter)
            .opacity(grown ? 1 : 0)
    }
}

// MARK: - The panel

private struct RMenuPanel: View {
    let request: RMenuRequest
    let source: CGRect
    let container: CGSize
    let onSettle: () -> Void
    let onHighlightChange: () -> Void

    @State private var idealWidth: CGFloat = RMenuPlacement.minWidth
    /// The row under the finger, or the one just chosen (the pill slides on snappy).
    @State private var highlighted: Int?
    @State private var chosen = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var kind: RMenuKind {
        request.kind
    }

    private var width: CGFloat {
        RMenuPlacement.width(hugging: idealWidth, containerWidth: container.width, accessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    private var height: CGFloat {
        CGFloat(request.rows.count) * kind.rowHeight + 2 * RDimension.space1
    }

    var body: some View {
        rows
            .padding(RDimension.space1)
            .frame(width: width)
            .background {
                // measured once, unpadded, so the panel hugs its longest row
                rows.fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width + 2 * RDimension.space1
                    } action: { measured in
                        idealWidth = measured
                    }
            }
            .rPopover(kind.radius)
            // Increase Contrast: a 1pt control ring
            .overlay(
                RShape.rect(kind.radius)
                    .strokeBorder(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0)
            )
            .offset(
                x: RMenuPlacement.x(source: source, containerWidth: container.width, menuWidth: width),
                y: RMenuPlacement.y(source: source, containerHeight: container.height, menuHeight: height)
            )
            .simultaneousGesture(slide)
            .onAppear {
                // the choreography's settle, when the grow has landed
                Task {
                    try? await Task.sleep(for: .seconds(RNumber.motionDurationBase + RNumber.motionDurationSourceDim))
                    onSettle()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) {
                request.isPresented.wrappedValue = false
            }
            .accessibilityIdentifier("menu")
    }

    private var rows: some View {
        VStack(spacing: RDimension.space0) {
            ForEach(Array(request.rows.enumerated()), id: \.element.id) { index, row in
                RMenuRowView(row: row, kind: kind, highlighted: highlighted == index) {
                    choose(index)
                }
            }
        }
        .background(alignment: .top) {
            // one pill that slides between rows on snappy
            if let highlighted {
                RShape.rect(kind.pillRadius)
                    .fill(RColor.surfaceWash)
                    .frame(height: kind.rowHeight)
                    .offset(y: CGFloat(highlighted) * kind.rowHeight)
                    .animation(reduceMotion ? nil : RMotion.snappy, value: highlighted)
            }
        }
    }

    /// Long press, slide and release chooses in one gesture: the pill follows the finger.
    private var slide: some Gesture {
        DragGesture(minimumDistance: RDimension.space0, coordinateSpace: .local)
            .onChanged { value in
                let index = RMenuPlacement.row(at: value.location.y - RDimension.space1, rowHeight: kind.rowHeight, count: request.rows.count)
                if index != highlighted {
                    highlighted = index
                    if index != nil {
                        onHighlightChange()
                    }
                }
            }
            .onEnded { value in
                if let index = RMenuPlacement.row(at: value.location.y - RDimension.space1, rowHeight: kind.rowHeight, count: request.rows.count) {
                    choose(index)
                } else {
                    highlighted = nil
                }
            }
    }

    private func choose(_ index: Int) {
        guard !chosen else { return }
        let row = request.rows[index]
        guard row.disabledReason == nil else { return }
        chosen = true
        highlighted = index
        Task {
            try? await Task.sleep(for: chosenPause)
            request.isPresented.wrappedValue = false
            row.action()
        }
    }
}

private struct RMenuRowView: View {
    let row: RMenuRow
    let kind: RMenuKind
    let highlighted: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: RDimension.space3) {
                if let symbol = row.symbol {
                    RSymbol(name: symbol, size: .small, tint: row.disabledReason == nil ? RColor.iconDefault : RColor.iconMuted)
                }
                Text(row.title)
                    .rText(.menuRow)
                    .foregroundStyle(row.disabledReason == nil ? RColor.textPrimary : RColor.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: RDimension.space0)
                if row.selected {
                    // a thin 18 ink check, no disc
                    RSymbol(name: "checkmark", size: .regular, tint: RColor.inkDefault, glyphScale: RSymbol.checkGlyphScale)
                        .accessibilityHidden(true)
                } else if row.opensMore {
                    RSymbol(name: "chevron.right", size: .small, tint: RColor.iconMuted)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, RDimension.space3)
            .frame(maxWidth: .infinity, minHeight: kind.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(row.disabledReason != nil)
        .accessibilityAddTraits(row.selected ? .isSelected : [])
        .accessibilityHint(row.disabledReason ?? "")
        .accessibilityIdentifier("menu.\(row.id)")
    }
}

extension RSymbol {
    /// The 18 check in a 20 slot (the title menu's thin ink check).
    static let checkGlyphScale: CGFloat = 0.9 // literal-ok: 18 of the 20 slot, as drawn
}

extension RTextStyle {
    /// Menu rows (Paper C3A-0 `c:menu/message`: Geist 14 medium, snug, no tracking).
    static let menuRow = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

#if DEBUG
/// Lab page "menu": a title menu with a selected and a disabled row, and your message bubble
/// with its long-press menu (copy · open this entry). `-DesignLabAutoplay` opens each in turn.
struct RMenuGallery: View {
    @State private var titleOpen = false
    @State private var bubbleOpen = false
    @State private var length = "standard"
    @State private var last = "nothing chosen yet"

    private let words = "walked the long way home by the canal. felt lighter after."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("title menu · length (selected · disabled)")
                RPill(title: "length · \(length)", symbol: "chevron.down", style: .raised) { titleOpen = true }
                    .rMenuSource(isPresented: $titleOpen, rows: lengthRows)
                    .accessibilityIdentifier("menu.openTitle")
                caption("your message · long press (or the VoiceOver \"more\" action)")
                RMessageBubble(text: words)
                    .rMessageMenu(isPresented: $bubbleOpen, rows: messageRows)
                caption(last)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .rMenuHost()
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            titleOpen = true
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            titleOpen = false
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            bubbleOpen = true
        }
    }

    private var lengthRows: [RMenuRow] {
        ["short", "standard", "long"].map { option in
            RMenuRow(
                id: option,
                title: option,
                selected: option == length,
                disabledReason: option == "long" ? "needs a connected calendar" : nil
            ) {
                length = option
                last = "chose \(option)"
            }
        }
    }

    private var messageRows: [RMenuRow] {
        [
            RMenuRow(id: "copy", title: "copy", symbol: "doc.on.doc") {
                // text only, never logged
                UIPasteboard.general.string = words
                last = "copied"
            },
            RMenuRow(id: "open", title: "open this entry", symbol: "arrow.up.right", opensMore: true) {
                last = "opened the entry"
            },
        ]
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("menu") { RMenuGallery() }
#endif
