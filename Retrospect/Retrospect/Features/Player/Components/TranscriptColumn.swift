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
    /// A tap on a line, with its index (PC-2 → why this is here). Nil: the lines are plain text (ON-11).
    var onTapLine: ((Int) -> Void)?

    @Environment(\.rCompactHeight) private var compactHeight
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space5) {
                ForEach(Array(transcript.lines.enumerated()), id: \.element.id) { index, line in
                    if let onTapLine {
                        Button {
                            onTapLine(index)
                        } label: {
                            lineText(line, index: index)
                        }
                        .buttonStyle(TranscriptLineStyle())
                        .accessibilityHint("shows why this is here")
                        .accessibilityIdentifier("player.line.\(index)")
                    } else {
                        lineText(line, index: index)
                    }
                }
            }
            .padding(.top, RDimension.space6)
        }
        .scrollIndicators(.hidden)
        .rProgressiveBlur(.transcriptTop)
        .rProgressiveBlur(.transcriptBottom)
        .accessibilityIdentifier("player.transcript")
    }

    private func lineText(_ line: Flows.TranscriptLine, index: Int) -> some View {
        let edges = TranscriptEdges(compact: compactHeight, reduceTransparency: reduceTransparency)
        return Text(line.text)
            .rText(.transcriptLine)
            .foregroundStyle(index == current ? RColor.textPrimary : RColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            // the lines under the top and bottom bands blur by where they sit, as Paper 1FV9-0 draws
            // the first and last line at rest (QA batch 4): see TranscriptEdges
            .visualEffect { content, proxy in
                content.blur(radius: edges.radius(line: proxy.frame(in: .scrollView), viewport: proxy.bounds(of: .scrollView)?.height))
            }
            .accessibilityValue(index == current ? "being read" : "")
    }
}

/// How blurred a transcript line is, from where it sits in the column (Paper PC-2 1FWN-0 / 1FWM-0:
/// the top band blurs in full over its outer 30% and eases to sharp at its inner edge; the bottom band
/// eases from sharp at its inner edge to full 55% of the way down). The bands, their strength and the
/// solid fractions are tokens. The column's own progressive blur (`rProgressiveBlur`) keeps the sheet
/// tint over the bands and blurs what scrolls under the edges; this is what the lines at rest need,
/// which the system soft edge doesn't reach. It never moves anything: a line's blur only follows its
/// position, so Reduce Motion needs no other path. Reduce Transparency: no blur (the tint carries the
/// edges, as everywhere else).
struct TranscriptEdges: Equatable {
    var compact = false
    var reduceTransparency = false

    private var topBand: CGFloat {
        compact ? RDimension.blurTranscriptTopBandCompact : RDimension.blurTranscriptTopBand
    }

    private var bottomBand: CGFloat {
        compact ? RDimension.blurTranscriptBottomBandCompact : RDimension.blurTranscriptBottomBand
    }

    /// 0 (sharp) … 1 (blurred in full) for a line centred `mid` points down a column `viewport` tall.
    func strength(mid: CGFloat, viewport: CGFloat) -> CGFloat {
        guard !reduceTransparency, viewport > 0 else { return 0 }
        // top: full within the outer `lineSolid` of the band, easing to 0 at its inner edge
        let topSolid = topBand * RNumber.blurTranscriptTopLineSolid
        let top = mid <= topSolid ? 1 : max(0, 1 - (mid - topSolid) / (topBand - topSolid))
        // bottom: 0 at the band's inner edge, full `lineSolid` of the way into it, full to the edge
        let bottomStart = viewport - bottomBand
        let bottomSolid = bottomStart + bottomBand * RNumber.blurTranscriptBottomLineSolid
        let bottom = mid <= bottomStart ? 0 : min(1, (mid - bottomStart) / (bottomSolid - bottomStart))
        return max(top, bottom)
    }

    /// The blur radius for a line's frame in the column's coordinates.
    func radius(line: CGRect, viewport: CGFloat?) -> CGFloat {
        guard let viewport else { return 0 }
        let strength = strength(mid: line.midY, viewport: viewport)
        return strength * (line.midY < viewport / 2 ? RDimension.blurTranscriptTopMax : RDimension.blurTranscriptBottomMax)
    }
}

/// A tappable line looks exactly like a plain one at rest; pressed, it dims (no scale: a paragraph
/// that shrinks reflows the column).
private struct TranscriptLineStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
    }
}
