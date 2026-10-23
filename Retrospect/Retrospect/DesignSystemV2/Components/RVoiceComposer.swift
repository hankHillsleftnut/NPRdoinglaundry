//
//  RVoiceComposer.swift
//  M14 C14: the voice composer, the bar at the bottom of Journal where you talk or type to Retro
//  (Paper approvals part 07 c:voice-composer/*, and the current board "everything · latest" JR-1;
//  the dark file's copies). A raised 56 pill, radius.composer, the state words 20 in from the
//  leading edge, and one 32 corner button that never moves: mute while voice is on, mic once
//  muted, the lit send once there are words. With `voice` off (a host with nothing to record
//  into) there is no mic: the corner is empty until there are words, then the lit send.
//
//  Listening (and thinking) take the current board's look: a 0.5 glow.primary.ring edge and
//  four offset glows outside the bar (founder c-tmcs3y). Typing grows like the composer
//  (RFieldGrowth, RGrowingField).
//
import SwiftUI

extension RTextStyle {
    /// The voice composer's words and state line: SF 17, leading snug, card tracking (Paper part 07).
    static let composerText = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.body.leading,
        relativeTo: .body
    )
}

struct RVoiceComposer: View {
    enum Mode: Equatable {
        /// Your turn: it hears you; your words land on the page, not in the bar.
        case listening
        /// Retro's turn: dark bars; a tap anywhere cuts in.
        case speaking
        /// You've stopped; Retro is working out its reply.
        case thinking
        /// Voice off: a text field.
        case muted
    }

    @Binding var mode: Mode
    @Binding var text: String
    /// Offers the mic. Off for a host that can't record yet, so the bar never says
    /// "listening…" while keeping nothing (decision 4); on by default.
    var voice = true
    /// The live voice level, 0…1: yours while listening, Retro's while speaking. Nil rests the bars.
    var level: Double?
    /// The muted field's placeholder, and the name VoiceOver reads for it.
    var placeholder = "message retro…"
    var fieldLabel = "message retro"
    var onSend: (String) -> Void = { _ in }
    /// Speaking: a tap anywhere on the bar.
    var onInterrupt: () -> Void = {}

    @FocusState private var focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A 32 control with 12 above and below: the 56 bar.
    private static let growth = RFieldGrowth(
        style: .composerText,
        restHeight: RDimension.sizeControlSmall + 2 * RDimension.space3
    )

    private var isSend: Bool {
        mode == .muted && !text.isEmpty
    }

    /// Whether the corner button is there: always with voice; without it, only as the send.
    static func showsCorner(voice: Bool, mode: Mode, text: String) -> Bool {
        voice || (mode == .muted && !text.isEmpty)
    }

    /// What a tap on the corner does: send the words, or switch between talking and typing.
    /// Without voice there is nothing to switch to, so only the send.
    enum CornerTap: Equatable {
        case send
        case toggle(to: Mode)
        case none
    }

    static func cornerTap(voice: Bool, mode: Mode, text: String) -> CornerTap {
        if mode == .muted, !text.isEmpty {
            return .send
        }
        guard voice else { return .none }
        return .toggle(to: mode == .muted ? .listening : .muted)
    }

