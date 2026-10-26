//
//  RMiniPlayer.swift
//  V2 lane 0 · components gap #4: the mini-player, the one control for what's playing while the player
//  sheet is closed (Paper 02 · components, part 45 GT1-0: c:mini-player/playing GX0-0, /failed GXB-0; in
//  use on PC-1 H0Q-0; spec components/mini-player.md). It floats 12 above the tab bar on every tab while
//  something is loaded (PC-1 draws it; the shell mounts it later). Playback lives in the player; this
//  view only shows a state and reports taps.
//
//  Paper, 1:1 (GX0-0): a 64-tall pill (radius.control), width = screen − 2 × margin (354 on 402),
//  background.raised; inner-top 0 1 0 and a 0.5 outer stroke; shadows contact 0 1 1.5, cast 0 4 10 −4,
//  ambient 0 10 30 −10. 8 padding at the sides, 12 between parts: a 44 round mesh thumb, the title
//  (SF text-md medium, one line) over the subline (Geist text-sm, text.label), 2 apart, and a 44 wash
//  well (pause / play / retry, a 20 glyph). A 2pt player.progress line along the bottom, clipped by the
//  pill. Failed (GXB-0): the subline in status.dangerText ("couldn't play · tap to retry"), the well
//  shows retry, the whole pill retries (so "tap to retry" holds wherever you tap) and the line goes.
//  Buffering and paused come from the spec's state table (Paper draws playing and failed only):
//  paused shows play; buffering keeps the glyph's place with the spinner and holds the line.
//  Pressed: the body 0.98, the well 0.94 with haptic.press (RPressStyle). Reduce Motion: no scale.
//
import SwiftUI

extension RTextStyle {
    /// The mini-player's title (GX3-0: --font-text, --text-md, medium, --leading-snug).
    static let miniPlayerTitle = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

struct RMiniPlayer: View {
    enum Phase: Equatable {
        case playing
        case paused
        /// Loading audio: the well spins, the line holds.
        case buffering
        /// It couldn't play: the subline says so and the well retries.
        case failed
    }

    let title: String
    /// "chapter 2 · the standup · 8 min left"; replaced by the failure line when failed.
    let subline: String
    let artwork: RArtworkRecipe
    let phase: Phase
    /// 0…1 of the episode played.
    let progress: Double
    /// The body: opens the player sheet.
    let open: () -> Void
    /// The well: pause, play or retry, by phase.
    let well: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: RDimension.space3) {
            // failed, the whole pill retries, so "tap to retry" (Paper GXF-0) is true wherever you tap
            Button(action: phase == .failed ? well : open) {
                HStack(spacing: RDimension.space3) {
                    RArtwork(
                        recipe: artwork,
                        width: RDimension.sizeControlDefault,
                        height: RDimension.sizeControlDefault,
                        cornerRadius: RDimension.radiusControl
                    )
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: RDimension.sizeBorderRing) {
                        Text(title)
                            .rText(.miniPlayerTitle)
                            .foregroundStyle(RColor.textPrimary)
                            .lineLimit(1)
                        Text(phase == .failed ? Self.failedLine : subline)
                            .rText(.metaLine)
                            .foregroundStyle(sublineColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(RPressStyle())
            .accessibilityLabel(title)
            .accessibilityValue(phase == .failed ? Self.failedLine : subline)
            .accessibilityHint(phase == .failed ? "tries again" : "opens the player")
            RMiniPlayerWell(phase: phase, action: well)
        }
        .padding(.horizontal, RDimension.space2)
        .frame(minHeight: RDimension.sizePlayerTray)
        .background { RMiniPlayerSurface() }
        .overlay(alignment: .bottomLeading) {
            if phase != .failed {
                GeometryReader { proxy in
                    RColor.playerProgress
                        .frame(width: proxy.size.width * played, height: RDimension.sizeBorderRing)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RShape.pill)
                .accessibilityHidden(true)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationPlayMorph), value: phase)
    }

    static let failedLine = "couldn't play · tap to retry"

    /// The share played, held inside 0…1.
    private var played: CGFloat {
        CGFloat(min(max(progress, .zero), 1))
    }

    private var sublineColor: Color {
        if phase == .failed {
            return RColor.statusDangerText
        }
        return contrast == .increased ? RColor.textSecondary : RColor.textLabel
    }
}

/// The 44 wash well: pause while playing, play when paused, the spinner while buffering, retry on failure.
private struct RMiniPlayerWell: View {
    let phase: RMiniPlayer.Phase
    let action: () -> Void

    private var symbol: String {
        switch phase {
        case .playing: "pause.fill"
        case .paused: "play.fill"
        case .buffering: "pause.fill"
        case .failed: "arrow.clockwise"
        }
    }

    private var label: String {
        switch phase {
        case .playing, .buffering: "pause"
        case .paused: "play"
        case .failed: "try again"
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if phase == .buffering {
                    RSpinner(diameter: RDimension.sizeIconDefault)
                } else {
                    RSymbol(name: symbol)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: RDimension.sizeControlDefault, height: RDimension.sizeControlDefault)
            .background(RColor.surfaceWash, in: Circle())
            .contentShape(Circle())
        }
        .rPress(small: true, haptic: RHaptic.press)
        .accessibilityLabel(label)
        .sensoryFeedback(RHaptic.error, trigger: phase) { _, new in new == .failed }
    }
}

/// background.raised with Paper's floating stack (GX0-0): inner-top 0 1 0 white, 0.5 warm hairline,
/// contact 0 1 1.5, cast 0 4 10 −4, ambient 0 10 30 −10 (spread has no SwiftUI form: the radius halves it).
private struct RMiniPlayerSurface: View {
    var body: some View {
        let shape = RShape.pill
        shape.fill(RColor.backgroundRaised)
            .overlay(alignment: .top) {
                shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 3, y: 4)
            .shadow(color: RColor.depthShadowAmbient, radius: 10, y: 10)
    }
}

#if DEBUG
/// Lab page "miniplayer": Paper's two (playing GX0-0, failed GXB-0), then paused and buffering from the
/// spec, and a live one whose well cycles playing → paused → buffering → failed.
struct RMiniPlayerGallery: View {
    @State private var live = RMiniPlayer.Phase.playing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                ForEach([RMiniPlayer.Phase.playing, .failed, .paused, .buffering], id: \.self) { phase in
                    Text("mini-player · \(String(describing: phase))").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                    sample(phase)
                }
                Text("live · tap the well").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                sample(live) {
                    let order: [RMiniPlayer.Phase] = [.playing, .paused, .buffering, .failed]
                    live = order[((order.firstIndex(of: live) ?? 0) + 1) % order.count]
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
    }

    private func sample(_ phase: RMiniPlayer.Phase, well: @escaping () -> Void = {}) -> some View {
        RMiniPlayer(
            title: "the week you stopped rushing",
            subline: "chapter 2 · the standup · 8 min left",
            artwork: RArtworkRecipes.weekly,
            phase: phase,
            progress: 0.34,
            open: {},
            well: well
        )
    }
}

#Preview("mini-player") { RMiniPlayerGallery() }
#endif
