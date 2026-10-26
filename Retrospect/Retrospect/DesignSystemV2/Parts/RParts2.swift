//
//  RParts2.swift
//  M14 sub-components, group 2 (S07, S08, S09): the onboarding progress hairline,
//  the knows-you track (and C36, the meter built on it) and the small syncing spinner. Values from the approved ON-6
//  board (c:onboarding-progress, c:knows-you-meter) and ST-3 (syncing); tokens only.
//
import SwiftUI

// MARK: - S07 · Progress hairline

/// The onboarding progress line: a 3pt track with an ink fill that advances on the
/// map spring, one step at a time (never a percentage readout).
struct RProgressHairline: View {
    /// 0…1
    let fraction: Double
    private var clamped: Double {
        fraction.clamped01
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RShape.rect(RDimension.radiusSmall)
                    .fill(RColor.surfaceTrack)
                RShape.rect(RDimension.radiusSmall)
                    .fill(RColor.inkDefault)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: RDimension.sizeProgress)
        .animation(RMotion.map, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("progress")
        .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - S08 · Knows-you track

/// The lit track behind the knows-you meter: a 4pt pill whose fill carries the
/// primary glow and moves on the move curve (meter fills one step per source).
struct RKnowsYouTrack: View {
    /// 0…1
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var clamped: Double {
        fraction.clamped01
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RShape.pill.fill(RColor.surfaceTrack)
                RShape.pill
                    .fill(LinearGradient(
                        colors: [RColor.glowPrimaryGradientTop, RColor.glowPrimaryGradientBottom],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * clamped)
                    // Paper 21C4-0: glow.primary.halo 0 0 6 (a CSS blur of 6 is a SwiftUI radius of 3)
                    .shadow(color: RColor.glowPrimaryHalo, radius: RDimension.sizeMeter * 0.75) // literal-ok: half of Paper's 6 blur
            }
        }
        .frame(height: RDimension.sizeMeter)
        // a step travels on curve.move over 420; Reduce Motion: it lands in a short 140 instead
        .animation(
            reduceMotion
                ? RMotion.standard(RNumber.motionDurationFast)
                : RMotion.move(RNumber.motionDurationTranscriptFollow),
            value: fraction
        )
        .accessibilityHidden(true)
    }
}

// MARK: - C36 · Knows-you meter

extension RTextStyle {
    /// The meter's words (Paper 21C2-0): Geist 12 medium, leading snug, and no tracking (Paper sets
    /// none here, unlike the section labels' --tracking-label).
    static let meterLabel = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.labelMedium.leading,
        relativeTo: .caption
    )
}

/// The knows-you meter (Paper `c:knows-you-meter/1-of-6`, 21C1-0): the lit track, then its words
/// on the right ("knows you a little"), 12 apart, 4 above. The track fills one step on curve.move
/// (motion-system "Knows-you meter"); the words blur-replace when they change. At accessibility
/// sizes the words go under the track so neither is squeezed. One element for VoiceOver: the words.
struct RKnowsYouMeter: View {
    /// 0…1
    let fraction: Double
    let label: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let parts = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space2))
            : AnyLayout(HStackLayout(spacing: RDimension.space3))
        parts {
            RKnowsYouTrack(fraction: fraction)
                .frame(maxWidth: .infinity)
            Text(label)
                .rText(.meterLabel)
                .foregroundStyle(RColor.textLabel)
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                .contentTransition(.interpolate)
                .animation(RMotion.standard(RNumber.motionDurationBase), value: label)
        }
        .padding(.top, RDimension.space1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

// MARK: - S09 · Spinner

/// The small syncing spinner: a track ring with a quarter arc that turns once per
/// motion.duration.spin. Under Reduce Motion it holds still.
struct RSpinner: View {
    var diameter: CGFloat = RDimension.sizeStepDot
    @State private var turning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Both strokes sit inside the frame, so the spinner is exactly the dot's size.
            Circle().strokeBorder(RColor.borderStrong, lineWidth: diameter / 4)
            Circle()
                .inset(by: diameter / 8)
                .trim(from: 0, to: 0.25)
                .stroke(RColor.textSecondary, style: StrokeStyle(lineWidth: diameter / 4, lineCap: .round))
                .rotationEffect(.degrees(turning ? 360 : 0))
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(RMotion.spin) {
                turning = true
            }
        }
        .accessibilityLabel("syncing")
    }
}

#if DEBUG
struct RParts2Gallery: View {
    @State private var step = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            RProgressHairline(fraction: step / 6)
            RKnowsYouTrack(fraction: step / 6)
            RKnowsYouMeter(fraction: step / 6, label: "knows you a little")
            HStack(spacing: RDimension.space3) {
                RSpinner()
                RSpinner(diameter: RDimension.sizeIconDefault)
            }
            Button("next step") { step = step >= 6 ? 1 : step + 1 }
                .rText(.pill)
                .padding(.horizontal, RDimension.space3)
                .frame(height: RDimension.sizeSourceIcon)
                .rSecondary()
                .rPress(small: true, haptic: RHaptic.select)
        }
        .padding(RDimension.spaceScreenMargin)
        .foregroundStyle(RColor.textPrimary)
    }
}

#Preview("parts 2") { RParts2Gallery() }
#endif

private extension Double {
    /// Clamped to 0…1.
    var clamped01: Double {
        Swift.min(Swift.max(self, .zero), 1)
    }
}
