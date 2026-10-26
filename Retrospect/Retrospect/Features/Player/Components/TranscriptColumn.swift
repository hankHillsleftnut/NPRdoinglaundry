//
//  TranscriptColumn.swift
//  PS.sheet.a: the episode's words in the player sheet (Paper ON-11 26OZ-0): Exposure at text-xl,
//  20 between lines, 24 above the first. The line being read is dark (`text.primary`); every other
//  line, already read or still to come, is dim (`text.tertiary`; founder c-lsyb3w). The edges are the
//  real progressive blur of progressive-blur.md (96 top, 140 bottom; 64 / 80 on SE), never Paper's
//  stacked layers. Static here: following the time with motion is PS.sheet.b.
//
import SwiftUI

extension RTextStyle {
    /// A transcript line (Paper 26PC-0: display-inky at ink-card, text-xl, tracking-card, leading-snug).
    static let transcriptLine = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeXl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .title2
    )
}

struct TranscriptColumn: View {
    let transcript: Flows.Transcript
    /// The line being read; nil lights none.
    let current: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space5) {
                ForEach(Array(transcript.lines.enumerated()), id: \.element.id) { index, line in
                    Text(line.text)
                        .rText(.transcriptLine)
                        .foregroundStyle(index == current ? RColor.textPrimary : RColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityValue(index == current ? "being read" : "")
                }
            }
            .padding(.top, RDimension.space6)
        }
        .scrollIndicators(.hidden)
        .rProgressiveBlur(.transcriptTop)
        .rProgressiveBlur(.transcriptBottom)
        .accessibilityIdentifier("player.transcript")
    }
}