    /// Listening and thinking light the bar's edge and glow.
    private var isLit: Bool {
        mode == .listening || mode == .thinking
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: RDimension.space3) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            cornerButton
                .padding(.top, RDimension.space3)
                .padding(.bottom, max(
                    RDimension.space3,
                    Self.growth.bottomInset(centring: RDimension.sizeControlSmall, at: dynamicTypeSize)
                ))
        }
        .padding(.leading, RDimension.space5)
        .padding(.trailing, RDimension.space3)
        .frame(minHeight: Self.growth.restHeight)
        .background { surface }
        .contentShape(RShape.rect(RDimension.radiusComposer))
        .onTapGesture {
            if mode == .speaking {
                onInterrupt()
            }
        }
        .onChange(of: mode) { _, new in
            // leaving muted drops the keyboard; coming back never raises it unasked
            if new != .muted {
                focused = false
            }
            if let word = stateWord(new) {
                AccessibilityNotification.Announcement(word).post()
            }
        }
        .sensoryFeedback(trigger: mode) { old, new in
            if new == .listening {
                return RHaptic.listenStart
            }
            if old == .listening {
                return RHaptic.listenStop
            }
            return old == .speaking ? RHaptic.turn : nil
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if mode == .muted {
            RGrowingField(
                label: fieldLabel,
                placeholder: placeholder,
                text: $text,
                style: .composerText,
                growth: Self.growth,
                focused: $focused
            )
            .transition(.opacity)
        } else {
            HStack(alignment: .top, spacing: RDimension.space3) {
                // centred on the first line when the words wrap at large sizes
                indicator
                    .frame(height: Self.growth.lineHeight(at: dynamicTypeSize))
                Text(stateWord(mode) ?? "")
                    .rText(.composerText)
                    .foregroundStyle(contrast == .increased ? RColor.textSecondary : RColor.textPlaceholder)
                    .contentTransition(.interpolate)
            }
            .padding(.vertical, Self.growth.textInset)
            .animation(RMotion.standard(RNumber.motionDurationSlow), value: mode)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stateWord(mode) ?? "")
            .accessibilityHint(mode == .speaking ? "double-tap to cut in" : "")
            .transition(.opacity)
        }
    }

    /// The bars while someone speaks; three dots while Retro thinks (the bars settle into them).
    private var indicator: some View {
        Group {
            switch mode {
            case .listening:
                RWaveform(mode: .listening, level: level)
            case .speaking:
                RWaveform(mode: .speaking, level: level)
            case .thinking:
                RPendingDots(diameter: RDimension.sizeVoiceThinkingDot)
                    .foregroundStyle(RColor.voiceListening)
                    .frame(height: RDimension.sizeIconDefault)
            case .muted:
                EmptyView()
            }
        }
        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
    }

    private func stateWord(_ mode: Mode) -> String? {
        switch mode {
        case .listening: "listening…"
        case .speaking: "retro is speaking…"
        case .thinking: "thinking…"
        case .muted: nil
        }
    }

    // MARK: Corner button

    private var cornerButton: some View {
        Button(action: cornerAction) {
            ZStack {
                Circle()
                    .fill(RColor.surfaceWash)
                    .opacity(isSend ? 0 : 1)
                // send rises in: scale 0.86 → 1, blur 4 → 0, on popover (composer.md)
                Color.clear
                    .rLit()
                    .opacity(isSend ? 1 : 0)
                    .scaleEffect(isSend || reduceMotion ? 1 : RNumber.motionScalePopoverFrom)
                    .blur(radius: isSend || reduceMotion ? 0 : RDimension.motionAppearBlurFrom / 2) // literal-ok: half the appear blur (4)
                // Paper's 18 marks, as the composer's mic (C12, C13)
                RSymbol(
                    name: cornerSymbol,
                    tint: isSend ? RColor.glowPrimaryForeground : RColor.iconDefault,
                    weight: .medium,
                    glyphScale: 0.74 // literal-ok: 18 × 0.82 in the 20 frame
                )
                .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: RDimension.sizeControlSmall, height: RDimension.sizeControlSmall)
            .contentShape(Circle().inset(by: (RDimension.sizeControlSmall - RDimension.sizeTouchTarget) / 2))
        }
        .rPress(small: true, haptic: isSend ? RHaptic.press : nil)
        // without voice the empty corner keeps its frame, so the field never reflows as send rises
        .opacity(showsCorner ? 1 : 0)
        .allowsHitTesting(showsCorner)
        .accessibilityHidden(!showsCorner)
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.popover, value: isSend)
        .animation(RMotion.standard(RNumber.motionDurationFast), value: mode)
        .accessibilityLabel(cornerLabel)
    }

    private var showsCorner: Bool {
        Self.showsCorner(voice: voice, mode: mode, text: text)
    }

    private var cornerSymbol: String {
        if isSend {
            return "arrow.up"
        }
        return mode == .muted ? "mic" : "mic.slash"
    }

    private var cornerLabel: String {
        if isSend {
            return "send"
        }
        return mode == .muted ? "talk instead" : "stop listening, type instead"
    }

    private func cornerAction() {
        switch Self.cornerTap(voice: voice, mode: mode, text: text) {
        case .send:
            onSend(text)
            text = ""
        case let .toggle(to):
            mode = to
        case .none:
            break
        }
    }

    // MARK: Surface

    /// Raised white in every state; listening and thinking add the edge and the glows outside.
    private var surface: some View {
        let shape = RShape.rect(RDimension.radiusComposer)
        return ZStack {
            Color.clear
                .rRaised(RDimension.radiusComposer)
                .opacity(isLit ? 0 : 1)
            ZStack {
                RListeningGlow(radius: RDimension.radiusComposer)
                shape.fill(RColor.backgroundRaised)
                    .shadow(color: RColor.depthShadowContact, radius: 1, y: 1) // literal-ok: Paper's contact 0 1 2
                shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
                shape.stroke(RColor.glowPrimaryRing, lineWidth: RDimension.sizeBorderHairline)
            }
            .opacity(isLit ? 1 : 0)
            // Increase Contrast: a 1pt border.control ring at rest (voice-composer.md)
            if contrast == .increased, !isLit {
                shape.strokeBorder(RColor.borderControl, lineWidth: RDimension.sizeBorderDefault)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationSlow), value: isLit)
    }
}

