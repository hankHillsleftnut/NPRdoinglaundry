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
        TranscriptLineText(
            text: line.text,
            isCurrent: index == current,
            edges: TranscriptEdges(compact: compactHeight, reduceTransparency: reduceTransparency)
        )
    }
}

/// One transcript line. Where it sits under the column's top or bottom band, it softens point by point
/// as Paper 1FV9-0 / ON-11 draw it: a blurred copy of the words shows through a mask that follows the
/// band's ramp (TranscriptEdges), so only the part of the line nearest the edge is soft and the rest
/// stays readable. The line being read never blurs (QA batch 6).
private struct TranscriptLineText: View {
    let text: String
    let isCurrent: Bool
    let edges: TranscriptEdges

    /// The line's frame in the scroll view's visible coordinates, and the column's height.
    @State private var place = TranscriptEdges.Place()

    var body: some View {
        let stops = edges.stops(line: place.line, viewport: place.viewport, isCurrent: isCurrent)
        ZStack {
            if stops.isEmpty {
                words
            } else {
                // the sharp words fade out where the band is strong, and a blurred copy fades in there
                words
                    .mask {
                        LinearGradient(
                            stops: edges.stops(line: place.line, viewport: place.viewport, isCurrent: isCurrent, sharp: true),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                words
                    .blur(radius: edges.radius(line: place.line, viewport: place.viewport))
                    .mask { LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom) }
            }
        }.onGeometryChange(for: TranscriptEdges.Place.self) { proxy in
            TranscriptEdges.Place(line: proxy.frame(in: .scrollView), viewport: proxy.bounds(of: .scrollView)?.height ?? 0)
        } action: { place = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityValue(isCurrent ? "being read" : "")
    }

    private var words: some View {
        Text(text)
            .rText(.transcriptLine)
            .foregroundStyle(isCurrent ? RColor.textPrimary : RColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// How soft each point of a transcript line is, from where it sits in the column (Paper PC-2 1FWN-0 /
/// 1FWM-0, the same bands on ON-11 26P0-0): the top band is soft in full over its outer 30% and eases
/// to sharp at its inner edge; the bottom band eases from sharp at its inner edge to full 55% of the
/// way down. The bands, the 8pt blur and the solid fractions are tokens. The column's own progressive
/// blur (`rProgressiveBlur`) keeps the sheet tint over the bands and blurs what scrolls under the edges.
/// Nothing moves: the softness only follows position, so Reduce Motion needs no other path. Reduce
/// Transparency: no blur (the tint carries the edges, as everywhere else).
struct TranscriptEdges: Equatable {
    /// A line's frame in the scroll view's visible coordinates, and the column's height.
    struct Place: Equatable {
        var line: CGRect = .zero
        var viewport: CGFloat = 0
    }

    /// Mask samples down a line: enough that a three-line paragraph shows no steps.
    static let samples = 8 // literal-ok: mask resolution, not a size
    var compact = false
    var reduceTransparency = false

    private var topBand: CGFloat {
        compact ? RDimension.blurTranscriptTopBandCompact : RDimension.blurTranscriptTopBand
    }

    private var bottomBand: CGFloat {
        compact ? RDimension.blurTranscriptBottomBandCompact : RDimension.blurTranscriptBottomBand
    }

    /// 0 (sharp) … 1 (soft in full) at `y` points down a column `viewport` tall.
    func strength(y: CGFloat, viewport: CGFloat) -> CGFloat {
        guard !reduceTransparency, viewport > 0 else { return 0 }
        // top: full within the outer `lineSolid` of the band, easing to 0 at its inner edge
        let topSolid = topBand * RNumber.blurTranscriptTopLineSolid
        let top = y <= topSolid ? 1 : max(0, 1 - (y - topSolid) / (topBand - topSolid))
        // bottom: 0 at the band's inner edge, full `lineSolid` of the way into it, full to the edge
        let bottomStart = viewport - bottomBand
        let bottomSolid = bottomStart + bottomBand * RNumber.blurTranscriptBottomLineSolid
        let bottom = y <= bottomStart ? 0 : min(1, (y - bottomStart) / (bottomSolid - bottomStart))
        return max(top, bottom)
    }

    /// The band's strength at evenly spaced points down a line, top to bottom (`samples + 1` values).
    /// Empty when no point of the line is under a band, and always for the line being read (QA batch 6:
    /// it must stay legible wherever it sits): the line is drawn once, sharp.
    func softness(line: CGRect, viewport: CGFloat, isCurrent: Bool = false) -> [Double] {
        guard !isCurrent, line.height > 0 else { return [] }
        let values = (0 ... Self.samples).map { step in
            Double(strength(y: line.minY + CGFloat(step) / CGFloat(Self.samples) * line.height, viewport: viewport))
        }
        return values.contains { $0 > 0 } ? values : []
    }

    /// How far the sheet colour has risen over the words at `y` (Paper's bands lay background-raised
    /// over the blur: from the top edge to clear at the top band's inner edge, and from the bottom edge
    /// to clear at the bottom band's): 1 at the column's edge, 0 at a band's inner edge and beyond.
    func fade(y: CGFloat, viewport: CGFloat) -> CGFloat {
        guard viewport > 0 else { return 0 }
        let top = max(0, 1 - y / topBand)
        let bottom = max(0, 1 - (viewport - y) / bottomBand)
        return min(1, max(top, bottom))
    }

    /// The blurred copy's mask down a line (the softness, thinned as the sheet colour rises over it, so
    /// the soft part reads as Paper's faded edge and never as a grey smear), or, `sharp`, the sharp
    /// words' (one minus the softness).
    func stops(line: CGRect, viewport: CGFloat, isCurrent: Bool = false, sharp: Bool = false) -> [Gradient.Stop] {
        let values = softness(line: line, viewport: viewport, isCurrent: isCurrent)
        return values.enumerated().map { step, value in
            let location = CGFloat(step) / CGFloat(Self.samples)
            let y = line.minY + location * line.height
            let opacity = sharp ? 1 - value : value * (1 - Double(fade(y: y, viewport: viewport)))
            return Gradient.Stop(color: .black.opacity(opacity), location: location)
        }
    }

    /// The blurred copy's radius: the band's full 8 (the mask does the easing).
    func radius(line: CGRect, viewport: CGFloat) -> CGFloat {
        line.midY < viewport / 2 ? RDimension.blurTranscriptTopMax : RDimension.blurTranscriptBottomMax
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
