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

/// PC-2's launcher states: Paper draws it playing only (founder 27 Oct: key drawn states only; paused,
/// ended, couldn't load and offline are undrawn, not built). `playing` runs from 4:12 on the real clock;
/// `playing-still` is the frame compared with Paper (4:12, held still until pause and play).
enum EpisodePlayerScenario: String, CaseIterable {
    case playing
    case playingStill = "playing-still"

    var playback: Flows.PlaybackScenario {
        switch self {
        case .playing: .weeklyEpisode
        case .playingStill: .weeklyEpisodeStill
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
            VStack(spacing: RDimension.space4) {
                Text(exit.standIn)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
                    .accessibilityIdentifier("pc2.exit")
                // back to the same sheet, where it was (the stand-in is a dead end otherwise)
                RButton(title: "back to the player", variant: .secondary) { self.exit = nil }
                    .fixedSize()
                    .accessibilityIdentifier("pc2.exit.back")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RColor.backgroundCanvas)
        } else if let model {
            PlayerSheetScreen {
                PlayerSheet(model: model, partLabel: .counted) { line in
                    // nothing plays behind the stand-in
                    model.playback.pause()
                    exit = .whyThisIsHere(line: line)
                }
            }
        } else {
            RColor.backgroundUnderlay
                .ignoresSafeArea()
                .onAppear {
                    model = Self.makeModel(scenario) {
                        model?.playback.pause()
                        exit = .collapsed
                    }
                }
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
#endif
