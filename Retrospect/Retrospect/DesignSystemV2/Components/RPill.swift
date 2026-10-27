//
//  RPill.swift
//  M14 C05: the pill (Paper c:pill/neutral, c:pill/raised, c:pill/raised/action; chip.md).
//  neutral sits in the page as a wash; raised floats as the cream control; action is the
//  words-only raised pill at the end of a row (connect, play, export, sample). 32 tall, a true
//  pill, in a 44pt hit area. Padding 8 on the icon side and 12 on the other (craft 2.5).
//  Medium (a card's answers, Paper B7U-0): 36 tall, 16 each side, 8 between glyph and words.
//
import SwiftUI

struct RPill: View {
    enum Style { case neutral, raised, action }
    enum Size { case small, medium }

    let title: String
    var symbol: String?
    var style: Style = .neutral
    var size: Size = .small
    /// Says why it can't be used; the pill dims and reads the reason aloud.
    var disabledReason: String?
    /// The pill's action is on its way: a turning ring leads the words and the pill can't be
    /// pressed again, without dimming (it's busy, not unavailable).
    var pending = false
    /// The raised surface: today's (the default) or Paper's c:pill/raised box-shadows exactly (SH.composer).
    var look = RDepthLook.current
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: size == .medium ? RDimension.space2 : RDimension.space1) {
                if pending {
                    // a 12 ring in the 16 glyph slot, so the words don't move
                    RSpinner(diameter: RDimension.sizeIconSmall - 2 * RDimension.sizeBorderRing)
                        .frame(width: RDimension.sizeIconSmall, height: RDimension.sizeIconSmall)
                        .accessibilityHidden(true)
                } else if let symbol, style != .action {
                    RSymbol(name: symbol, size: .small)
                }
                Text(title)
                    .rText(style == .action ? .pillAction : .pill)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(RPillStyle(style: style, size: size, leadingIcon: pending || (symbol != nil && style != .action), look: look))
        .disabled(disabledReason != nil || pending)
        .accessibilityValue(pending ? "busy" : "")
        .opacity(disabledReason == nil ? 1 : RNumber.opacityDisabled)
        .accessibilityHint(disabledReason ?? "")
    }
}

private struct RPillStyle: ButtonStyle {
    let style: RPill.Style
    let size: RPill.Size
    let leadingIcon: Bool
    var look = RDepthLook.current
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var leading: CGFloat {
        switch size {
        case .small: leadingIcon ? RDimension.space2 : RDimension.space3
        case .medium: RDimension.space4
        }
    }

    private var trailing: CGFloat {
        size == .medium ? RDimension.space4 : RDimension.space3
    }

    private var height: CGFloat {
        size == .medium ? RDimension.sizeControlMedium : RDimension.sizeControlSmall
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .frame(minHeight: height)
            .modifier(RPillBody(style: style, pressed: pressed, look: look))
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            // weighted press: in fast, out slower (craft 1.9)
            .animation(RMotion.standard(pressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut), value: pressed)
            // the 32 (or 36) visual sits centred in a 44pt hit area (craft 1.7)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
    }
}

private struct RPillBody: ViewModifier {
    let style: RPill.Style
    let pressed: Bool
    let look: RDepthLook

    func body(content: Content) -> some View {
        switch (style, look) {
        case (.neutral, _):
            content.background(pressed ? RColor.surfaceWashPressed : RColor.surfaceWash, in: RShape.pill)
        case (.raised, .current), (.action, .current):
            content.rSecondary(pressed: pressed)
        case (.raised, .paper), (.action, .paper):
            content.rSecondaryPaper(pressed: pressed)
        }
    }
}

/// A quick answer on an onboarding question (Paper c:pill/choice/off MHE-0 and c:pill/choice/on MHK-0,
/// ON-4a quick answers MGZ-0; build notes c-6gtmpz). 36 tall, a true pill, in a 44 hit area. Off: a
/// surface.wash pill, 16 each side. On: lifted to background.raised with Paper's choice shadow, a 14
/// check 4 before the words, 12 on the check side and 16 on the other; no ink fill. Toggling
/// cross-fades over 200 ms with the select haptic; Reduce Motion keeps the cross-fade, no press scale.
struct RChoicePill: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    /// Taps on this pill: the select haptic follows a tap, never `isOn` changing for another reason
    /// (typing the chip's words by hand).
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: RDimension.space1) {
                if isOn {
                    RSymbol(name: "checkmark", size: .check)
                        .transition(.opacity)
                }
                Text(title)
                    .rText(.pill)
                    .foregroundStyle(RColor.textPrimary)
                    // never cut: at accessibility sizes a long answer wraps inside its pill
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, isOn ? RDimension.space3 : RDimension.space4)
            .padding(.trailing, RDimension.space4)
            .frame(minHeight: RDimension.sizeControlMedium)
            .background {
                ZStack {
                    RShape.pill.fill(RColor.surfaceWash)
                        .opacity(isOn ? 0 : 1)
                    RShape.pill.fill(RColor.backgroundRaised)
                        .rBoxShadows(RElevation.boxShadowPillChoiceOn, radius: RDimension.radiusControl)
                        .opacity(isOn ? 1 : 0)
                }
            }
            // the 36 pill keeps Paper's 8 gaps; its tap area reaches 44 tall beyond the edge (as the
            // composer's corner does), so rows of chips are not spread apart by their hit areas
            .contentShape(RShape.pill.inset(by: (RDimension.sizeControlMedium - RDimension.sizeTouchTarget) / 2))
        }
        .buttonStyle(RChoicePressStyle())
        .animation(RMotion.standard(RNumber.motionDurationBase), value: isOn)
        .sensoryFeedback(RHaptic.select, trigger: taps)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The choice pill's press: the weighted small press scale (craft 1.9), none with Reduce Motion.
private struct RChoicePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            .animation(RMotion.standard(pressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut), value: pressed)
    }
}

#if DEBUG
struct RPillGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            Text("pill").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            HStack(spacing: RDimension.space2) {
                RPill(title: "chapters", symbol: "list.bullet") {}
                RPill(title: "transcript", style: .neutral) {}
            }
            HStack(spacing: RDimension.space2) {
                RPill(title: "add a source", symbol: "plus", style: .raised) {}
                RPill(title: "connect", style: .action) {}
                RPill(title: "play", style: .action) {}
            }
            HStack(spacing: RDimension.space2) {
                RChoicePill(title: "tech", isOn: true) {}
                RChoicePill(title: "football", isOn: false) {}
            }
            HStack(spacing: RDimension.space2) {
                RPill(title: "export", style: .action, disabledReason: "nothing to export yet") {}
                RPill(title: "sync now", symbol: "arrow.clockwise", style: .raised, disabledReason: "offline") {}
            }
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("pill") { RPillGallery() }
#endif
