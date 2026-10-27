//
//  PlanButton.swift
//  PW.paywall: "the plans are the buttons" (Paper ON-12 22MG-0). Two equal 52-tall pills, 12 apart:
//  c:button/secondary/plan-monthly 22MM-0 (background.raised, depth.boxShadow.paywall.planMonthly)
//  and c:button/lit/plan-yearly 22MH-0 (the glow.primary gradient, depth.boxShadow.paywall.planYearly,
//  halo kept on this screen: founder 26 Oct night, PW-Q4 A) with c:badge/save 22MI-0 straddling its top
//  edge. Label: the price (font-text text-md medium) then the period (text-md regular; text.secondary
//  on the monthly, the lit foreground at opacity.pending on the yearly), spacing-1 apart. The buttons
//  are dummies (no purchase): the model hands the choice on. The yearly one can nudge (see `rNudge`).
//
import SwiftUI

struct PlanButton: View {
    let plan: Flows.Plan
    /// The lit yearly plan (one lit object per screen) or the raised monthly one.
    let lit: Bool
    /// "save 20%", drawn on the lit plan only.
    var saving: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RDimension.space1) {
                Text(plan.displayPrice)
                    .rText(.textMdMedium)
                    .foregroundStyle(lit ? RColor.glowPrimaryForeground : RColor.textPrimary)
                Text("/ \(plan.period.rawValue)")
                    .rText(.textMd)
                    .foregroundStyle(lit ? RColor.glowPrimaryForeground : RColor.textSecondary)
                    .opacity(lit ? RNumber.opacityPending : 1)
            }
            .frame(maxWidth: .infinity, minHeight: RDimension.sizePlanButton)
            .background { surface }
            .overlay(alignment: .top) {
                // the badge's middle sits on the button's top edge (Paper top −11 on a 22 badge)
                if let saving, lit {
                    SaveBadge(text: saving)
                        .offset(y: -RDimension.sizeSaveBadgeHeight / 2)
                }
            }
            .contentShape(RShape.pill)
        }
        .rPress(haptic: lit ? RHaptic.press : nil)
        .accessibilityLabel(Self.spoken(plan: plan, saving: lit ? saving : nil))
    }

    @ViewBuilder private var surface: some View {
        if lit {
            RShape.pill
                .fill(LinearGradient(
                    colors: [RColor.glowPrimaryGradientTop, RColor.glowPrimaryGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .rBoxShadows(RElevation.boxShadowPaywallPlanYearly, radius: RDimension.radiusControl)
        } else {
            RShape.pill
                .fill(RColor.backgroundRaised)
                .rBoxShadows(RElevation.boxShadowPaywallPlanMonthly, radius: RDimension.radiusControl)
        }
    }

    /// "$239.99 per year, save 20%".
    static func spoken(plan: Flows.Plan, saving: String?) -> String {
        let price = "\(plan.displayPrice) per \(plan.period.rawValue)"
        return saving.map { "\(price), \($0)" } ?? price
    }
}

/// c:badge/save 22MI-0: 76×22, background.raised pill, a primary-ring hairline and contact; label
/// font-label text-sm medium accent.text. It is part of the lit plan (VoiceOver reads it there).
private struct SaveBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .rText(.pillAction)
            .foregroundStyle(RColor.accentText)
            .frame(minWidth: RDimension.sizeSaveBadgeWidth, minHeight: RDimension.sizeSaveBadgeHeight)
            .background(RColor.backgroundRaised, in: RShape.pill)
            .rBoxShadows(RElevation.boxShadowPaywallSaveBadge, radius: RDimension.radiusControl)
            .accessibilityHidden(true)
    }
}

// MARK: - The nudge (founder, 26 Oct night; scopes/PW.paywall.md §6a)

/// A barely visible nudge: 1.0 → motion.scale.nudge (rising on the standard curve over
/// motion.duration.fast) → 1.0 (settling on the snappy spring), with one selection haptic on the frame
/// the scale peaks. Each change of `trigger` nudges once; a tap during a nudge restarts it from where it
/// is. Reduce Motion: the haptic alone, nothing moves.
private struct RNudge<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @State private var scale: CGFloat = 1
    @State private var peaks = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else {
                    peaks += 1
                    return
                }
                withAnimation(RMotion.standard(RNumber.motionDurationFast)) {
                    scale = RNumber.motionScaleNudge
                } completion: {
                    peaks += 1
                    withAnimation(RMotion.snappy) { scale = 1 }
                }
            }
            .sensoryFeedback(RHaptic.select, trigger: peaks)
    }
}

extension View {
    /// The paywall's nudge of the lit plan (see `RNudge`).
    func rNudge(trigger: some Equatable) -> some View {
        modifier(RNudge(trigger: trigger))
    }
}
