//
//  RWaveform.swift
//  M14 S12: the five voice bars in the listening field and the talk button. Shape,
//  sizes and colours from the approved ON-3–9 board (voice.listening, size.voice-bar-*).
//  The bars follow the live voice level (founder, 21 Oct: "follow my voice"), smoothed
//  on the snappy spring and capped, and settle back to Paper's resting shape when quiet.
//
import SwiftUI

struct RWaveform: View {
    enum Mode { case listening, speaking, idle }

    var mode: Mode = .listening
    /// Live input level, 0…1. Nil shows the resting shape.
    var level: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Paper's resting shape: 6, 10, 14, 9, 5 of a 20pt box.
    private static let restShape: [Double] = [0.3, 0.5, 0.7, 0.45, 0.25] // literal-ok: the bars' designed proportions
    private var box: CGFloat {
        RDimension.sizeIconDefault
    }

    private var color: Color {
        switch mode {
        case .listening: RColor.voiceListening
        case .speaking: RColor.voiceSpeaking
        case .idle: RColor.voiceWaveIdle
        }
    }

    var body: some View {
        HStack(spacing: RDimension.sizeVoiceBarGap) {
            ForEach(Self.restShape.indices, id: \.self) { index in
                RShape.pill
                    .fill(color)
                    .frame(width: RDimension.sizeVoiceBarWidth, height: height(for: index))
            }
        }
        .frame(height: box)
        .animation(reduceMotion ? nil : RMotion.snappy, value: level)
        .animation(RMotion.standard(RNumber.motionDurationFast), value: mode)
        .accessibilityHidden(true)
    }

    private func height(for index: Int) -> CGFloat {
        let rest = Self.restShape[index]
        guard let level, mode != .idle, !reduceMotion else { return box * rest }
        // Louder voice lifts every bar, keeping the shape; never below rest, never past the box.
        let lifted = rest + (1 - rest) * Swift.min(Swift.max(level, .zero), 1)
        return box * lifted
    }
}

#if DEBUG
#Preview("waveform") {
    VStack(spacing: RDimension.space4) {
        RWaveform(mode: .listening)
        RWaveform(mode: .listening, level: 0.6)
        RWaveform(mode: .speaking, level: 0.3)
        RWaveform(mode: .idle)
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
