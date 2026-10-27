//
//  EpisodePlayerScreens+Launcher.swift
//  V2.podcasts.c: PC-2, the player sheet in episode mode (Paper 1FV9-0), opened with
//  `-Screen PC-2 -State <state> -Data sample`. The same `PlayerSheet` as ON-11 on the sample weekly
//  episode: the scrubber counts the chapter ("2 of 4 · the river", PCD-12) and a tap on a line asks
//  for why this is here (SCREEN-MAP row 76). PC-3 and the mini-player land in V2.podcasts.d; until
//  then the collapse and a line tap show a quiet stand-in line, like the player launcher's. Dark:
//  registered from `PodcastsScreens` and nowhere in the release root.
//
#if DEBUG
import SwiftUI

/// PC-2's launcher states. `playing-still` is the frame compared with Paper (4:12, held still);
/// `paused`, `ended`, `failed`, `offline` are the states Paper doesn't draw (PCD-6, founder-review lean).
enum EpisodePlayerScenario: String, CaseIterable {
    case playing
    case playingStill = "playing-still"
    case paused
    case ended
    case failed
    case offline

    var playback: Flows.PlaybackScenario {
        switch self {
        case .playing: .weeklyEpisode
        case .playingStill: .weeklyEpisodeStill
        case .paused: .weeklyEpisodePaused
        case .ended: .weeklyEpisodeEnded
        case .failed: .weeklyEpisodeFailed
        case .offline: .weeklyEpisodeOffline
        }
    }
}

extension ScreenRegistry {
    static let podcastsPlayerScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "PC-2", states: EpisodePlayerScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(EpisodePlayerLaunch(scenario: EpisodePlayerScenario(rawValue: arguments.state) ?? .playingStill))
        },
    ]
}

/// Where PC-2 hands off to, in the order the launcher records it.
enum EpisodePlayerExit: Equatable {
    /// The chevron-down: the mini-player above the tabs (row 82, V2.podcasts.d).
    case collapsed
    /// A line was tapped: why this is here (row 76, PC-3).
    case whyThisIsHere(line: Int)

    /// The stand-in line the launcher shows until d mounts the real destination.
    var standIn: String {
        switch self {
        case .collapsed: "collapsed · the mini-player comes next"
        case let .whyThisIsHere(line): "why this is here · line \(line + 1)"
        }
    }
}

/// PC-2's sheet on the sample player, standing on the underlay like ON-11's.
struct EpisodePlayerLaunch: View {
    let scenario: EpisodePlayerScenario
    @State private var model: PlayerSheetModel?
    @State private var exit: EpisodePlayerExit?

    var body: some View {
        if let exit {
            Text(exit.standIn)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas)
                .accessibilityIdentifier("pc2.exit")
        } else if let model {
            PlayerSheetScreen {
                PlayerSheet(model: model, partLabel: .counted) { line in
                    exit = .whyThisIsHere(line: line)
                }
            }
        } else {
            RColor.backgroundUnderlay
                .ignoresSafeArea()
                .onAppear { model = Self.makeModel(scenario) { exit = .collapsed } }
        }
    }

    static func makeModel(_ scenario: EpisodePlayerScenario, onCollapse: @escaping () -> Void) -> PlayerSheetModel {
        PlayerSheetModel(
            playback: SamplePlayback(scenario: scenario.playback, clock: ContinuousClock()),
            transcript: SampleEpisodeTranscript.weekly,
            onCollapse: onCollapse
        )
    }
}

#Preview("PC-2 · as drawn") { EpisodePlayerLaunch(scenario: .playingStill) }
#Preview("PC-2 · paused") { EpisodePlayerLaunch(scenario: .paused) }
#Preview("PC-2 · ended") { EpisodePlayerLaunch(scenario: .ended) }
#Preview("PC-2 · failed") { EpisodePlayerLaunch(scenario: .failed) }
#Preview("PC-2 · offline") { EpisodePlayerLaunch(scenario: .offline) }
#endif
