//
//  RClaim.swift
//  V2 lane 0 · components gap #3: the claim, the one thing Retro holds about you (Paper 02 · components,
//  part 41 "why this is here" G1E-0: c:claim/stated G2A-0, c:claim/asked G3C-0). Used by PC-3 (why this
//  is here), YO-4 (a node) and GL-2 (one goal), each with its evidence rows (REvidenceRow) under it.
//
//  Paper, 1:1:
//  - stated (G2A-0): the claim in the inky title (text-3xl, ink title, tracking-title, leading-tight,
//    balanced) over a meta line (Geist text-sm, text.label, leading-snug, no tracking), 8 apart
//    (space2). No surface: it is said plainly.
//  - asked (G3C-0): the guess look of guess-card.md. inference.surface, radius.card, a 1pt dashed
//    inference.border edge inside, padding 16 (space4), 8 between lines: "a guess" (Geist text-sm
//    medium, text.label), the question in the inky card face at text-2xl (`.inkClaimAsked`), and the
//    meta line. Status is never colour alone: the dash and the words "a guess" both say it.
//  Increase Contrast thickens the dash (size.inference.edgeIncreased): the asked look is the guess card's
//  own paper, `RInferenceSurface` (RTag.swift), so a change to one reaches both.
//
import SwiftUI

extension RTextStyle {
    /// The asked claim's question (G3E-0: --font-display-inky, --text-2xl, --font-weight-ink-card,
    /// --tracking-card, --leading-tight). The inky card face one size up from `.inkCard`.
    static let inkClaimAsked = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.1,
        relativeTo: .title
    )

    /// "a guess" (G3D-0: Geist text-sm medium, leading-snug, no tracking).
    static let claimGuessLabel = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption
    )
}

struct RClaim: View {
    enum Kind: Equatable {
        /// Retro says it: "your best days start early."
        case stated
        /// Retro asks it: "are mornings when you do your best work?"
        case asked
    }

    let kind: Kind
    /// The claim or the question, in content's own case.
    let text: String
    /// "stated · from what you did · very sure"; "asked · fairly sure · rests on 3 mornings".
    let meta: String
    /// The stated claim's face: the master part draws it at text-3xl (`.inkTitle`); a screen that draws
    /// it smaller passes its own (YO-4 1GDU-0: text-2xl). Additive, `.inkTitle` by default.
    var statedStyle: RTextStyle = .inkTitle
    /// Balanced wrapping for the stated claim (CSS `text-wrap: balance`, as Paper sets YO-4's belief 1GDU-0):
    /// the lines even out instead of leaving one word alone on the last. Additive, off by default: the
    /// master (G2A-0) is balanced too, but PC-3 and GL-2 were compared with Paper ragged, so flipping the
    /// default here would move their lines without a side-by-side. YO-4 opts in; the other two are on the
    /// polish list (docs/team/polish-list.md) to opt in, or flip the default, against their own stills.
    var balanced = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        switch kind {
        case .stated:
            VStack(alignment: .leading, spacing: RDimension.space2) {
                statedText
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .asked:
            VStack(alignment: .leading, spacing: RDimension.space2) {
                Text("a guess")
                    .rText(.claimGuessLabel)
                    .foregroundStyle(RColor.textLabel)
                Text(text)
                    .rText(.inkClaimAsked)
                    .foregroundStyle(RColor.textPrimary)
                    // a long question never truncates in a height-bound slot (as the guess card's)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RDimension.space4)
            .background { RInferenceSurface(increasedContrast: contrast == .increased) }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var statedText: some View {
        let words = Text(text)
            .rText(statedStyle)
            .foregroundStyle(RColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
        if balanced {
            words.rBalancedLines()
        } else {
            words
        }
    }

    private var metaLine: some View {
        Text(meta)
            .rText(.metaLine)
            .foregroundStyle(contrast == .increased ? RColor.textSecondary : RColor.textLabel)
            .accessibilityLabel(spokenMeta)
    }

    /// What VoiceOver reads for the meta line: commas, not dots (as RGuessCard and REvidenceRow).
    var spokenMeta: String {
        meta.replacingOccurrences(of: " · ", with: ", ")
    }
}

#if DEBUG
/// Lab page "claim": both kinds with Paper's copy (G2A-0, G3C-0), then a long claim to wrap.
struct RClaimGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                Text("claim · stated").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RClaim(kind: .stated, text: "your best days start early.", meta: "stated · from what you did · very sure")
                Text("claim · asked").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RClaim(
                    kind: .asked,
                    text: "are mornings when you do your best work?",
                    meta: "asked · fairly sure · rests on 3 mornings"
                )
                Text("long").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                RClaim(
                    kind: .asked,
                    text: "is the week after a demo when you sleep least, and does it start on the sunday?",
                    meta: "asked · a little sure · rests on 2 weeks"
                )
            }
            .frame(maxWidth: RDimension.layoutReadingWidth)
            .padding(RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("claim") { RClaimGallery() }
#endif
