//
//  BenefitRow.swift
//  PW.paywall: one c:benefit-row (Paper ON-12 22S1-0 …): a 56 art tile, some of them turned off axis
//  (founder c-ga3yqz), then the benefit in two lines. Row: gap spacing-4, padding block spacing-1,
//  centred. Title font-text text-body medium tracking-card leading-snug text.primary; line font-text
//  text-md regular leading-snug text.secondary; 2 apart. VoiceOver reads the row as one sentence.
//
import SwiftUI

extension RTextStyle {
    /// A paywall benefit's title (Paper 22S4-0: --font-text, --text-body, medium, --tracking-card, --leading-snug).
    static let benefitTitle = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .medium,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .body
    )
}

/// One benefit, as Paper words and draws it.
struct Benefit: Identifiable, Equatable {
    let tile: BenefitTileKind
    /// The tile's turn in degrees (Paper `rotate`): some are off axis.
    let turn: Double
    let title: String
    let line: String

    var id: String {
        title
    }

    /// Paper's six, in order (22S1-0, 22RN-0, 22RC-0, 22QY-0, 22QN-0, 22QA-0).
    static let paper: [Benefit] = [
        Benefit(tile: .brief, turn: -6, title: "wake up to what moved", line: "a 4-minute brief, made from yesterday"),
        Benefit(tile: .map, turn: 0, title: "see your life, connected", line: "the people and threads you return to"),
        Benefit(tile: .ask, turn: 5, title: "ask your life anything", line: "answers from your days, with sources"),
        Benefit(tile: .onTrack, turn: 0, title: "know if you're on track", line: "your goals, checked against your real days"),
        Benefit(tile: .podcast, turn: -5, title: "a podcast about your week", line: "every sunday, like the one you just heard"),
        Benefit(tile: .journal, turn: 0, title: "a journal that talks back", line: "talk or type; it asks what's next"),
    ]
}

struct BenefitRow: View {
    let benefit: Benefit

    var body: some View {
        HStack(spacing: RDimension.space4) {
            BenefitTile(kind: benefit.tile)
                .rotationEffect(.degrees(benefit.turn))
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(benefit.title)
                    .rText(.benefitTitle)
                    .foregroundStyle(RColor.textPrimary)
                Text(benefit.line)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RDimension.space1)
        .accessibilityElement(children: .combine)
    }
}
