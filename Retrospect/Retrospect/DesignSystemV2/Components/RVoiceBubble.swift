//
//  RVoiceBubble.swift
//  M14 C30.3: a voice note of yours in the thread (design-system/components/message.md;
//  Paper c:message/mine/voice in part 08, 9W8-0). The same wash bubble as `RMessageBubble`
//  (message.mine, radius.message with the size.border.inset corner on your side), padded
//  8 / 16 / 8 / 8 with 12 between its three parts: a 32 raised play well, sixteen level bars
//  (size.voiceBarWidth 3, size.voiceBarGap 2, in a 20 box; the played ones text.secondary,
//  the rest text.tertiary, darkening in step with playback), and the length in mono 12
//  text.label. It hugs its parts, so it never needs the text bubble's width cap. Sending,
//  waiting and not sent read exactly as the text bubble's (`RMessageStatusLine`). Playback
//  itself belongs to the player: the host passes `progress` and `isPlaying` and gets `play`.
//
import SwiftUI

struct RVoiceBubble: View {
    /// The note's length, from the entry (the seam carries it on voice entries).
    let durationSeconds: Double
    /// How much has played, 0…1, from the player.
    var progress: Double = 0
    var isPlaying = false
    var delivery: RMessageBubble.Delivery = .sent
    /// One level per bar, 0…1, oldest first; Paper's resting shape when the note has none yet.
    var levels: [Double] = RVoiceBubble.restingLevels
    /// Plays or pauses the note (the host's player).
    let play: () -> Void
    /// Sends it again; only used when it didn't send.
    var retry: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    /// Paper's sixteen bars: 6 10 16 12 20 14 8 12 18 10 6 14 10 6 12 8 of the 20 box.
    static let restingLevels: [Double] = [
        0.3, 0.5, 0.8, 0.6, 1, 0.7, 0.4, 0.6, // literal-ok: the bars' designed proportions
        0.9, 0.5, 0.3, 0.7, 0.5, 0.3, 0.6, 0.4, // literal-ok: the bars' designed proportions
    ]

    /// How many bars, from the start, count as played: the share of the note that has played,
    /// rounded down, so a bar darkens as playback passes it, never before.
    static func playedBars(progress: Double, count: Int) -> Int {
        let share = Swift.min(Swift.max(progress, .zero), 1)
        return Swift.min(count, Int((share * Double(count)).rounded(.down)))
    }

    /// "1:42" for the bubble; whole seconds, never negative.
    static func length(seconds: Double) -> String {
        let whole = Int(Swift.max(seconds, .zero).rounded(.down))
        return "\(whole / 60):" + String(whole % 60).leftPadded()
    }

    /// "1 minute 42" for VoiceOver ("12 seconds" under a minute).
    static func spokenLength(seconds: Double) -> String {
        let whole = Int(Swift.max(seconds, .zero).rounded(.down))
        let minutes = whole / 60
        let rest = whole % 60
        switch minutes {
        case 0: return "\(rest) seconds"
        case 1: return rest == 0 ? "1 minute" : "1 minute \(rest)"
        default: return rest == 0 ? "\(minutes) minutes" : "\(minutes) minutes \(rest)"
        }
    }

    private var status: RMessageBubble.Status? {
        RMessageBubble.Status(delivery)
    }

