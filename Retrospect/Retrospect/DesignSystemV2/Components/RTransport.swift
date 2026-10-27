//
//  RTransport.swift
//  C24: the player's transport (Paper JR-2 row `1FMT-0`: tray `1FMV-0`, skips `1FN1-0` / `1FMW-0`,
//  raised play well `1FMY-0` with `1FMZ-0`, speed `1FMU-0`). A recessed 64 tray holds skip back 15,
//  the play/pause well and skip forward 30 (15 under a minute); the speed figure sits to its right.
//  The "..." Paper draws to the left opens a menu when the page gives one (`more`, the player
//  sheet, PS.sheet); without one its 44 slot stays empty so the tray stays centred as drawn.
//
//  The glyph follows the player's state, never the button: pause shows only while the player says
//  `.playing`. Buffering turns a ring around the glyph; the end offers "play again" with forward
//  disabled; a failure offers retry under "couldn't load this brief"; offline disables the skips.
//  The well never glows (founder's rule for the transport).
//
import SwiftUI

struct RTransport: View {

    // MARK: Rules (pure)

    /// The well's glyph.
    enum Well: Equatable {
        case play, pause, retry
    }

    /// The one line above the tray, when the audio can't play.
    enum Line: Equatable {
        case failed, offline

        var text: String {
            switch self {
            case .failed: "couldn't load this brief"
            case .offline: "offline · it'll play when you're back online"
            }
        }

        var spoken: String {
            text.replacingOccurrences(of: " · ", with: ", ")
        }
    }

    /// Everything the transport draws, from the player's state alone.
    struct Look: Equatable {
        var well: Well
        var wellLabel: String
        var buffering = false
        var backEnabled = true
        var forwardEnabled = true
        var line: Line?
    }

    enum Action: Equatable {
        case well, back, forward, speed
    }

    /// Skip back, and the scrubber's VoiceOver step.
    static let backSeconds: Double = 15
    /// Skip forward, for audio a minute or longer.
    static let forwardSeconds: Double = 30
    /// The speeds the "1.0×" control steps through, in order, then round again.
    static let speeds: [Double] = [1, 1.2, 1.5, 2, 0.8]
    /// How far a skip glyph turns while pressed, in degrees (C24).
    static let skipTurn: Double = 20

    /// Forward is 30, or 15 when the audio is under a minute.
    static func forwardStep(duration: Double?) -> Double {
        guard let duration, duration < ScrubberMath.oneCapsuleUnder else { return forwardSeconds }
        return backSeconds
    }

    static func look(for state: Flows.PlaybackState) -> Look {
        switch state {
        case .idle:
            Look(well: .play, wellLabel: "play", backEnabled: false, forwardEnabled: false)
        case .paused:
            Look(well: .play, wellLabel: "play")
        case .playing:
            Look(well: .pause, wellLabel: "pause")
        case .buffering:
            Look(well: .play, wellLabel: "pause", buffering: true)
        case .ended:
            Look(well: .retry, wellLabel: "play again", forwardEnabled: false)
        case .failed:
            Look(well: .retry, wellLabel: "retry", backEnabled: false, forwardEnabled: false, line: .failed)
        case .offline:
            Look(well: .play, wellLabel: "play", backEnabled: false, forwardEnabled: false, line: .offline)
        }
    }

    /// One tap, one command: rapid taps queue nothing beyond one command each.
    static func perform(_ action: Action, on playback: any Flows.Playback) {
        switch action {
        case .well:
            switch playback.state {
            case .playing, .buffering: playback.pause()
            default: playback.play()
            }
        case .back:
            playback.skip(by: -backSeconds)
        case .forward:
            playback.skip(by: forwardStep(duration: playback.duration ?? playback.item?.durationSeconds))
        case .speed:
            playback.rate = nextRate(after: playback.rate)
        }
    }

    static func nextRate(after rate: Double) -> Double {
        guard let index = speeds.firstIndex(where: { abs($0 - rate) < 0.01 }) else { return speeds[0] }
        return speeds[(index + 1) % speeds.count]
    }

    /// "1.0×", "1.2×".
    static func speedWords(_ rate: Double) -> String {
        let tenths = Int((rate * 10).rounded())
        return "\(tenths / 10).\(tenths % 10)\u{00D7}"
    }

    // MARK: View

    let playback: any Flows.Playback
    /// The "…" menu's rows (Paper 26OB-0; build note: chapters ›, download). Nil leaves the slot
    /// empty, as before; the menu opens through the page's `rMenuHost()`.
    var more: [RMenuRow]?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var spin = false

