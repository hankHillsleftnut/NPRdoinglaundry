//
//  EpisodeMomentCard.swift
//  V2.podcasts.b · c:episode-moment/rest (Paper 1FY2-0, used by PC-3 only, so it lives here): where in
//  the episode Retro says it. A raised panel (radius.panel, padding 16, 12 between its parts) holding
//  the line in the inky face (--text-xl, ink card) and, under it, the episode's 32 mesh (radius
//  default), "at 4:12 in this week's" and the "hear it" pill.
//
import SwiftUI

struct EpisodeMomentCard: View {
    let moment: WhyThisIsHere.Moment
    /// nil until the player hosts the page: the pill is disabled and says why.
    let hearIt: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(moment.quote)
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: RDimension.space2))
                : AnyLayout(HStackLayout(spacing: RDimension.space3))
            layout {
                HStack(spacing: RDimension.space3) {
                    RArtwork(
                        recipe: RArtworkRecipes.weekly,
                        width: RDimension.sizeControlSmall,
                        height: RDimension.sizeControlSmall,
                        cornerRadius: RDimension.radiusDefault
                    )
                    Text(moment.at)
                        .rText(.metaLine)
                        .foregroundStyle(RColor.textLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                RPill(
                    title: "hear it",
                    symbol: "play.fill",
                    disabledReason: hearIt == nil ? WhyThisIsHereModel.notAvailableYet : nil
                ) { hearIt?() }
                .accessibilityLabel("hear it, \(moment.at)")
                .accessibilityIdentifier("why.hearIt")
            }
        }
        .padding(RDimension.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised(RDimension.radiusPanel)
    }
}
