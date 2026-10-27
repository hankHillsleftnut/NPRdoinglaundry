//
//  BriefLaunch.swift
//  V2.journal J3: JR-2 in the launcher, `-Screen JR-2 -State playing|paused|played|quiet -Data sample`.
//  Each opens the brief sheet on the sample player in the state Paper draws (playing and quiet are held
//  still on Paper's frame until pause and play). The collapse goes back to the journal (JR-1 on its
//  sample, SCREEN-MAP row 52), with no mini-player (not drawn). Listed by `JournalV2Screens`.
//
#if DEBUG
import SwiftUI

/// JR-2's launcher states.
enum BriefScenario: String, CaseIterable {
    case playing, paused, played, quiet

    var playback: Flows.PlaybackScenario {
        switch self {
        case .playing: .briefPaperPlaying
        case .paused: .briefPaperPaused
        case .played: .briefPaperPlayed
        case .quiet: .briefPaperQuiet
        }
    }

    var content: BriefSheetContent {
        self == .quiet ? SampleBrief.quietTuesday : SampleBrief.heavierWeek
    }
}

extension JournalV2Screens {
    static let briefScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "JR-2", states: BriefScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(BriefLaunch(scenario: BriefScenario(rawValue: arguments.state) ?? .playing))
        },
    ]
}

/// The brief sheet on the sample player, standing on the underlay the way the journal will raise it.
struct BriefLaunch: View {
    let scenario: BriefScenario
    @State private var model: BriefSheetModel?
    @State private var collapsed = false

    var body: some View {
        if collapsed {
            JournalLaunch(scenario: scenario == .quiet ? .briefQuiet : .full)
                .transition(.opacity)
        } else if let model {
            PlayerSheetScreen {
                BriefSheet(model: model)
            }
        } else {
            RColor.backgroundUnderlay
                .ignoresSafeArea()
                .onAppear { model = makeModel() }
        }
    }

    private func makeModel() -> BriefSheetModel {
        BriefSheetModel(
            playback: SamplePlayback(scenario: scenario.playback, clock: ContinuousClock()),
            content: scenario.content,
            onCollapse: { withAnimation(RMotion.standard(RNumber.motionDurationFast)) { collapsed = true } }
        )
    }
}

#Preview("JR-2 · playing") { BriefLaunch(scenario: .playing) }
#Preview("JR-2 · quiet") { BriefLaunch(scenario: .quiet) }
#endif
