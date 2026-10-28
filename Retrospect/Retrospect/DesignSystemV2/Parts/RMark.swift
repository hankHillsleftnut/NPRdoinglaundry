//
//  RMark.swift
//  S10: the Retrospect mark as it sits on first-run pages (Paper `c:the-mark/38`): a 38 disc in the
//  cream control colour with its inner highlight, a secondary ring and a soft cast. It says "this is
//  Retrospect" and nothing else; the wordless disc is the whole mark for now.
//  PS.sheet.a adds the player header's mark (Paper ON-11 26PQ-0, `c:the-mark/22`): a 22 disc carrying
//  the glyph (12 × 9, `icon.mark`) with a smaller contact and cast, as the header draws it.
//
import SwiftUI

struct RMark: View {
    enum Style {
        /// The 38 wordless disc of the first-run pages.
        case disc
        /// The 22 disc with the glyph at the start of the player sheet's header.
        case header
    }

    var size: CGFloat = RDimension.sizeMark
    var style: Style = .disc

    /// The player header's mark (26PQ-0).
    static var header: RMark {
        RMark(size: RDimension.sizePlayerHeaderMark, style: .header)
    }

    var body: some View {
        Circle()
            .fill(RColor.surfaceSecondaryAction)
            .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
            .overlay(Circle().stroke(RColor.borderSecondaryRing, lineWidth: RDimension.sizeBorderDefault))
            .overlay {
                if style == .header {
                    glyph
                }
            }
            .frame(width: size, height: size)
            .modifier(MarkShadow(style: style))
            .accessibilityHidden(true)
    }

    /// The Retrospect glyph (the same drawing as the loading mark, 112 × 86), tinted `icon.mark`.
    private var glyph: some View {
        Image("retrospect-loading-mark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(RColor.iconMark)
            .frame(width: RDimension.sizePlayerHeaderMarkGlyph)
    }
}

private struct MarkShadow: ViewModifier {
    let style: RMark.Style

    func body(content: Content) -> some View {
        switch style {
        case .disc:
            content
                .shadow(color: RColor.depthShadowContact, radius: 1, y: 1) // literal-ok: Paper c:the-mark contact 0 1 2
                .shadow(color: RColor.depthShadowCast, radius: 3.5, y: 6) // literal-ok: Paper c:the-mark cast 0 6 7
        case .header:
            content
                .shadow(color: RColor.depthShadowContact, radius: 0.5, y: 0.5) // literal-ok: Paper 26PQ-0 contact 0 0.5 1
                .shadow(color: RColor.depthShadowCast, radius: 1.5, y: 2) // literal-ok: Paper 26PQ-0 cast 0 2 3
        }
    }
}
