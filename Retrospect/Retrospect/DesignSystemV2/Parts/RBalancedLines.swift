//
//  RBalancedLines.swift
//  CSS `text-wrap: balance`, as Paper sets titles and lines (the privacy mark's title, the splash's
//  words): the text is laid out at the narrowest width that still takes as many lines as at the full
//  width, so a line never leaves one word alone on its last line. One home (moved from PrivacyPage).
//
import SwiftUI

extension View {
    /// Balanced wrapping (CSS `text-wrap: balance`). The view keeps the narrower width it settles on,
    /// so the parent's alignment places it (leading on the splash, centred on the privacy page).
    func rBalancedLines() -> some View {
        RBalancedLayout { self }
    }
}

struct RBalancedLayout: SwiftUI.Layout {
    /// Halvings of the width search: under a point of error on any phone.
    private static let steps = 10 // literal-ok: search depth, not a size

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let full = text.sizeThatFits(proposal)
        guard let width = proposal.width, width.isFinite, width > 0 else { return full }
        var low: CGFloat = 0
        var high = min(width, full.width)
        for _ in 0 ..< Self.steps {
            let middle = (low + high) / 2
            let height = text.sizeThatFits(ProposedViewSize(width: middle, height: nil)).height
            if height > full.height {
                low = middle
            } else {
                high = middle
            }
        }
        return CGSize(width: high.rounded(.up), height: full.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}
