//
//  SetupRecapCard.swift
//  FH.home: c:entry/setup-recap (Paper ON-13 1FJ6-0), what you told Retro while setting up. A raised
//  card (background.raised, radius.card; top light, 0.5 hairline, contact 0 1 2, cast 0 10 24 −12),
//  padded spacing-5 with spacing-3 between: the header ("what you told retro while setting up", Geist
//  text-sm medium, and "9 answers", Geist text-sm, both text.label, baseline, apart), then the lines
//  (display-inky text-body, ink card, tracking card, leading snug, text.primary), spacing-2 apart.
//  "see all 9" (1FJ7-0) is HIDDEN until its destination is drawn (DECISIONS 8). On a short screen (SE)
//  the third line goes (handoff: "SE shows two recap lines"). VoiceOver reads the card as one.
//
import SwiftUI

extension RTextStyle {
    /// A recap line (Paper 1FJB-0: --font-display-inky, --text-body, ink-card, --tracking-card, --leading-snug).
    static let recapLine = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.body.leading,
        relativeTo: .body
    )
    /// The recap's header (Paper 1FJE-0 / 1FJD-0: --font-label, --text-sm, leading snug, no tracking).
    static let recapHeader = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.body.leading,
        relativeTo: .caption
    )
}

struct SetupRecapCard: View {
    let recap: SetupRecap
    @Environment(\.rCompactHeight) private var compactHeight

    /// The lines shown: all of them, or two on a short screen.
    static func shown(_ lines: [String], compact: Bool) -> [String] {
        compact ? Array(lines.prefix(2)) : lines
    }

    var body: some View {
        let lines = Self.shown(recap.lines, compact: compactHeight)
        VStack(alignment: .leading, spacing: RDimension.space3) {
            HStack(alignment: .firstTextBaseline, spacing: RDimension.space3) {
                Text(FirstDay.recapTitle)
                    .rText(.recapHeader)
                    .foregroundStyle(RColor.textLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(recap.countLine)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: RDimension.space2) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .rText(.recapLine)
                        .foregroundStyle(RColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(RDimension.space5)
        .background(RColor.backgroundRaised, in: RShape.rect(RDimension.radiusCard))
        .rBoxShadows(RElevation.boxShadowFirstHomeRecap, radius: RDimension.radiusCard)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("firstHome.recap")
    }
}
