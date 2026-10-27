//
//  GoalCard.swift
//  V2.goals · GL-1's goal card (Paper c:goal-card/rest 1G2R-0 / 1G2D-0, c:goal-card/too early 1G21-0;
//  part 48 ITY-0). Raised paper (background.raised, the card depth stack), radius.card, padding 16 top
//  and 20 at the sides and bottom, 12 between parts: the goal in SF 17 semibold, the said/did bars, and
//  Retro's one line in SF 14 secondary. No red, no %, no streaks: the gap is shown plainly (part 48).
//  The whole card opens the goal (GL-2); with nowhere to open (`open` nil) it is plain, not a button.
//
import SwiftUI

extension RTextStyle {
    /// The goal on a card: SF 17 semibold, tracking-card, leading snug (1G34-0).
    static let goalCardTitle = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .semibold,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.textMd.leading,
        relativeTo: .headline
    )

    /// "said", "did": Geist Mono 11, tracking-label, leading snug (1G33-0).
    static let goalMeasureName = RTextStyle(
        family: .mono,
        size: RDimension.fontSizeXs,
        weight: .regular,
        tracking: RNumber.fontTrackingLabel,
        leading: RTextStyle.textMd.leading,
        relativeTo: .caption2
    )
}

struct GoalCard: View {
    let goal: GoalSummary
    var open: (() -> Void)?

    var body: some View {
        if let open {
            Button(action: open) { card }
                .buttonStyle(GoalCardPressStyle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityText)
                .accessibilityHint("opens the goal")
        } else {
            card
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(goal.title)
                .rText(.goalCardTitle)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.leading)
            GoalSaidDid(said: goal.said, did: goal.did)
            Text(goal.line)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, RDimension.space4)
        .padding([.horizontal, .bottom], RDimension.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised()
        .contentShape(RShape.rect(RDimension.radiusCard))
    }

    private var accessibilityText: String {
        let did = goal.did.map { "did \($0.label)" } ?? "did: too early to tell"
        return "\(goal.title). said \(goal.said.label), \(did). \(goal.line)"
    }
}

/// The said and did rows (1G2T-0, gap 8). Each: the word in its 28 slot (a minimum: it grows with Dynamic Type), the 4pt track (surface.track)
/// with its fill (goal.said; did in ink, GL-D13), the count in a 64 slot, right-aligned, 12 between. Too early:
/// "too early to tell" in the bar's place (1G25-0). At accessibility sizes the fixed slots can't hold
/// the words, so the word and count sit on one line over a full-width bar.
struct GoalSaidDid: View {
    let said: GoalMeasure
    let did: GoalMeasure?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            row(name: "said", measure: said, fill: RColor.goalSaid)
            if let did {
                // ink, not goal.did's blue: blue is the active colour only (founder 27 Oct, GL-D13)
                row(name: "did", measure: did, fill: RColor.textPrimary)
            } else {
                tooEarly
            }
        }
        .accessibilityElement(children: .ignore)
    }

    @ViewBuilder private func row(name: String, measure: GoalMeasure, fill: Color) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: RDimension.space1) {
                HStack {
                    nameText(name)
                    Spacer(minLength: RDimension.space2)
                    countText(measure.label)
                }
                GoalBar(fraction: measure.fraction, fill: fill)
            }
        } else {
            HStack(spacing: RDimension.space3) {
                nameText(name)
                    .frame(minWidth: RDimension.sizeGoalLabel, alignment: .leading)
                GoalBar(fraction: measure.fraction, fill: fill)
                countText(measure.label)
                    .frame(width: RDimension.sizeGoalCount, alignment: .trailing)
            }
        }
    }

    private var tooEarly: some View {
        HStack(spacing: RDimension.space3) {
            nameText("did")
                .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : RDimension.sizeGoalLabel, alignment: .leading)
            Text("too early to tell")
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nameText(_ name: String) -> some View {
        Text(name)
            .rText(.goalMeasureName)
            .foregroundStyle(RColor.textLabel)
            .lineLimit(1)
            .fixedSize()
    }

    private func countText(_ label: String) -> some View {
        Text(label)
            .rText(.metaLine)
            .foregroundStyle(RColor.textSecondary)
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
    }
}

/// One 4pt bar: the track, and the fill at its share (Paper rounds the width to the point).
struct GoalBar: View {
    let fraction: Double
    let fill: Color

    var body: some View {
        RShape.rect(RDimension.radiusControl)
            .fill(RColor.surfaceTrack)
            .frame(height: RDimension.sizeGoalTrack)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RShape.rect(RDimension.radiusControl)
                        .fill(fill)
                        .frame(width: (proxy.size.width * Self.clamped(fraction)).rounded())
                }
            }
            .clipShape(RShape.rect(RDimension.radiusControl))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    static func clamped(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }
}

/// The card dims a touch while held (opacity.pressed), in fast, out slower; no scale on a whole card.
private struct GoalCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}
