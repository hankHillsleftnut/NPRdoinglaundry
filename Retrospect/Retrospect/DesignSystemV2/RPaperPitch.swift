//
//  RPaperPitch.swift
//  Paper's line pitch for the ink faces (TYPE.leading, founder 26 Oct: "fix it once, everywhere").
//  Exposure's own line box is 1.2 × its size (ascent 0.95 + descent 0.25, no line gap), and
//  SwiftUI never sets a line shorter than the font's box: `.lineSpacing` only adds. Paper sets
//  the ink titles at --leading-tight (1.1 × size: 33 at --text-3xl), so every line after the first
//  landed 0.1 × size lower than Paper (3pt a line at 30, 9pt by line 4) and the title stood
//  3pt a line taller. This renderer keeps the first line where it is and draws each later line
//  one Paper pitch below the one before; the text reports the matching shorter height, so what
//  sits below moves up with it.
//
import SwiftUI

/// Draws a text's lines `pitch` apart (Paper's leading × size) when that is tighter than the
/// font's own line height, keeping the first line in place. The text is still laid out at the
/// font's own height (a renderer that reports a shorter size makes SwiftUI drop the last lines);
/// `RPaperPitchLayout` around it reports the shorter height to the page.
struct RPaperPitch: TextRenderer {
    /// Paper's line height at the scaled size (leading × size).
    let pitch: CGFloat
    /// The font's own line height at the scaled size, the pitch SwiftUI lays the lines out at.
    let naturalLineHeight: CGFloat

    /// How much closer each line sits than the font's own height; 0 leaves the text as it was.
    var squeeze: CGFloat {
        max(0, naturalLineHeight - pitch)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard squeeze > 0, let first = layout.first else {
            for line in layout {
                context.draw(line)
            }
            return
        }
        for (index, line) in layout.enumerated() {
            var lineContext = context
            lineContext.translateBy(x: 0, y: Self.offset(lineIndex: index, firstBaseline: first.origin.y, baseline: line.origin.y, pitch: pitch))
            lineContext.draw(line)
        }
    }

    /// How far to move a line so it sits `lineIndex` Paper pitches below the first one.
    static func offset(lineIndex: Int, firstBaseline: CGFloat, baseline: CGFloat, pitch: CGFloat) -> CGFloat {
        firstBaseline + CGFloat(lineIndex) * pitch - baseline
    }

    /// The text's height once its lines are a Paper pitch apart: the first line keeps the font's
    /// own height (so a one-line title doesn't change), each later line adds one pitch.
    static func height(laidOut: CGFloat, naturalLineHeight: CGFloat, pitch: CGFloat) -> CGFloat {
        let squeeze = naturalLineHeight - pitch
        guard squeeze > 0, naturalLineHeight > 0 else { return laidOut }
        let lines = max(1, Int((laidOut / naturalLineHeight).rounded()))
        return laidOut - CGFloat(lines - 1) * squeeze
    }

    /// The height to lay the text out in so it keeps as many lines as fit in `pitchHeight` at
    /// Paper's pitch: one font line, then one Paper pitch per further line (the inverse of `height`).
    static func laidOutHeight(forPitchHeight pitchHeight: CGFloat, naturalLineHeight: CGFloat, pitch: CGFloat) -> CGFloat {
        guard pitchHeight.isFinite, naturalLineHeight > pitch, pitch > 0, pitchHeight >= naturalLineHeight else { return pitchHeight }
        let lines = Int(((pitchHeight - naturalLineHeight) / pitch + slack).rounded(.down)) + 1
        // up to one font line more than the lines need: SwiftUI rounds a laid-out line up to a pixel
        return CGFloat(lines) * naturalLineHeight + pitch * slack * CGFloat(lines)
    }

    /// A hair of a line, so float error (33 × 4 = 131.999…) never drops a line that fits.
    private static let slack: CGFloat = 0.05 // literal-ok: fraction of a line, not a size
}

/// Wraps one text drawn by `RPaperPitch`: lays it out at the font's own height, so every line
/// is kept, and tells the page the height its lines take at Paper's pitch. The text sits at the
/// top, so its first line doesn't move; its lines are drawn inside the shorter height.
struct RPaperPitchLayout: SwiftUI.Layout {
    let pitch: RPaperPitch

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count == 1, let text = subviews.first else {
            assertionFailure("RPaperPitchLayout wraps exactly one Text")
            return subviews.first?.sizeThatFits(proposal) ?? .zero
        }
        let laidOut = text.sizeThatFits(textProposal(width: proposal.width, height: proposal.height))
        return CGSize(
            width: laidOut.width,
            height: RPaperPitch.height(laidOut: laidOut.height, naturalLineHeight: pitch.naturalLineHeight, pitch: pitch.pitch)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard subviews.count == 1, let text = subviews.first else {
            subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
            return
        }
        let laidOut = text.sizeThatFits(textProposal(width: bounds.width, height: bounds.height))
        text.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: laidOut.height))
    }

    /// The text is laid out at the font's own height, so a height offered at Paper's pitch is
    /// widened to fit the same number of lines; otherwise SwiftUI would drop the last ones.
    private func textProposal(width: CGFloat?, height: CGFloat?) -> ProposedViewSize {
        ProposedViewSize(
            width: width,
            height: height.map { RPaperPitch.laidOutHeight(forPitchHeight: $0, naturalLineHeight: pitch.naturalLineHeight, pitch: pitch.pitch) }
        )
    }
}
