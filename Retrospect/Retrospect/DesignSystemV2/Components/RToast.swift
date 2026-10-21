//
//  RToast.swift
//  M14 C21: says something just happened, offers undo, and goes away (toast.md; Paper approvals,
//  "review · toast and tags", part 30 rounds 3–4). Frosted paper on the floating tier, an SF Symbol
//  in a 28 wash well saying what changed, SF Pro 14 medium words, undo with a 44 hit area.
//  The founder is choosing between four looks in hand (round 4), so all four are here behind `Look`.
//
import SwiftUI

extension RTextStyle {
    /// The toast's undo (Paper part 30: --text-md, semibold).
    static let toastAction = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .semibold,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

struct RToast: View {
    /// Round 4's four ways to make the frosted toast harder to miss.
    enum Look: String, CaseIterable, Identifiable {
        /// 1 · the frost with the overlay tier's deeper shadow.
        case frost
        /// 2 · thicker frost, a crisp 1pt edge in the divider grey, the deeper shadow (lean).
        case frostEdge
        /// 3 · glass a step darker than the page.
        case greyGlass
        /// 4 · dark glass, between the ink and the white.
        case darkGlass

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .frost: "1 · shadow"
            case .frostEdge: "2 · edge"
            case .greyGlass: "3 · grey"
            case .darkGlass: "4 · dark"
            }
        }
    }

    let message: String
    /// An SF Symbol for the thing that changed (goal, entry, fix, download).
    var symbol: String?
    var look: Look = .frostEdge
    var undo: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        content
            .background { RToastSurface(look: look, radius: radius) }
            .frame(maxWidth: RDimension.layoutToastMaxWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, look == .darkGlass ? .dark : colorScheme)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityAction(named: Text("undo")) { undo?() }
    }

    @Environment(\.colorScheme) private var colorScheme

    /// A true pill at one line; at accessibility sizes it becomes a block with undo on its own line.
    private var stacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var radius: CGFloat {
        RDimension.sizeControlDefault / 2
    }

    @ViewBuilder private var content: some View {
        if stacked {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                HStack(alignment: .top, spacing: RDimension.space3) {
                    if let symbol {
                        well(symbol)
                    }
                    words
                }
                if let undo {
                    undoButton(undo)
                }
            }
            .padding(.top, RDimension.space4)
            .padding(.bottom, undo == nil ? RDimension.space4 : RDimension.space1)
            .padding(.horizontal, RDimension.space5)
        } else {
            HStack(spacing: RDimension.space1) {
                if let symbol {
                    well(symbol)
                }
                words
                    .padding(.leading, symbol == nil ? RDimension.space5 : RDimension.space2)
                    .padding(.trailing, undo == nil ? RDimension.space5 : RDimension.space0)
                if let undo {
                    undoButton(undo)
                        .padding(.trailing, RDimension.space1)
                }
            }
            .padding(.leading, symbol == nil ? RDimension.space0 : RDimension.space2)
            .frame(minHeight: RDimension.sizeControlDefault)
        }
    }

    private var words: some View {
        Text(message)
            .rText(.textMdMedium)
            .foregroundStyle(RColor.textPrimary)
            .lineLimit(stacked ? nil : 1)
    }

    /// The 28 well sits 8 in from the round end, so its curve is concentric with the toast's (22 − 8 = 14).
    private func well(_ symbol: String) -> some View {
        RSymbol(name: symbol, size: .small, tint: RColor.iconDefault)
            .frame(width: RDimension.sizeAvatarSmall, height: RDimension.sizeAvatarSmall)
            .rWash()
    }

    private func undoButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("undo")
                .rText(.toastAction)
                .foregroundStyle(RColor.accentText)
                .padding(.horizontal, stacked ? RDimension.space0 : RDimension.space4)
                .frame(minWidth: RDimension.sizeTouchTarget, minHeight: RDimension.sizeTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .rPress(small: true, haptic: RHaptic.select)
        .accessibilityHidden(true)
    }
}

/// The floating surface under the words: frosted material tinted with a token surface, the inner top
/// edge, an outer stroke and the overlay tier's contact, cast and ambient shadows.
private struct RToastSurface: View {
    let look: RToast.Look
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(tint))
            .overlay(alignment: .top) {
                shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .overlay(shape.stroke(edge, lineWidth: edgeWidth))
            .shadow(color: RColor.depthShadowContact, radius: 1, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 16, y: 14)
            .shadow(color: RColor.depthShadowAmbient, radius: 32, y: 28)
    }

    /// How much of the token surface sits over the blur (Paper: 62% frost, 86% thick frost, 84% glass).
    private var tint: Color {
        switch look {
        case .frost: RColor.backgroundRaised.opacity(0.62) // literal-ok: Paper round 4, frost density
        case .frostEdge: RColor.backgroundRaised.opacity(0.86) // literal-ok: Paper round 4, thick frost
        case .greyGlass: RColor.surfaceControl.opacity(0.84) // literal-ok: Paper round 4, glass density
        case .darkGlass: RColor.backgroundRaised.opacity(0.84) // literal-ok: Paper round 4, glass density
        }
    }

    private var edge: Color {
        look == .frostEdge ? RColor.borderStrong : RColor.depthStrokeOuter
    }

    private var edgeWidth: CGFloat {
        look == .frostEdge ? RDimension.sizeBorderDefault : RDimension.sizeBorderHairline
    }
}