    private var look: Look {
        Self.look(for: playback.state)
    }

    var body: some View {
        let look = look
        VStack(spacing: RDimension.space3) {
            if let line = look.line {
                Text(line.text)
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(line.spoken)
                    .rBlurReplace()
            }
            HStack(spacing: RDimension.space0) {
                if let more {
                    MoreButton(rows: more)
                } else {
                    // Paper's "..." slot with no menu given: nothing to tap; the tray stays centred
                    Color.clear
                        .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: RDimension.space0)
                tray(look)
                Spacer(minLength: RDimension.space0)
                speed
            }
        }
        .animation(RMotion.snappy, value: look.line)
        .sensoryFeedback(RHaptic.error, trigger: look.line == .failed) { _, failed in failed }
    }

    // MARK: Tray

    /// The skips' 44 frames overlap the drawn 28 glyphs, so the tray keeps Paper's 22 inset and 20 gaps.
    private static let skipOverhang = (RDimension.sizeTouchTarget - RDimension.sizePlayerSkipIcon) / 2

    private func tray(_ look: Look) -> some View {
        HStack(spacing: RDimension.space5 - Self.skipOverhang) {
            skip(.back, enabled: look.backEnabled)
            well(look)
            skip(.forward, enabled: look.forwardEnabled)
        }
        .padding(.horizontal, RDimension.sizePlayerTrayInset - Self.skipOverhang)
        .frame(height: RDimension.sizePlayerTray)
        .background { recess }
    }

    /// Recessed, not a lighter fill: the wash shade with a deep top inner shade and a hairline (1FMV-0).
    private var recess: some View {
        RShape.pill
            .fill(RColor.surfaceWashPressed)
            .overlay {
                RShape.pill
                    .stroke(RColor.depthShadowSunken, lineWidth: RDimension.sizeBorderRing)
                    .blur(radius: RDimension.sizeBorderDefault)
                    .offset(y: RDimension.sizeBorderDefault)
                    .clipShape(RShape.pill)
            }
            .overlay {
                RShape.pill.strokeBorder(
                    contrast == .increased ? RColor.borderControl : RColor.depthStrokeOuter,
                    lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.sizeBorderHairline
                )
            }
    }

    private func skip(_ action: Action, enabled: Bool) -> some View {
        let back = action == .back
        return Button {
            Self.perform(action, on: playback)
        } label: {
            Image(back ? "skip-back-15" : "skip-forward-30")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(contrast == .increased ? RColor.textPrimary : RColor.textSecondary)
                .frame(width: RDimension.sizePlayerSkipIcon, height: RDimension.sizePlayerSkipIcon)
                .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(SkipPressStyle(turn: back ? -Self.skipTurn : Self.skipTurn))
        .disabled(!enabled)
        .compositingGroup()
        .opacity(enabled ? 1 : RNumber.opacityDisabled)
        .accessibilityLabel(back ? "skip back 15 seconds" : forwardLabel)
        .accessibilityIdentifier(back ? "transport.back" : "transport.forward")
    }

    private var forwardLabel: String {
        let step = Int(Self.forwardStep(duration: playback.duration ?? playback.item?.durationSeconds))
        return "skip forward \(step) seconds"
    }

    private func well(_ look: Look) -> some View {
        Button {
            Self.perform(.well, on: playback)
        } label: {
            ZStack {
                glyph(look.well)
                    .id(look.well)
                    .transition(glyphTransition)
                if look.buffering {
                    ring
                }
            }
            .frame(width: RDimension.sizeControlLarge, height: RDimension.sizeControlLarge)
            .contentShape(Rectangle())
        }
        .buttonStyle(WellPressStyle())
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.standard(RNumber.motionDurationPlayMorph), value: look.well)
        .accessibilityLabel(look.wellLabel)
        .accessibilityIdentifier("transport.well")
    }

    private func glyph(_ well: Well) -> some View {
        let symbol = switch well {
        case .play: "play.fill"
        case .pause: "pause.fill"
        case .retry: "arrow.clockwise"
        }
        return Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(RColor.iconDefault)
            .padding(RDimension.space1)
            .frame(width: RDimension.sizePlayerPlayIcon, height: RDimension.sizePlayerPlayIcon)
            .accessibilityHidden(true)
    }

