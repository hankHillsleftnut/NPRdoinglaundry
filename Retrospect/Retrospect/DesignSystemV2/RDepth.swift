//
//  RDepth.swift
//  The surface ladder from the approved Paper parts: wash (flat tint), sunken (inset well), raised
//  (floats above the page), secondary (the cream control) and lit (the one primary action). Every
//  colour is a generated token; shadow geometry matches the Paper box-shadows. SwiftUI has no inset
//  shadow, so Paper's inset highlights are drawn as inner strokes.
//
import SwiftUI

/// Every corner is a squircle (radius.style, founder 21 Oct): continuous curvature for
/// rectangles and pills alike. Draw corners through these, never a bare Capsule() or
/// RoundedRectangle (design-system/tools/check-swift-literals.mjs fails them).
enum RShape {
    static func rect(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: RCorner.style)
    }

    static var pill: Capsule {
        Capsule(style: RCorner.style)
    }
}

extension View {
    /// z 0.5 · a translucent tint that reads as part of the page (pills, wells, bubbles).
    func rWash(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        background(RColor.surfaceWash, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// z −1 · a field you type or search into.
    func rSunken(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(RColor.surfaceControl, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: 0.5))
            .overlay(alignment: .top) {
                // inset 0 1 2 sunken shade, darkest at the top edge
                shape.stroke(RColor.depthShadowSunken, lineWidth: 2).blur(radius: 1).offset(y: 1).clipShape(shape)
            }
    }

    /// z 1 · floats above the page: cards, the composer, the mini-player.
    func rRaised(_ radius: CGFloat = RDimension.radiusCard) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: 1))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.depthShadowContact, radius: 1, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 14, y: 12)
            .shadow(color: RColor.depthShadowAmbient, radius: 30, y: 24)
    }

    /// The cream secondary control (raised pills, plan buttons, the mark's disc).
    func rSecondary(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(RColor.surfaceSecondaryAction, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: 1))
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 3, y: 4)
    }

    /// The one lit object on a screen (primary buttons, plan "yearly", the play well).
    func rLit(_ radius: CGFloat = RDimension.radiusControl, pressed: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let top = pressed ? RColor.glowPrimaryGradientTopPressed : RColor.glowPrimaryGradientTop
        let bottom = pressed ? RColor.glowPrimaryGradientBottomPressed : RColor.glowPrimaryGradientBottom
        return background(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom), in: shape)
            .overlay(shape.strokeBorder(RColor.glowPrimaryBloom, lineWidth: 3).blur(radius: 3).clipShape(shape))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.glowPrimaryRim, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.glowPrimaryRing, lineWidth: 1.5))
            .shadow(color: RColor.glowPrimaryCast, radius: 1, y: 2)
            .shadow(color: RColor.glowPrimaryHalo, radius: 7, y: 6)
            .foregroundStyle(RColor.glowPrimaryForeground)
    }
}
