//
//  PlayerScreens+Launcher.swift
//  The player sheet in the launcher (PS.sheet.a): `-Screen player -State tease|tease-still|tease-paused|
//  tease-ended -Data sample` opens ON-11's sheet on the sample player and the tease's lines (a 10-second
//  episode, founder Q5 = B). `tease` plays from 0:00 on the real clock; `tease-still` is the frame
//  compared with Paper (playing at 0:04 on the line Paper lights, held still until pause and play).
//  Nothing is mounted in the app yet (PS.sheet.c): the collapse says so in a quiet line.
//
#if DEBUG
import SwiftUI

/// The player sheet's launcher states.
enum PlayerScenario: String, CaseIterable {
    case tease
    case teaseStill = "tease-still"
    case teasePaused = "tease-paused"
    case teaseEnded = "tease-ended"

    var playback: Flows.PlaybackScenario {
        switch self {
        case .tease: .tease
        case .teaseStill: .teaseStill
        case .teasePaused: .teasePaused
        case .teaseEnded: .teaseEnded
        }
    }
}

extension ScreenRegistry {
    static let playerScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "player", states: PlayerScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(PlayerLaunch(scenario: PlayerScenario(rawValue: arguments.state) ?? .teaseStill))
        },
    ]
}

/// ON-11's sheet on the sample player, the way the flow host will show it.
struct PlayerLaunch: View {
    let scenario: PlayerScenario
    @State private var model: PlayerSheetModel?
    @State private var collapsed = false

    var body: some View {
        if collapsed {
            // stands in for where the collapse goes (the paywall rising, PS.sheet.c)
            Text("collapsed")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("player.collapsed")
        } else if let model {
            PlayerSheetScreen {
                PlayerSheet(model: model)
            }
        } else {
            RColor.backgroundUnderlay
                .ignoresSafeArea()
                .onAppear { model = makeModel() }
        }
    }

    private func makeModel() -> PlayerSheetModel {
        PlayerSheetModel(
            playback: SamplePlayback(scenario: scenario.playback, clock: ContinuousClock()),
            transcript: SampleTranscript.tease,
            onCollapse: { collapsed = true }
        )
    }
}
#endif