// MARK: - Presenting

extension View {
    /// Shows `toast` floating at the bottom, `bottomInset` above the edge (12 above the tab bar or
    /// mini-player). It rises 12pt out of a 6pt blur on arrival, drops 6pt and fades on leaving, stays
    /// for motion.duration.toastVisible while untouched, and swipes down to dismiss. One at a time:
    /// setting a new toast replaces the old.
    func rToast(_ toast: Binding<RToastItem?>, bottomInset: CGFloat) -> some View {
        modifier(RToastHost(item: toast, bottomInset: bottomInset))
    }
}

/// One toast's content, identified so a new one replaces the old.
struct RToastItem: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var symbol: String?
    var look: RToast.Look = .frostEdge
    var undo: (() -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private struct RToastHost: ViewModifier {
    @Binding var item: RToastItem?
    let bottomInset: CGFloat
    @State private var touching = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let item {
                    RToast(message: item.message, symbol: item.symbol, look: item.look, undo: item.undo.map { undo in
                        { undo(); dismiss() }
                    })
                    .id(item.id)
                    .transition(transition)
                    .gesture(swipeDown)
                    .onLongPressGesture(minimumDuration: .infinity, pressing: { touching = $0 }, perform: {})
                    .task(id: item.id) { await autoDismiss() }
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                }
            }
            .padding(.bottom, bottomInset)
            .animation(RMotion.standard(RNumber.motionDurationExpand), value: item)
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            AccessibilityNotification.Announcement(new.message).post()
        }
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: RToastMotion(offset: RDimension.space3, blur: RDimension.radiusSmall, opacity: 0),
                identity: RToastMotion(offset: 0, blur: 0, opacity: 1)
            ),
            removal: .modifier(
                active: RToastMotion(offset: RDimension.radiusSmall, blur: 0, opacity: 0),
                identity: RToastMotion(offset: 0, blur: 0, opacity: 1)
            )
            .animation(RMotion.exit(RNumber.motionDurationFast))
        )
    }

    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: RDimension.space2).onEnded { value in
            if value.translation.height > RDimension.space6 {
                dismiss()
            }
        }
    }

    /// Leaves after toastVisible; waits while it's touched or VoiceOver is on it.
    private func autoDismiss() async {
        var elapsed: Double = 0
        let step = RNumber.motionDurationFast
        while elapsed < RNumber.motionDurationToastVisible {
            try? await Task.sleep(for: .seconds(step))
            if Task.isCancelled {
                return
            }
            if !touching, !voiceOver {
                elapsed += step
            }
        }
        dismiss()
    }

    private func dismiss() {
        item = nil
    }
}

/// Rise, blur and fade as one transition state.
private struct RToastMotion: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(y: offset).blur(radius: blur).opacity(opacity)
    }
}

#if DEBUG
/// Round 4 in hand: a goals-like list scrolling under the toast, a picker for the four looks.
struct RToastGallery: View {
    @State private var look: RToast.Look = .frostEdge
    @State private var toast: RToastItem?
    /// Paper round 3's four messages, each with the symbol for what changed.
    private let samples: [RToastItem] = [
        RToastItem(message: "ended \u{201C}run twice a week\u{201D}", symbol: "target", undo: {}),
        RToastItem(message: "saved to your journal", symbol: "book.closed", undo: {}),
        RToastItem(message: "fixed what i got wrong", symbol: "text.bubble", undo: {}),
        RToastItem(message: "downloaded for the train", symbol: "arrow.down.circle"),
    ]
    @State private var next = 0

    var body: some View {
        VStack(spacing: RDimension.space3) {
            Picker("look", selection: $look) {
                ForEach(RToast.Look.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, RDimension.spaceScreenMargin)
            Button("show another") { show() }
                .rText(.labelMedium)
                .foregroundStyle(RColor.textLink)
                .frame(minHeight: RDimension.sizeTouchTarget)
            ScrollView {
                VStack(spacing: RDimension.space4) {
                    ForEach(0 ..< 8, id: \.self) { index in
                        VStack(alignment: .leading, spacing: RDimension.space2) {
                            Text(["ship the first version", "sleep before midnight", "call mum on sundays", "read before bed"][index % 4])
                                .rText(.textMdMedium)
                                .foregroundStyle(RColor.textPrimary)
                            Text("you work on it most on tuesdays.")
                                .rText(.textMd)
                                .foregroundStyle(RColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(RDimension.space5)
                        .rRaised()
                    }
                }
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .padding(.bottom, RDimension.space16 + RDimension.sizeControlDefault)
            }
            .rToast($toast, bottomInset: RDimension.space6)
        }
        .background(RColor.backgroundCanvas)
        .onChange(of: look) { _, _ in show() }
        .task {
            // -ToastLook <name> picks a look and shows a toast on launch (for checking each look).
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-ToastLook"), index + 1 < arguments.count,
               let chosen = RToast.Look(rawValue: arguments[index + 1]), chosen != look {
                look = chosen // onChange shows it
            } else {
                show()
            }
        }
    }

    private func show() {
        let sample = samples[next % samples.count]
        next += 1
        toast = RToastItem(message: sample.message, symbol: sample.symbol, look: look, undo: sample.undo)
    }
}

#Preview("toast") { RToastGallery() }
#endif
