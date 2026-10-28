//
//  ShareItemCard.swift
//  V2.outside · EX-1's item card (Paper c:share/item-card 1H1Z-0; one screen only, so page-private).
//  Raised paper, radius.card: "the thing" (16 in, 12 between: 56 artwork, its title in SF 14 semibold
//  on one line over the source in Geist 12), then a 1pt border.subtle line and "retro's read" (16 in,
//  8 between): the label, Retro's one line in the inky card face, and "goes with" + the goal pill.
//  Paper's "change" (the goal picker) isn't drawn behind, so it is hidden (EX-D3); the goal pill
//  is a label, not a button, until then.
//
import SwiftUI

extension RTextStyle {
    /// The shared thing's title: SF 14 semibold, leading snug (1H2B-0).
    static let shareItemTitle = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .semibold,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.textMd.leading,
        relativeTo: .subheadline
    )
}

struct ShareItemCard: View {
    let item: ShareItem

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            thing
            (RColor.borderSubtle)
                .frame(height: RDimension.sizeBorderDefault)
                .accessibilityHidden(true)
            read
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised()
    }

    private var thing: some View {
        HStack(spacing: RDimension.space3) {
            RArtwork(recipe: RArtworkRecipes.quiet, size: RDimension.sizeArtworkShareItem)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                Text(item.title)
                    .rText(.shareItemTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(1)
                Text(item.source)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RDimension.space4)
        .accessibilityElement(children: .combine)
    }

    private var read: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text("retro's read")
                .rText(.claimGuessLabel)
                .foregroundStyle(RColor.textLabel)
            Text(item.read)
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let goal = item.goal {
                HStack(spacing: RDimension.space2) {
                    Text("goes with")
                        .rText(.metaLine)
                        .foregroundStyle(RColor.textLabel)
                    Text(goal)
                        .rText(.pill)
                        .foregroundStyle(RColor.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, RDimension.space3)
                        .frame(minHeight: RDimension.sizeControlSmall)
                        .background(RColor.surfaceWash, in: RShape.pill)
                }
                .padding(.top, RDimension.space2)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(RDimension.space4)
    }
}
