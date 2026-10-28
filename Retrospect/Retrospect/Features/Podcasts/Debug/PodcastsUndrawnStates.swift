//
//  PodcastsUndrawnStates.swift
//  V2.podcasts.a · DEBUG ONLY. PC-1's states Paper doesn't draw (founder-review lean): loading (the
//  skeleton), empty, error (try again) and offline (the offline line over what's saved). Founder,
//  27 Oct: state screens are for testing in the sandbox (the launcher), never in the product, so
//  this file is compiled into debug builds only; the shipped page shows the canvas for them.
//
#if DEBUG
import SwiftUI

struct PodcastsUndrawnStates<Library: View>: View {
    static var emptyLine: String {
        "your episodes appear here every sunday."
    }

    static var errorLine: String {
        "the podcasts didn't load."
    }

    let state: PodcastsModel.ViewState
    let retry: () -> Void
    /// The page's own scroll of the library (for offline).
    @ViewBuilder let library: (PodcastsContent) -> Library

    var body: some View {
        switch state {
        case .loading:
            loading
        case .empty:
            REmptyLine(line: Self.emptyLine, symbol: RTab.podcasts.symbol)
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .frame(maxHeight: .infinity)
        case let .offline(content):
            VStack(alignment: .leading, spacing: RDimension.space3) {
                ROfflineLine(copy: .page)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                if let content {
                    library(content)
                }
            }
        case .failed:
            RErrorState(message: Self.errorLine, retry: retry)
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .frame(maxHeight: .infinity)
        case .content:
            EmptyView()
        }
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
#endif
