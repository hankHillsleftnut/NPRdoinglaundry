//
//  RButton.swift
//  M14 C01–C03: primary (lit), secondary (cream) and text buttons, from
//  design-system/components/button.md and the approved boards (ON-6 continue / later,
//  ON-12 plan buttons). One component, a variant and a state; every value a token.
//
import SwiftUI

struct RButton: View {
    enum Variant { case primary, secondary, text }
    enum Status: Equatable {
        case rest
        /// Presses blocked; the label stays and dots pulse over it (button.md rule 3).
        case pending
        /// No glow; the reason shows under it (rule 5).
        case disabled(reason: String)
        /// Back to rest, with the reason under it.
        case error(String)
    }

    let title: String
    var variant: Variant = .primary
    var status: Status = .rest
    let action: () -> Void

    private var isInteractive: Bool {
        status == .rest || isError
    }

    private var isError: Bool {
        if case .error = status {
            true
        } else {
            false
        }
    }

    private var note: String? {
        switch status {
        case let .disabled(reason): reason
        case let .error(message): message
        default: nil
        }
    }

    var body: some View {
        VStack(spacing: RDimension.space2) {
            Button(action: action) { label }
                .buttonStyle(RButtonStyle(variant: variant, enabled: isEnabled))
                .disabled(!isInteractive)
                .accessibilityValue(status == .pending ? "busy" : "")
                .accessibilityHint(note ?? "")
            if let note {
                Text(note)
                    .rText(.label)
                    .foregroundStyle(isError ? RColor.statusDangerText : RColor.textLabel)
                    .multilineTextAlignment(.center)
                    .transition(.blurReplace)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationBase), value: status)
        .sensoryFeedback(RHaptic.error, trigger: isError) { _, now in now }
    }

    private var isEnabled: Bool {
        if case .disabled = status {
            false
        } else {
            true
        }
    }

    private var label: some View {
        Text(title)
            .rText(variant == .primary ? .buttonLabel : .bodyMedium)
            .lineLimit(1)
            .opacity(status == .pending ? 0.35 : 1) // literal-ok: label kept faint under the pending dots
            .overlay {
                if status == .pending {
                    RPendingDots()
                }
            }
    }
}

/// The press, the depth and the colours for each variant.
private struct RButtonStyle: ButtonStyle {
    let variant: RButton.Variant
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return Group {
            switch variant {
            case .primary:
                configuration.label
                    .frame(maxWidth: .infinity, minHeight: RDimension.sizeControlHero)
                    .foregroundStyle(enabled ? RColor.glowPrimaryForeground : RColor.textDisabled)
                    .modifier(PrimaryBody(enabled: enabled, pressed: pressed))
            case .secondary:
                configuration.label
                    .frame(maxWidth: .infinity, minHeight: RDimension.sizeControlHero)
                    .foregroundStyle(enabled ? RColor.textPrimary : RColor.textDisabled)
                    .rSecondary()
            case .text:
                configuration.label
                    .frame(minHeight: RDimension.sizeControlDefault)
                    .padding(.horizontal, RDimension.space3)
                    .foregroundStyle(enabled ? RColor.textLink : RColor.textDisabled)
                    .contentShape(Rectangle())
            }
        }
        .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePress : 1)
        .animation(pressed ? RMotion.standard(RNumber.motionDurationPressIn) : RMotion.snappy, value: pressed)
        .sensoryFeedback(trigger: pressed) { _, now in now && variant == .primary ? RHaptic.press : nil }
    }
}

private struct PrimaryBody: ViewModifier {
    let enabled: Bool
    let pressed: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.rLit(pressed: pressed)
        } else {
            content.background(RColor.surfaceControl, in: Capsule())
        }
    }
}

/// Three dots that pulse in turn over a pending label.
private struct RPendingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate / RNumber.motionDurationTyping
            HStack(spacing: RDimension.space1) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
                        .opacity(reduceMotion ? 1 : 0.35 + 0.65 * pulse(t, index)) // literal-ok: pulse floor and range
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func pulse(_ time: Double, _ index: Int) -> Double {
        let phase = (time - Double(index) / 3).truncatingRemainder(dividingBy: 1)
        return phase < 0.5 ? phase * 2 : (1 - phase) * 2 // literal-ok: triangle wave over one cycle
    }
}

#if DEBUG
#Preview("buttons") {
    VStack(spacing: RDimension.space4) {
        RButton(title: "continue") {}
        RButton(title: "continue", status: .pending) {}
        RButton(title: "continue", status: .disabled(reason: "connect one source to continue")) {}
        RButton(title: "$24.99 / month", variant: .secondary) {}
        RButton(title: "later", variant: .text) {}
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
