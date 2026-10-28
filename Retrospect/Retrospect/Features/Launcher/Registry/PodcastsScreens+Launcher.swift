//
//  PodcastsScreens+Launcher.swift
//  V2 lane 2 (plan-v2.md §3): PC-1 podcasts and PC-3 why this is here, opened with
//  `-Screen PC-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//  The player sheet (PC-2 / ON-11) is the core flow's and registers in its own feature folder.
//  PC-1 (V2.podcasts.a): `rest` is Paper 1FSA-0; `loading`, `empty`, `error`, `offline` are the
//  states Paper doesn't draw (founder-review lean), on the sample library.
//
#if DEBUG
import SwiftUI

enum PodcastsScreens: ScreenGroup {
    static let name = "podcasts"
    /// PC-2 in episode mode (V2.podcasts.c) registers from its own file.
    static let screens: [LaunchableScreen] = ScreenRegistry.podcastsPlayerScreens + [
        LaunchableScreen(id: "PC-1", states: PodcastsScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(PodcastsLaunch(scenario: PodcastsScenario(rawValue: arguments.state) ?? .rest))
        },
    ]
}

/// PC-1 on the sample library.
struct PodcastsLaunch: View {
    @State private var model: PodcastsModel

    init(scenario: PodcastsScenario) {
        _model = State(initialValue: PodcastsModel(data: SamplePodcastsData(scenario: scenario), words: SamplePodcastsData.words))
    }

    var body: some View {
        PodcastsPage(model: model)
    }
}

#Preview("PC-1 · rest") { PodcastsLaunch(scenario: .rest) }
#Preview("PC-1 · loading") { PodcastsLaunch(scenario: .loading) }
#Preview("PC-1 · empty") { PodcastsLaunch(scenario: .empty) }
#Preview("PC-1 · error") { PodcastsLaunch(scenario: .error) }
#Preview("PC-1 · offline") { PodcastsLaunch(scenario: .offline) }
#endif
