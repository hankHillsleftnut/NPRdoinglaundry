//
//  RFlowLayout.swift
//  A wrapping row: Paper's `display: flex; flex-wrap: wrap` with a column gap and a row gap. Items keep
//  their own size and run leading to trailing, starting a new line when the next one would not fit.
//  Used by the onboarding question's live words (c:onboarding/your-words 1F6R-0: column gap spacing-2,
//  no row gap) and its quick answers (c:onboarding/quick-answers MH9-0: spacing-2 both ways). An item
//  wider than the line (a long word at AX5) gets the line's width and wraps inside itself.
//
import SwiftUI

struct RFlowLayout: Layout {
    /// Between items on a line.
    var spacing: CGFloat
    /// Between lines.
    var lineSpacing: CGFloat = RDimension.space0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    // MARK: Lines

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let width = min(size.width, maxWidth)
            let widthWithItem = row.items.isEmpty ? width : row.width + spacing + width
            if !row.items.isEmpty, widthWithItem > maxWidth {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? width : row.width + spacing + width
            row.height = max(row.height, size.height)
            row.items.append(Item(index: index, size: CGSize(width: width, height: size.height)))
        }
        if !row.items.isEmpty {
            rows.append(row)
        }
        return rows
    }
}