    /// The play morph: scale 0.8 and an opacity cross (the glyphs aren't one symbol); a plain
    /// cross-fade with Reduce Motion.
    private var glyphTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: RNumber.motionScalePopoverFrom).combined(with: .opacity)
    }

    /// Buffering: a 2pt ring turns around the glyph; with Reduce Motion it holds still.
    private var ring: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(RColor.textLabel, style: StrokeStyle(lineWidth: RDimension.sizeBorderRing, lineCap: .round))
            .frame(width: RDimension.sizeControlIcon, height: RDimension.sizeControlIcon)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(RMotion.spin) { spin = true }
            }
            .onDisappear { spin = false }
            .accessibilityHidden(true)
    }

    // MARK: Speed

    private var speed: some View {
        Button {
            Self.perform(.speed, on: playback)
        } label: {
            Text(Self.speedWords(playback.rate))
                .rText(.playerSpeed)
                .foregroundStyle(RColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: RDimension.sizeTouchTarget, minHeight: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
        }
        .rPress(small: true)
        // AX3: the controls keep their size
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("speed")
        .accessibilityValue(Self.speedWords(playback.rate).replacingOccurrences(of: "\u{00D7}", with: " times"))
        .accessibilityIdentifier("transport.speed")
    }
}

extension RTextStyle {
    /// The speed figure beside the transport (Paper 1FMU-0: mono 15 on an 18 line).
    static let playerSpeed = RTextStyle(
        family: .mono,
        size: RDimension.fontSizePlayerSpeed,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.2,
        relativeTo: .subheadline
    )
}

/// The "…" (Paper 26OB-0): three 4 dots in `icon.muted`, 4 apart, in a 44 frame; a tap opens the
/// menu, which grows out of it (RMenu).
private struct MoreButton: View {
    let rows: [RMenuRow]
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: RDimension.space1) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    Circle()
                        .fill(RColor.iconMuted)
                        .frame(width: RDimension.sizePlayerMoreDot, height: RDimension.sizePlayerMoreDot)
                }
            }
            .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
        }
        .rPress(small: true)
        .rMenuSource(isPresented: $open, rows: rows)
        .accessibilityLabel("more")
        .accessibilityIdentifier("transport.more")
    }
}

/// A skip: the arrow turns toward its direction while pressed and springs back (no turn with
/// Reduce Motion); the skip haptic on touch down.
private struct SkipPressStyle: ButtonStyle {
    let turn: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? turn : 0))
            .opacity(configuration.isPressed && reduceMotion ? RNumber.opacityPressed : 1)
            .animation(RMotion.snappy, value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in
                pressed ? RHaptic.skip : nil
            }
    }
}

/// The raised play well (Paper 1FMY-0: inner-top 1, inner 1, outer 0.5, contact 0 1 1.5, cast
/// 0 10 24 −10). Pressed, it shrinks to 0.94 and the cast collapses to the contact. Never lit.
private struct WellPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RShape.pill
        return configuration.label
            .background {
                shape.fill(RColor.backgroundRaised)
                    .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: RDimension.sizeBorderDefault))
                    .overlay(alignment: .top) {
                        shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                            .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
                    }
                    .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
                    .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1)
                    .shadow(color: pressed ? .clear : RColor.depthShadowCast, radius: 7, y: 10)
            }
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePressSmall : 1)
            .opacity(pressed && reduceMotion ? RNumber.opacityPressed : 1)
            .animation(pressed ? RMotion.standard(RNumber.motionDurationPressIn) : RMotion.snappy, value: pressed)
            .sensoryFeedback(trigger: pressed) { _, isPressed in
                isPressed ? RHaptic.press : nil
            }
    }
}

// MARK: - Lab

#if DEBUG
/// Lab page "transport": every sample scenario (paused, playing, played, quiet, buffering, failed,
/// offline, long, under a minute), each live on its own sample player, with its scrubber above.
struct RTransportGallery: View {
    @State private var players = Flows.PlaybackScenario.allCases.map { SamplePlayback(scenario: $0, clock: ContinuousClock()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space10) {
                ForEach(players, id: \.scenario) { player in
                    VStack(alignment: .leading, spacing: RDimension.space4) {
                        Text(player.scenario.rawValue).rText(.labelMedium).foregroundStyle(RColor.textSecondary)
                        RScrubber(playback: player)
                        RTransport(playback: player)
                    }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .accessibilityIdentifier("lab.transport")
    }
}

#Preview("transport") { RTransportGallery() }
#endif
