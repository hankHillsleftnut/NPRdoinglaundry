//
//  PodcastsScreens+Launcher.swift
//  V2 lane 2 (plan-v2.md §3): PC-1 podcasts and PC-3 why this is here, opened with
//  `-Screen PC-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//  The player sheet (PC-2 / ON-11) is the core flow's and registers in its own feature folder.
//  PC-1 (V2.podcasts.a): `rest` is Paper 1FSA-0; `loading`, `empty`, `error`, `offline` are the
//  states Paper doesn't draw (founder-review lean), on the sample library.
//  PC-3 (V2.podcasts.b): `asked` (1FXG-0 = 05 NDK-0) and `stated` (05 NBD-0) as drawn; `more` and
//  `nothing-yet` not drawn (founder-review lean). It stands on the player's sheet (PlayerSheetScreen).
//
#if DEBUG
import SwiftUI

enum PodcastsScreens: ScreenGroup {
    static let name = "podcasts"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "PC-1", states: PodcastsScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(PodcastsLaunch(scenario: PodcastsScenario(rawValue: arguments.state) ?? .rest))
        },
        LaunchableScreen(id: "PC-3", states: WhyScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(WhyLaunch(scenario: WhyScenario(rawValue: arguments.state) ?? .asked))
        },
    ]
}

/// PC-3 standing on the sheet as the player will show it (V2.podcasts.b). The player isn't its host
/// yet (V2.podcasts.c), so back and "hear it" are disabled with the reason, and close shows a line.
struct WhyLaunch: View {
    let scenario: WhyScenario
    @State private var closed = false

    var body: some View {
        if closed {
            Text("closed")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .onTapGesture { closed = false }
        } else {
            PlayerSheetScreen {
                WhyThisIsHerePage(model: WhyThisIsHereModel(content: SampleWhy.content(scenario), dismiss: { closed = true }))
            }
        }
    }
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
#Preview("PC-3 · asked") { WhyLaunch(scenario: .asked) }
#Preview("PC-3 · stated") { WhyLaunch(scenario: .stated) }
#Preview("PC-3 · more") { WhyLaunch(scenario: .more) }
#Preview("PC-3 · nothing yet") { WhyLaunch(scenario: .nothingYet) }
#endif