    private var played: Int {
        Self.playedBars(progress: progress, count: levels.count)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: RDimension.space1) {
            bubble
            if let status {
                RMessageStatusLine(status: status, retry: retry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(RMotion.standard(RNumber.motionDurationFast), value: delivery)
        // once per failure: a retry that fails again goes through sending first, so it buzzes again
        .sensoryFeedback(RHaptic.error, trigger: delivery == .notSent) { old, new in !old && new }
        .accessibilityElement(children: .contain)
    }

    private var bubble: some View {
        HStack(spacing: RDimension.space3) {
            playWell
            bars
            Text(Self.length(seconds: durationSeconds))
                .rText(.voiceLength)
                .foregroundStyle(RColor.textLabel)
                .monospacedDigit()
        }
        .padding(.vertical, RDimension.space2)
        .padding(.leading, RDimension.space2)
        .padding(.trailing, RDimension.space4)
        .background(RColor.messageMine, in: RMessageBubble.shape)
        // Increase Contrast: the same 1pt edge as the text bubble
        .overlay(RMessageBubble.shape.strokeBorder(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0))
        .compositingGroup()
        .opacity(delivery == .sending ? RNumber.opacityPending : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("you: voice note, \(Self.spokenLength(seconds: durationSeconds))")
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, play)
    }

    private var accessibilityValue: String {
        if isPlaying {
            return "playing"
        }
        return played == 0 ? "" : "\(played * 100 / Swift.max(levels.count, 1)) percent played"
    }

    /// The 32 raised well with the play (or pause) glyph; it presses to 0.94 and the glyph
    /// morphs over motion.duration.playMorph (an instant swap under Reduce Motion). The hit
    /// area reaches 44 without growing the bubble.
    private var playWell: some View {
        Button(action: play) {
            RSymbol(name: isPlaying ? "pause.fill" : "play.fill", size: .small)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: RDimension.sizeControlSmall, height: RDimension.sizeControlSmall)
                .rSecondary(RDimension.radiusControl)
                .contentShape(Rectangle().inset(by: -RDimension.space3))
        }
        .rPress(small: true)
        .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationPlayMorph), value: isPlaying)
        .accessibilityHidden(true)
    }

    /// Sixteen pills in a 20 box; played ones darker. A quiet bar still shows as a dot.
    private var bars: some View {
        HStack(alignment: .center, spacing: RDimension.sizeVoiceBarGap) {
            ForEach(levels.indices, id: \.self) { index in
                RShape.pill
                    .fill(index < played ? RColor.textSecondary : RColor.textTertiary)
                    .frame(width: RDimension.sizeVoiceBarWidth, height: height(of: levels[index]))
            }
        }
        .frame(height: RDimension.sizeIconDefault)
        .animation(RMotion.move(RNumber.motionDurationFast), value: played)
    }

    private func height(of level: Double) -> CGFloat {
        Swift.max(RDimension.sizeVoiceBarWidth, RDimension.sizeIconDefault * Swift.min(Swift.max(level, .zero), 1))
    }
}

private extension String {
    /// Seconds always take two places ("1:05").
    func leftPadded() -> String {
        count < 2 ? "0" + self : self
    }
}

extension RTextStyle {
    /// A voice note's length (Paper c:message/mine/voice: --font-mono, --text-sm, text.label):
    /// a figure that counts, so mono, at the label size.
    static let voiceLength = RTextStyle(
        family: .mono,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption
    )
}

#if DEBUG
/// Lab page "voice": a note at rest, half played, and one you can play (the lab stands in for
/// the player, moving through the note in real time), then sending, waiting and not sent.
/// `-DesignLabAutoplay` plays the note and retries the failed one, for recordings.
struct RVoiceBubbleGallery: View {
    private let length: Double = 102
    @State private var playing = false
    @State private var progress: Double = 0
    @State private var failed: RMessageBubble.Delivery = .notSent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("voice note · at rest (c:message/mine/voice)")
                RVoiceBubble(durationSeconds: length) {}
                caption("half played")
                RVoiceBubble(durationSeconds: length, progress: 0.5) {}
                caption("plays · the lab stands in for the player")
                RVoiceBubble(durationSeconds: length, progress: progress, isPlaying: playing) { playing.toggle() }
                caption("sending · waiting · not sent (tap the line to retry)")
                VStack(alignment: .trailing, spacing: RDimension.space2) {
                    RVoiceBubble(durationSeconds: 12, delivery: .sending) {}
                    RVoiceBubble(durationSeconds: 47, delivery: .waiting) {}
                    RVoiceBubble(durationSeconds: 125, delivery: failed, play: {}, retry: { Task { await retry() } })
                }
                RPill(title: "fail it again", style: .raised) { Task { await failAgain() } }
                    .disabled(failed == .sending)
            }
            .padding(RDimension.spaceScreenMargin)
        }
        // moves through the note while playing; cancelled with the page, so nothing outlives it
        .task(id: playing) {
            guard playing else { return }
            let step = 1.0 / 30
            while !Task.isCancelled, progress < 1 {
                do { try await Task.sleep(for: .seconds(step)) } catch { return }
                progress = Swift.min(1, progress + step / length)
            }
            playing = false
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            playing = true
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await retry()
        }
    }

    /// A retry that lands.
    private func retry() async {
        failed = .sending
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        failed = .sent
    }

    /// A send that fails again, with the buzz.
    private func failAgain() async {
        failed = .sending
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        failed = .notSent
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("voice bubble") { RVoiceBubbleGallery() }
#endif
