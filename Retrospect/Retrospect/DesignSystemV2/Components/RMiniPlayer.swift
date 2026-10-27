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

        /// The well's glyph: pause while playing (and under the buffering spinner), play when paused, retry on failure.
        var wellSymbol: String {
            switch self {
            case .playing, .buffering: "pause.fill"
            case .paused: "play.fill"
            case .failed: "arrow.clockwise"
            }
        }

        /// What the well says to VoiceOver: what a tap will do.
        var wellLabel: String {
            switch self {
            case .playing, .buffering: "pause"
            case .paused: "play"
            case .failed: "try again"
            }
        }

        /// Whether the 2pt progress line shows (Paper GXB-0 drops it on failure).
        var showsProgress: Bool {
            self != .failed
        }
    }

    let title: String
    /// "chapter 2 · the standup · 8 min left"; replaced by the failure line when failed.
    let subline: String
    let artwork: RArtworkRecipe
    let phase: Phase
    /// 0…1 of the episode played.
    let progress: Double
    /// The body: opens the player sheet. Nil where the body has nowhere to go (the ON-12 paywall,
    /// PW-Q7): it is then not a button and promises nothing to VoiceOver. Failed, the body still retries.
    let open: (() -> Void)?
    /// The well: pause, play or retry, by phase.
    let well: () -> Void
    /// What VoiceOver hears after the well's label, where a tap does more than the label says (the
    /// ON-12 paywall, PW-Q9: play nudges the plan instead of playing). Nil: no hint; additive.
    var wellHint: String? = nil
    /// The well's press haptic. Nil where the tap's answer carries its own haptic (the paywall's nudge
    /// fires one selection haptic at its peak), so one tap never gives two; additive.
    var wellHaptic: SensoryFeedback? = RHaptic.press

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: RDimension.space3) {
            if let action = bodyAction {
                // failed, the whole pill retries, so "tap to retry" (Paper GXF-0) is true wherever you tap
                Button(action: action) {
                    info.contentShape(Rectangle())
                }
                .buttonStyle(RPressStyle())
                .accessibilityLabel(title)
                .accessibilityValue(phase == .failed ? Self.failedLine : subline)
                .accessibilityHint(phase == .failed ? "tries again" : "opens the player")
            } else {
                info
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title)
                    .accessibilityValue(subline)
            }
            RMiniPlayerWell(phase: phase, hint: wellHint, haptic: wellHaptic, action: well)
        }
        .padding(.horizontal, RDimension.space2)
        .frame(minHeight: RDimension.sizePlayerTray)
        .background { RMiniPlayerSurface() }
        .overlay(alignment: .bottomLeading) {
            if phase.showsProgress {
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

    /// What a tap on the body does: retry when failed, else open (nil: the body is not a button).
    private var bodyAction: (() -> Void)? {
        phase == .failed ? well : open
    }

    /// The thumb and the two lines.
    private var info: some View {
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
    }

    /// Paper's box-shadow stack for the pill (GX0-0 / GXB-0): the same in every phase.
    static let surfaceShadow = RElevation.boxShadowMiniPlayer

    /// The share played, held inside 0…1.
    private var played: CGFloat {
        Self.played(progress)
    }

    /// The share played, held inside 0…1 (a bad or late progress value never overdraws the pill).
    static func played(_ progress: Double) -> CGFloat {
        guard progress.isFinite else { return .zero }
        return CGFloat(min(max(progress, .zero), 1))
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
    let hint: String?
    let haptic: SensoryFeedback?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if phase == .buffering {
                    RSpinner(diameter: RDimension.sizeIconDefault)
                } else {
                    RSymbol(name: phase.wellSymbol)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: RDimension.sizeControlDefault, height: RDimension.sizeControlDefault)
            .background(RColor.surfaceWash, in: Circle())
            .contentShape(Circle())
        }
        .rPress(small: true, haptic: haptic)
        .accessibilityLabel(phase.wellLabel)
        .accessibilityHint(hint ?? "")
        .sensoryFeedback(RHaptic.error, trigger: phase) { _, new in new == .failed }
    }
}

/// background.raised with Paper's floating stack (GX0-0 / GXB-0) layer for layer, through rBoxShadows
/// (the #202 technique): the inset 0 1 0 top light, the 0.5 hairline fully outside the edge, contact
/// 0 1 1.5, and the cast 0 4 10 −4 and ambient 0 10 30 −10 pulled in by their spreads, so nothing
/// climbs above the top edge. All from one token, `RElevation.boxShadowMiniPlayer`.
private struct RMiniPlayerSurface: View {
    var body: some View {
        RShape.pill.fill(RColor.backgroundRaised)
            .rBoxShadows(RMiniPlayer.surfaceShadow, radius: RDimension.radiusControl)
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
