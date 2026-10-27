//
//  HeardWords.swift
//  GR.ready, ON-10: your words under the question (Paper c:onboarding/your-words 26MX-0): the inky
//  card face at --text-2xl in text.secondary, words side by side 8 apart (column gap, baseline),
//  wrapping. Each word arrives on its own: blur 4 → 0 and opacity 0 → 1 over 200ms on
//  curve.standard (build notes, onboarding question). A word still being recognised stays soft,
//  as Paper draws "thursday" (blur 2, opacity.pending), and sharpens when it is final. Reduce
//  Motion: words arrive whole (a 140ms fade, no blur); a pending word is only lighter.
//
import SwiftUI

struct HeardWords: View {
    let words: [GettingReadyModel.Word]
    /// The UI-test name (ON-10's by default; the questions page passes its own).
    var identifier = "gettingReady.words"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Paper's soft word (26MY-0): blur(2px).
    static let pendingBlur: CGFloat = RDimension.motionAppearBlurFrom / 4 // literal-ok: Paper blur 2 (of the 8 appear blur)
    /// A word arriving starts here (build notes: blur 4 → 0).
    static let arrivalBlur: CGFloat = RDimension.motionAppearBlurFrom / 2 // literal-ok: build notes blur 4

    var body: some View {
        WordFlow(spacing: RDimension.space2) {
            ForEach(words) { word in
                Text(word.text)
                    .rText(.answerWords)
                    .foregroundStyle(RColor.textSecondary)
                    .blur(radius: word.isPending && !reduceMotion ? Self.pendingBlur : 0)
                    .opacity(word.isPending ? RNumber.opacityPending : 1)
                    .transition(arrival)
            }
        }
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.standard(RNumber.motionDurationBase), value: words)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(words.map(\.text).joined(separator: " "))
        .accessibilityHidden(words.isEmpty)
        .accessibilityIdentifier(identifier)
    }

    /// In: sharpening from the blur (Reduce Motion: a fade). Out (a new answer replaces them):
    /// faster, on the exit curve (craft 1.8).
    private var arrival: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .modifier(active: Arriving(blur: Self.arrivalBlur, opacity: 0), identity: Arriving(blur: 0, opacity: 1)),
            removal: AnyTransition.opacity.animation(RMotion.exit(RNumber.motionDurationFast))
        )
    }
}

/// A word on its way in: blurred and transparent, resolving to sharp.
private struct Arriving: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}

/// Words in a row, `spacing` apart, wrapping to the next line at the edge; lines touch (each word
/// carries its own leading), aligned to the leading edge. Paper's flex-wrap with a column gap.
struct WordFlow: SwiftUI.Layout {
    var spacing: CGFloat
    /// Between lines (none for words, whose lines touch; the questions' quick answers use 8, MH9-0).
    var lineSpacing: CGFloat = RDimension.space0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Greedy lines: a word goes on the current line if it fits, else starts the next. A word wider
    /// than the line (accessibility sizes) gets a line to itself.
    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, needed > width {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