/// The listening glow: four soft, offset glows outside the bar, so it reads as light moving
/// rather than a ring (founder c-tmcs3y). Paper box-shadows: offset x y, blur, spread.
private struct RListeningGlow: View {
    let radius: CGFloat

    private struct Glow {
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let blur: CGFloat
        let spread: CGFloat
    }

    /// Paper's four listening glows (x, y, blur, spread), as drawn on JR-1 and in the dark file.
    private static let glows = [
        Glow(color: RColor.voiceGlowPool, x: -64, y: 10, blur: 34, spread: -16), // literal-ok: Paper geometry
        Glow(color: RColor.voiceGlowLift, x: 72, y: -6, blur: 30, spread: -14), // literal-ok: Paper geometry
        Glow(color: RColor.voiceGlowUnder, x: 18, y: 20, blur: 36, spread: -18), // literal-ok: Paper geometry
        Glow(color: RColor.voiceGlowTop, x: -10, y: -12, blur: 26, spread: -16), // literal-ok: Paper geometry
    ]

    var body: some View {
        ZStack {
            ForEach(Self.glows.indices, id: \.self) { index in
                let glow = Self.glows[index]
                RShape.rect(radius)
                    .inset(by: -glow.spread)
                    .fill(glow.color)
                    .blur(radius: glow.blur / 2)
                    .offset(x: glow.x, y: glow.y)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Every state part 07 and JR-1 draw, at rest (the bars in Paper's shape), then a live bar to
/// play with: the fake level moves the bars, and the corner button mutes, talks and sends.
struct RVoiceComposerGallery: View {
    @State private var live: RVoiceComposer.Mode = .listening
    @State private var liveText = ""
    @State private var typed = "i think it's the 9am standup. i dread it, every week."
    @State private var grown = "i think it's the 9am standup. i dread it, every week. it's not the "
        + "work, it's having to say what i did yesterday out loud before coffee."
    @State private var none = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space10) {
                still(.listening, $none)
                still(.speaking, $none)
                still(.muted, $none)
                still(.muted, $typed)
                still(.thinking, $none)
                still(.muted, $grown)
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // a fake voice: two slow sines, 0…1
                    let level = (sin(t * 5) * sin(t * 1.3) + 1) / 2 // literal-ok: debug-only fake level
                    RVoiceComposer(mode: $live, text: $liveText, level: live == .muted ? nil : level)
                }
                HStack(spacing: RDimension.space2) {
                    Button("listen") { live = .listening }
                    Button("speak") { live = .speaking }
                    Button("think") { live = .thinking }
                    Button("mute") { live = .muted }
                }
                .rText(.label)
                .foregroundStyle(RColor.textLink)
            }
            .padding(RDimension.spaceScreenMargin)
            .padding(.vertical, RDimension.space8)
        }
        .background(RColor.backgroundCanvas)
    }

    private func still(_ mode: RVoiceComposer.Mode, _ text: Binding<String>) -> some View {
        RVoiceComposer(mode: .constant(mode), text: text)
    }
}

#Preview("voice composer") { RVoiceComposerGallery() }
#endif
