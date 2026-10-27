//
//  BriefItems.swift
//  V2.journal J3: JR-2's one-screen parts (components-gap §3: they stay in the feature).
//  `BriefItemNow` is c:brief-item/now (BI2-0; 1FO0-0 playing, GNY-0 played): a raised panel, 16 in,
//  8 between lines. `BriefItemNext` is one c:brief-item/next row (BHX-0/BHU-0): the part's number
//  and its words on a 44 row. `BriefQuietLine` is the quiet day's line and note (GSN-0).
//
import SwiftUI

extension RTextStyle {
    /// The now card's part (1FO0-0: the ink card face at --text-lg, tracking tight, leading snug).
    static let inkBriefPart = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeLg,
        weight: .regular,
        tracking: RNumber.fontTrackingTight,
        leading: 1.3,
        relativeTo: .headline
    )
    /// The quiet day's line (GSN-0: the ink card face at --text-2xl, tracking card, leading tight).
    static let inkBriefQuiet = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.1,
        relativeTo: .title
    )
}

/// The part playing now, or the last part once the brief has played.
struct BriefItemNow: View {
    let label: BriefSheetModel.NowLabel
    let place: String
    let part: BriefSheetContent.Part

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.words)
                    .rText(.briefLabel)
                    // "playing now" is the accent's one moment; "played" steps back to a label
                    .foregroundStyle(label == .playingNow ? RColor.accentText : RColor.textLabel)
                Spacer(minLength: RDimension.space2)
                Text(place)
                    .rText(.voiceLength)
                    .foregroundStyle(RColor.textLabel)
            }
            Text(part.title)
                .rText(.inkBriefPart)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let why = part.why {
                Text(why)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let source = part.source {
                // plain text: the source's destination isn't drawn (SCREEN-MAP row 53), so no chevron
                Text(source)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RDimension.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised(RDimension.radiusPanel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("brief.now")
    }
}

/// One part still to come.
struct BriefItemNext: View {
    let number: Int
    let words: String

    var body: some View {
        HStack(spacing: RDimension.space3) {
            Text("\(number)")
                .rText(.voiceLength)
                .foregroundStyle(RColor.textTertiary)
                .frame(width: RDimension.space4, alignment: .leading)
            Text(words)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, RDimension.space4)
        .frame(minHeight: RDimension.sizeRowCompact)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("brief.next.\(number)")
    }
}

/// The quiet day: one inky line and how short today's brief is, centred in the sheet's open space.
struct BriefQuietLine: View {
    let line: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text(line)
                .rText(.inkBriefQuiet)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(note)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("brief.quiet")
    }
}
