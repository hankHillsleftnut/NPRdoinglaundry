//
//  EntryDrawnParts.swift
//  V2.journal J2b: JR-4's one-screen drawn parts (components-gap §3: they stay in the feature).
//  - `TookSectionView` (N56-0 / N7W-0): "what i took from this", 8 above its rows or its quiet line.
//  - `TookRow` claim (c:took-row/claim E35-0): a raised panel, radius.panel, min 56, 8 × 16 / 12 in,
//    the claim in SF md text.primary, and "not right" as a neutral pill in a 44 slot.
//  - `TookRow` noted (E3C-0): on wash, the claim struck in text.tertiary, a 14 tick and "noted".
//    "not right" strikes the claim and notes it in motion.duration.expand (240 ms); Reduce Motion fades.
//  - `DestructiveRow` (c:row/destructive E3J-0): "delete entry", Geist md medium danger text, a 44 row.
//
import SwiftUI

struct TookSectionView: View {
    let section: TookSection
    let notRight: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text(EntryDrawnModel.tookTitle)
                .rText(.briefLabelTook)
                .foregroundStyle(RColor.textLabel)
                .accessibilityAddTraits(.isHeader)
            switch section {
            case let .claims(claims):
                ForEach(claims) { claim in
                    TookRow(claim: claim) { notRight(claim.id) }
                }
            case .notReadYet, .notSentYet:
                Text(section.line ?? "")
                    .rText(.textMd)
                    .foregroundStyle(RColor.textTertiary)
                    .padding(.vertical, RDimension.space1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("entry.took")
    }
}

struct TookRow: View {
    let claim: TookClaim
    let notRight: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: RDimension.space3) {
            Text(claim.words)
                .rText(.textMd)
                .foregroundStyle(claim.noted ? RColor.textTertiary : RColor.textPrimary)
                .strikethrough(claim.noted, color: RColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            trailing
                .frame(minHeight: RDimension.sizeTouchTarget)
        }
        .padding(.vertical, RDimension.space2)
        .padding(.leading, RDimension.space4)
        .padding(.trailing, RDimension.space3)
        .frame(minHeight: RDimension.sizeTouchTarget + RDimension.space3, alignment: .leading)
        .background { surface }
        .animation(RMotion.standard(reduceMotion ? RNumber.motionDurationFast : RNumber.motionDurationExpand), value: claim.noted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entry.took.\(claim.id)")
    }

    @ViewBuilder private var trailing: some View {
        if claim.noted {
            HStack(spacing: RDimension.space1) {
                RSymbol(
                    name: "checkmark",
                    size: .small,
                    tint: RColor.iconMuted,
                    weight: .medium,
                    glyphScale: 0.7
                ) // literal-ok: Paper's 14 tick in the 16 frame
                Text("noted")
                    .rText(.tookNoted)
                    .foregroundStyle(RColor.textLabel)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("noted")
            .transition(.opacity)
        } else {
            RPill(title: "not right", symbol: "text.bubble", style: .neutral, action: notRight)
                .accessibilityHint("tells retro this isn't right")
                .accessibilityIdentifier("entry.notRight")
                .transition(.opacity)
        }
    }

    @ViewBuilder private var surface: some View {
        if claim.noted {
            RShape.rect(RDimension.radiusPanel).fill(RColor.surfaceWash)
        } else {
            Color.clear.rRaised(RDimension.radiusPanel)
        }
    }
}

struct DestructiveRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .rText(.destructiveRow)
                .foregroundStyle(RColor.statusDangerText)
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
        }
        .rPress(small: true)
        .accessibilityIdentifier("entry.delete")
    }
}

extension RTextStyle {
    /// "what i took from this" (N5K-0: Geist sm medium, snug, no tracking).
    static let briefLabelTook = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption
    )
    /// "noted" (N59-0: Geist md regular, snug).
    static let tookNoted = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
    /// "delete entry" (N54-0: Geist md medium, snug).
    static let destructiveRow = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}
