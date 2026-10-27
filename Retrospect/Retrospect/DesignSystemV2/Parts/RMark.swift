//
//  RMark.swift
//  S10: the Retrospect mark as it sits on first-run pages (Paper `c:the-mark/38`): a 38 disc in the
//  cream control colour with its inner highlight, a secondary ring and a soft cast. It says "this is
//  Retrospect" and nothing else; the wordless disc is the whole mark for now.
//  PS.sheet.a adds the player header's mark (Paper ON-11 26PQ-0, `c:the-mark/22`): a 22 disc carrying
//  the glyph (12 × 9, `icon.mark`) with a smaller contact and cast, as the header draws it.
//  V2.outside.b adds the widget's mark (Paper EX-4 1H59-0 / 1H4W-0, `c:the-mark/16`, V4W-0): a 16 disc,
//  the glyph 9 wide, a 0 1 1 contact (EX-D8). Additive: the 38 and 22 marks don't change.
//
import SwiftUI

struct RMark: View {
    enum Style {
        /// The 38 wordless disc of the first-run pages.
        case disc
        /// The 22 disc with the glyph at the start of the player sheet's header.
        case header
        /// The 16 disc with the glyph at the top of a home-screen widget (EX-4).
        case widget
    }

    var size: CGFloat = RDimension.sizeMark
    var style: Style = .disc

    /// The player header's mark (26PQ-0).
    static var header: RMark {
        RMark(size: RDimension.sizePlayerHeaderMark, style: .header)
    }

    /// A home-screen widget's mark (1H59-0).
    static var widget: RMark {
        RMark(size: RDimension.sizeWidgetMark, style: .widget)
    }

    var body: some View {
        Circle()
            .fill(RColor.surfaceSecondaryAction)
            .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
            .overlay(Circle().stroke(RColor.borderSecondaryRing, lineWidth: RDimension.sizeBorderDefault))
            .overlay {
                if style != .disc {
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
            .frame(width: style == .widget ? RDimension.sizeWidgetMarkGlyph : RDimension.sizePlayerHeaderMarkGlyph)
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
        case .widget:
            content
                .shadow(color: RColor.depthShadowContact, radius: 0.5, y: 1) // literal-ok: Paper 1H59-0 contact 0 1 1
        }
    }
}
