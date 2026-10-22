//
//  RPill.swift
//  M14 C05: the pill (Paper c:pill/neutral, c:pill/raised, c:pill/raised/action; chip.md).
//  neutral sits in the page as a wash; raised floats as the cream control; action is the
//  words-only raised pill at the end of a row (connect, play, export, sample). 32 tall, a true
//  pill, in a 44pt hit area. Padding 8 on the icon side and 12 on the other (craft 2.5).
//
import SwiftUI

struct RPill: View {
    enum Style { case neutral, raised, action }

    let title: String
    var symbol: String?
    var style: Style = .neutral
    /// Says why it can't be used; the pill dims and reads the reason aloud.
    var disabledReason: String?
    /// The pill's action is on its way: a turning ring leads the words and the pill can't be
    /// pressed again, without dimming (it's busy, not unavailable).
    var pending = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RDimension.space1) {
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
        .buttonStyle(RPillStyle(style: style, leadingIcon: pending || (symbol != nil && style != .action)))
        .disabled(disabledReason != nil || pending)
        .accessibilityValue(pending ? "busy" : "")
        .opacity(disabledReason == nil ? 1 : RNumber.opacityDisabled)
        .accessibilityHint(disabledReason ?? "")
    }
}

private struct RPillStyle: ButtonStyle {
    let style: RPill.Style
    let leadingIcon: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .padding(.leading, leadingIcon ? RDimension.space2 : RDimension.space3)
            .padding(.trailing, RDimension.space3)
            .frame(minHeight: RDimension.sizeControlSmall)
            .modifier(RPillBody(style: style, pressed: pressed))
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            // weighted press: in fast, out slower (craft 1.9)
            .animation(RMotion.standard(pressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut), value: pressed)
            // the 32pt visual sits centred in a 44pt hit area (craft 1.7)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
    }
}

private struct RPillBody: ViewModifier {
    let style: RPill.Style
    let pressed: Bool

    func body(content: Content) -> some View {
        switch style {
        case .neutral:
            content.background(pressed ? RColor.surfaceWashPressed : RColor.surfaceWash, in: RShape.pill)
        case .raised, .action:
            content.rSecondary(pressed: pressed)
        }
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
                RPill(title: "export", style: .action, disabledReason: "nothing to export yet") {}
                RPill(title: "sync now", symbol: "arrow.clockwise", style: .raised, disabledReason: "offline") {}
            }
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("pill") { RPillGallery() }
#endif
