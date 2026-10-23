//
//  RMark.swift
//  S10: the Retrospect mark as it sits on first-run pages (Paper `c:the-mark/38`): a 38 disc in the
//  cream control colour with its inner highlight, a secondary ring and a soft cast. It says "this is
//  Retrospect" and nothing else; the wordless disc is the whole mark for now.
//
import SwiftUI

struct RMark: View {
    var size: CGFloat = RDimension.sizeMark

    var body: some View {
        Circle()
            .fill(RColor.surfaceSecondaryAction)
            .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
            .overlay(Circle().stroke(RColor.borderSecondaryRing, lineWidth: RDimension.sizeBorderDefault))
            .frame(width: size, height: size)
            .shadow(color: RColor.depthShadowContact, radius: 1, y: 1) // literal-ok: Paper c:the-mark contact 0 1 2
            .shadow(color: RColor.depthShadowCast, radius: 3.5, y: 6) // literal-ok: Paper c:the-mark cast 0 6 7
            .accessibilityHidden(true)
    }
}
