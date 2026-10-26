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
}

/// Wraps one text drawn by `RPaperPitch`: lays it out at the font's own height, so every line
/// is kept, and tells the page the height its lines take at Paper's pitch. The text sits at the
/// top, so its first line doesn't move; its lines are drawn inside the shorter height.
struct RPaperPitchLayout: SwiftUI.Layout {
    let pitch: RPaperPitch

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let laidOut = text.sizeThatFits(proposal)
        return CGSize(
            width: laidOut.width,
            height: RPaperPitch.height(laidOut: laidOut.height, naturalLineHeight: pitch.naturalLineHeight, pitch: pitch.pitch)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let text = subviews.first else { return }
        // the page gives the shorter height back; the text still needs the font's own height for
        // every line, or SwiftUI truncates the last one
        let laidOut = text.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        text.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: laidOut.height))
    }
}
