//
//  RPrinterSlot.swift
//  C42: the printer slot. At rest an 8pt sunken bar, 20 wider than the ticket (board T1 `2I01-0`);
//  printing, a curved mouth whose lip is a smile, with a shading band where the paper bends in
//  (T2a `2IDN-0`, `2IV7-0`). Decorative: hidden from VoiceOver. The real bend is the ticket's own
//  3D tilt, not this view.
//
import SwiftUI

struct RPrinterSlot: View {
    enum State: Equatable { case rest, printing }

    /// The ticket's width; the slot is 20 wider.
    let ticketWidth: CGFloat
    var state: State = .rest
    @Environment(\.colorSchemeContrast) private var contrast

    static let bar = RDimension.space2
    static let mouth = RDimension.space6

    var width: CGFloat {
        ticketWidth + RDimension.space5
    }

    var body: some View {
        ZStack(alignment: .top) {
            lip.opacity(state == .printing ? 1 : 0)
            bar.opacity(state == .rest ? 1 : 0)
        }
        .frame(width: width, height: Self.mouth, alignment: .top)
        .animation(RMotion.snappy, value: state)
        .accessibilityHidden(true)
    }

    /// The resting bar.
    private var bar: some View {
        RShape.pill
            .fill(RColor.backgroundSunken)
            .frame(width: width, height: Self.bar)
            .overlay(alignment: .top) {
                RShape.pill.stroke(RColor.depthShadowSunken, lineWidth: RDimension.sizeBorderRing).blur(radius: 1.5)
                    .offset(y: 2) // literal-ok: sunken shade 0 2 3
                    .clipShape(RShape.pill)
            }
            .overlay(RShape.pill.strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .overlay(alignment: .bottom) {
                Rectangle().fill(RColor.depthStrokeInnerTop).frame(height: RDimension.sizeBorderDefault).offset(y: RDimension.sizeBorderDefault)
            }
            .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The mouth: a crescent lip with the bend band above it.
    private var lip: some View {
        ZStack(alignment: .top) {
            SlotLip()
                .fill(RColor.backgroundSunken)
                .overlay(SlotLip().stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
                .shadow(color: RColor.depthShadowCast, radius: 1.5, y: -2) // literal-ok: inner cast 0 -2 3
                .frame(width: width, height: Self.mouth)
        }
    }
}

/// A smile: the top edge sags a little, the bottom edge sags deeper.
private struct SlotLip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.height * 0.25 // literal-ok: lip curvature
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + top * 2))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2))
        path.closeSubpath()
        return path
    }
}

/// Where the paper curls into the slot (board `2IV7-0`): 56 tall, clear to the cast shade.
struct RPrinterBend: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: RColor.depthShadowAmbient.opacity(0), location: 0),
                .init(color: RColor.depthShadowAmbient, location: 0.45), // literal-ok: board 2IV7-0
                .init(color: RColor.depthShadowCast, location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: RDimension.space12 + RDimension.space2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
