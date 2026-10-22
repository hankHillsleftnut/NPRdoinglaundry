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

    /// Rounded at the top corners only (sheets).
    static func top(_ radius: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: RCorner.style)
    }
}

extension View {
    /// z 0.5 · a translucent tint that reads as part of the page (pills, wells, bubbles).
    func rWash(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        background(RColor.surfaceWash, in: RShape.rect(radius))
    }

    /// z −1 · a field you type or search into.
    func rSunken(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.surfaceControl, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: 0.5))
            .overlay(alignment: .top) {
                // inset 0 1 2 sunken shade, darkest at the top edge
                shape.stroke(RColor.depthShadowSunken, lineWidth: 2).blur(radius: 1).offset(y: 1).clipShape(shape)
            }
    }

    /// z 1 · floats above the page: cards, the composer, the mini-player.
    func rRaised(_ radius: CGFloat = RDimension.radiusCard) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: 1))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.depthShadowContact, radius: 1, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 14, y: 12)
            .shadow(color: RColor.depthShadowAmbient, radius: 30, y: 24)
    }

    /// The cream secondary control (raised pills, plan buttons, the mark's disc). Pressed, the
    /// shadow collapses toward the page (Paper c:pill/raised/pressed: 0 .5 1 contact, 0 1 2 −1 cast).
    func rSecondary(_ radius: CGFloat = RDimension.radiusControl, pressed: Bool = false) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.surfaceSecondaryAction, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: 1))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.depthShadowContact, radius: pressed ? 0.5 : 0.75, y: pressed ? 0.5 : 1)
            .shadow(color: RColor.depthShadowCast, radius: pressed ? 1 : 3, y: pressed ? 1 : 4)
    }

    /// The raised mark above an empty state (Paper G7Y-0: inner-top 1, outer 0.5, contact 0 1 2,
    /// cast 0 8 18 −8). SwiftUI has no spread, so the cast's −8 is carried by a smaller radius.
    func rEmptyMark(_ radius: CGFloat = RDimension.radiusControl) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.depthShadowContact, radius: 1, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 5, y: 8)
    }

    /// A sheet's raised panel, rounded at the top only (Paper B9C-0: inner-top 1, an outer 0.5 line
    /// above the edge, cast 0 −8 24 −8 up onto the page behind).
    func rSheet(_ radius: CGFloat = RDimension.radiusSheet) -> some View {
        let shape = RShape.top(radius)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5).offset(y: -0.5).mask(alignment: .top) { Rectangle().frame(height: radius) })
            .shadow(color: RColor.depthShadowCast, radius: 8, y: -8)
    }

    /// Dialogs and other overlays (Paper E4B-0, elevation.overlay: inner-top 1, inner 1, outer 0.5,
    /// shadowOverlay2 0 4 12, shadowOverlay1 0 24 48 −12).
    func rOverlay(_ radius: CGFloat = RDimension.radiusField) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: 1))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.shadowOverlay2, radius: 6, y: 4)
            .shadow(color: RColor.shadowOverlay1, radius: 18, y: 24)
    }

    /// Menus (elevation.menu: 0 8 24 −6 and 0 2 6). No outline: Paper's menu (QE-0) draws none.
    func rMenu(_ radius: CGFloat = RDimension.radiusField) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.backgroundRaised, in: shape)
            .shadow(color: RColor.shadowMenu2, radius: 3, y: 2)
            .shadow(color: RColor.shadowMenu1, radius: 9, y: 8)
    }

    /// A popover floating over the page (elevation.popover: 0 18 40 −10 and 0 2 6).
    func rPopover(_ radius: CGFloat = RDimension.radiusField) -> some View {
        let shape = RShape.rect(radius)
        return background(RColor.backgroundRaised, in: shape)
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
            .shadow(color: RColor.shadowPopover2, radius: 3, y: 2)
            .shadow(color: RColor.shadowPopover1, radius: 15, y: 18)
    }

    /// The destructive confirm, the only place a danger glow appears (Paper E4G-0: gradient
    /// glow.danger top → bottom, rim inset 1, edge 0.5, shadow 0 1 2, danger tint 0 6 14 −6).
    func rLitDanger(_ radius: CGFloat = RDimension.radiusControl, pressed: Bool = false) -> some View {
        let shape = RShape.rect(radius)
        let top = pressed ? RColor.glowDangerGradientTopPressed : RColor.glowDangerGradientTop
        let bottom = pressed ? RColor.glowDangerGradientBottomPressed : RColor.glowDangerGradientBottom
        return background(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom), in: shape)
            .overlay(shape.strokeBorder(RColor.glowDangerEdge, lineWidth: 0.5))
            .overlay(alignment: .top) { shape.strokeBorder(RColor.glowDangerRim, lineWidth: 1).mask(alignment: .top) { Rectangle().frame(height: 1) } }
            .shadow(color: RColor.shadowPrimaryAction2, radius: 1, y: 1)
            .shadow(color: RColor.depthTintDanger, radius: pressed ? 2 : 4, y: pressed ? 3 : 6)
            .foregroundStyle(RColor.glowDangerForeground)
    }

    /// The one lit object on a screen (primary buttons, plan "yearly", the play well).
    func rLit(_ radius: CGFloat = RDimension.radiusControl, pressed: Bool = false) -> some View {
        let shape = RShape.rect(radius)
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
