//
//  EpisodeTiles.swift
//  V2.podcasts.a · PC-1's two tiles (Paper 02 · components part 40 FWU-0: c:episode-tile/hero/rest
//  FXR-0, c:episode-tile/square/rest FYG-0; in use on 1FSA-0 as 1FUK-0 and 1FUE-0 …). Used by PC-1
//  only, so they live in the podcasts folder (components-gap §3).
//  Hero: one raised card (radius.card, padding 8, 12 between its parts, the full depth stack with the
//  ambient shadow), the episode's mesh panel (radius.panel, 180; 132 on a short phone) with its
//  corner line in white, the 44 lit play on the panel's seam 16 from the trailing edge, then the
//  inky title (2xl, 48 kept clear for the play) and one plain line.
//  Square: the same card without the ambient shadow, padding 8, 8 between the square mesh and the
//  words, 4 between the inky title (base, two lines at most) and the date line.
//
import SwiftUI

extension RTextStyle {
    /// The hero's title (Paper 1FUO-0: display-inky, --text-2xl, ink card, tracking card, leading tight).
    static let episodeHeroTitle = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.inkCard.leading,
        relativeTo: .title
    )
    /// A square's title (Paper 1FUH-0: display-inky, --text-base, ink card, tracking card, leading tight).
    static let episodeTileTitle = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeBase,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.inkCard.leading,
        relativeTo: .headline
    )
}

extension EpisodeArt {
    var recipe: RArtworkRecipe {
        switch self {
        // Paper 1FUP-0's dark brown to amber (QA batch 6); the shared `weekly` renders a lighter wash (PCD-15)
        case .weekly: RArtworkRecipes.weeklyLibrary
        case .brief: RArtworkRecipes.brief
        case .first: RArtworkRecipes.first
        case .calls: RArtworkRecipes.calls
        }
    }
}

/// The mesh filling whatever frame it's given.
private struct EpisodeArtwork: View {
    let art: EpisodeArt

    var body: some View {
        GeometryReader { proxy in
            RArtwork(recipe: art.recipe, width: proxy.size.width, height: proxy.size.height, cornerRadius: RDimension.radiusPanel)
        }
        .accessibilityHidden(true)
    }
}

struct EpisodeHeroTile: View {
    let hero: EpisodeHero

    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Paper 1FUP-0: 180; on a short phone the brief card's panel height, so the squares stay in view.
    static let panelHeight: CGFloat = 180 // literal-ok: Paper 1FUP-0

    private var panelHeight: CGFloat {
        compactHeight ? RBriefCard.panelHeight : Self.panelHeight
    }

    private var accessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            // the card's words are one element; the play stays its own, so VoiceOver reaches it
            // and hears that it isn't available yet
            VStack(alignment: .leading, spacing: RDimension.space3) {
                panel
                words
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spoken)
            .accessibilityIdentifier("podcasts.hero")
            if accessibilitySize {
                // at accessibility sizes the play moves under the words, as the brief card's does
                EpisodePlayPlaceholder()
                    .padding(.leading, RDimension.space2)
                    .padding(.vertical, RDimension.space2)
            }
        }
        .padding(RDimension.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised(RDimension.radiusCard)
        .overlay(alignment: .topTrailing) {
            // on the seam: half of it hangs below the panel (Paper 1FUQ-0: bottom −22, right 16)
            if !accessibilitySize {
                EpisodePlayPlaceholder()
                    .padding(.trailing, RDimension.space2 + RDimension.space4)
                    .offset(y: RDimension.space2 + panelHeight - RDimension.sizeControlDefault / 2)
            }
        }
    }

    private var spoken: String {
        [hero.title, hero.label.replacingOccurrences(of: " · ", with: ", "), hero.subline]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    private var panel: some View {
        EpisodeArtwork(art: hero.art)
            .frame(height: panelHeight)
            .overlay(alignment: .topLeading) {
                Text(hero.label)
                    .rText(.briefLabel)
                    .foregroundStyle(RColor.glowPrimaryForeground)
                    .padding(.leading, RDimension.space4)
                    .padding(.top, RDimension.space3)
            }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            Text(hero.title)
                .rText(.episodeHeroTitle)
                .foregroundStyle(RColor.textPrimary)
                .rBalancedLines()
                .fixedSize(horizontal: false, vertical: true)
                // 48 clear on the trailing side so the title never runs under the play (Paper 1FUN-0)
                .padding(.trailing, accessibilitySize ? RDimension.space0 : RDimension.space12)
            if let subline = hero.subline {
                Text(subline)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RDimension.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The hero's 44 lit play (Paper c:button/lit/play 1FUR-0), drawn ahead of the player and the shared
/// lit play button (V2.playbutton, after #201): the lit face from the design system's `rLit`, not a
/// button, and VoiceOver says it isn't available yet. V2.podcasts.d swaps it for the shared button.
struct EpisodePlayPlaceholder: View {
    var body: some View {
        RSymbol(name: "play.fill", size: .regular, tint: RColor.glowPrimaryForeground, glyphScale: RSymbol.playGlyphScale)
            .frame(width: RDimension.sizeControlDefault, height: RDimension.sizeControlDefault)
            .background { Color.clear.rLit(RDimension.radiusControl) }
            .accessibilityElement()
            .accessibilityLabel("play")
            .accessibilityValue(PodcastsModel.notAvailableYet)
            .accessibilityIdentifier("podcasts.hero.play")
    }
}

struct EpisodeSquareTile: View {
    let square: EpisodeSquare

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            EpisodeArtwork(art: square.art)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: RDimension.space1) {
                Text(square.title)
                    .rText(.episodeTileTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(square.meta)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
            }
            .padding(.horizontal, RDimension.space1)
            .padding(.top, RDimension.space1)
            .padding(.bottom, RDimension.space2)
        }
        .padding(RDimension.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rRaised(RDimension.radiusCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(square.title), \(square.meta.replacingOccurrences(of: " · ", with: ", "))")
        .accessibilityIdentifier("podcasts.square.\(square.id)")
    }
}
