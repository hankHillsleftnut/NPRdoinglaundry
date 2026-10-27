//
//  PodcastsPage.swift
//  V2.podcasts.a · PC-1 podcasts (Paper p-J-0 1FSA-0, approved 21 Oct): the tab page's inky title
//  bar (c:top-bar/title/rest 1FUX-0, nothing either side), then one scroll (1FTW-0: 24 margins, 12
//  from the bar, 32 between groups): this week's hero, and "earlier" over two columns of squares,
//  12 apart. Where the scroll meets the bottom it dissolves through the tab edge's progressive blur
//  (screen-rules 17; Paper's blurred copy 1FSW-0 is how Paper fakes it and is not built). At
//  accessibility sizes the squares go one to a row.
//  States Paper doesn't draw (loading, empty, error, offline) are debug-only scenarios
//  (`Debug/PodcastsUndrawnStates.swift`, founder 27 Oct: state screens live in the sandbox).
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

    /// Paper draws the library only. The other states (loading, empty, error, offline) are not drawn:
    /// the shipped page shows the canvas for them, and the debug launcher shows the founder-review
    /// lean (`PodcastsUndrawnStates`, debug builds only).
    @ViewBuilder private var content: some View {
        switch model.viewState {
        case let .content(library):
            scroll { libraryRows(library) }
        case let .offline(saved?):
            // what's saved stays on screen; the offline line over it is undrawn (debug only)
            #if DEBUG
            undrawn
            #else
            scroll { libraryRows(saved) }
            #endif
        case .loading, .empty, .offline, .failed:
            undrawn
        }
    }

    @ViewBuilder private var undrawn: some View {
        #if DEBUG
        PodcastsUndrawnStates(state: model.viewState, retry: { Task { await model.retry() } }, library: { library in
            scroll { libraryRows(library) }
        })
        #else
        Color.clear
        #endif
    }

    /// The library's scroll. It runs to the screen's bottom edge so the progressive blur's band
    /// covers the home-indicator strip too: the cards dissolve into the canvas instead of being cut
    /// by a hard line at the safe area (screen-rules 17; QA batch 1). At rest the last card still
    /// ends above the safe area (the bottom inset is kept as a content margin). In the shell the
    /// page ends at the tab bar, so the inset there is the bar's business (V2.tabbar-blend).
    private func scroll(@ViewBuilder _ rows: () -> some View) -> some View {
        // built here, outside the reader's escaping closure
        let column = VStack(alignment: .leading, spacing: RDimension.space8) {
            rows()
        }
        return GeometryReader { proxy in
            ScrollView {
                column
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .padding(.top, RDimension.space3)
                .padding(.bottom, RDimension.space8)
            }
            .contentMargins(.bottom, proxy.safeAreaInsets.bottom, for: .scrollContent)
            // the cards' shadows may spill sideways past the margins, but the cards never draw over
            // the title bar while they scroll
            .scrollClipDisabled()
            .mask { Rectangle().padding(.horizontal, -RDimension.spaceScreenMargin) }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height > geometry.containerSize.height
            } action: { _, now in
                overflows = now
            }
            .rProgressiveBlur(.tabEdge, active: overflows)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    @ViewBuilder private func libraryRows(_ library: PodcastsContent) -> some View {
        if let hero = library.hero {
            EpisodeHeroTile(hero: hero)
        }
        if !library.earlier.isEmpty {
            // Paper 1FTX-0: 12 from "earlier" to the squares; RSectionLabel brings 4 of it
            VStack(alignment: .leading, spacing: RDimension.space2) {
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
}
