//
//  PodcastsPage.swift
//  V2.podcasts.a · PC-1 podcasts (Paper p-J-0 1FSA-0, approved 21 Oct): the tab page's inky title
//  bar (c:top-bar/title/rest 1FUX-0, nothing either side), then one scroll (1FTW-0: 24 margins, 12
//  from the bar, 32 between groups): this week's hero, and "earlier" over two columns of squares,
//  12 apart. Where the scroll meets the bottom it dissolves through the tab edge's progressive blur
//  (screen-rules 17; Paper's blurred copy 1FSW-0 is how Paper fakes it and is not built). At
//  accessibility sizes the squares go one to a row.
//  States Paper doesn't draw (founder-review lean, listed in the PR): loading (the skeleton),
//  empty, error (try again) and offline (the offline line over what's saved).
//  Dark: reachable only from the launcher; the tab bar is the shell's, mounted by a wiring PR.
//
import SwiftUI

struct PodcastsPage: View {
    let model: PodcastsModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var overflows = false

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .title(title: "podcasts", trailing: .none))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast), value: model.viewState)
        .task { await model.load() }
        .accessibilityIdentifier("podcasts")
    }

    @ViewBuilder private var content: some View {
        switch model.viewState {
        case .loading:
            loading
        case let .content(library):
            scroll { libraryRows(library) }
        case .empty:
            REmptyLine(line: PodcastsModel.emptyLine, symbol: RTab.podcasts.symbol)
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .frame(maxHeight: .infinity)
        case let .offline(library):
            scroll {
                ROfflineLine(copy: .page)
                if let library {
                    libraryRows(library)
                }
            }
        case .failed:
            RErrorState(message: PodcastsModel.errorLine) {
                Task { await model.retry() }
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .frame(maxHeight: .infinity)
        }
    }

    private func scroll(@ViewBuilder _ rows: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                rows()
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .padding(.top, RDimension.space3)
            .padding(.bottom, RDimension.space8)
        }
        .scrollClipDisabled()
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentSize.height > geometry.containerSize.height
        } action: { _, now in
            overflows = now
        }
        .rProgressiveBlur(.tabEdge, active: overflows)
    }

    @ViewBuilder private func libraryRows(_ library: PodcastsContent) -> some View {
        if let hero = library.hero {
            EpisodeHeroTile(hero: hero)
        }
        if !library.earlier.isEmpty {
            VStack(alignment: .leading, spacing: RDimension.space3) {
                RSectionLabel(title: "earlier")
                LazyVGrid(columns: columns, alignment: .leading, spacing: RDimension.space3) {
                    ForEach(library.earlier) { square in
                        EpisodeSquareTile(square: square)
                    }
                }
            }
        }
    }

    /// Two columns 12 apart (Paper 1FTY-0); one at accessibility sizes.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: RDimension.space3, alignment: .top), count: count)
    }

    /// The hero and two squares in skeleton bars, while the first load is out.
    private var loading: some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            RSkeleton(bars: [nil, nil, nil, nil, nil, nil, RDimension.layoutReadingWidth * 0.6]) // literal-ok: the hero's shape
            RSkeleton(bars: [nil, nil, nil, nil])
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space3)
        .accessibilityElement()
        .accessibilityLabel("loading your podcasts")
        .accessibilityIdentifier("podcasts.loading")
    }
}
