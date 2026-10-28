//
//  RTicketShape.swift
//  C41.1: the invitation as an object. A continuous rounded rectangle with two real cuts (notches)
//  centred on the left and right edges at the perforation, subtracted from the path, never circles
//  painted in the page colour. The shadow goes on this shape, so it bends around the bites. The two
//  halves (`body` above the perforation, `stub` below) keep their half-bites and take small corners
//  where they were torn apart. Paper: round 2 board `2HXP-0`, notches r10 at y 264.
//
import SwiftUI

/// The ticket's measures, from the board: 354 wide on a 402 phone, 389 tall, the perforation at 264;
/// on a short screen the gift band is 104 instead of 132 and everything below moves up.
struct TicketGeometry: Equatable {
    let width: CGFloat
    let compact: Bool

    static let notchRadius: CGFloat = 10 // literal-ok: board 2HXP-0, a cut of radius 10
    static let holeRowHeight = RDimension.space5

    var meshHeight: CGFloat {
        compact ? 104 : 132
    } // literal-ok: board 2HXR-0, 104 on SE
    /// The perforation's centre line.
    var perforationY: CGFloat {
        compact ? 236 : 264
    } // literal-ok: board 2HXP-0
    var height: CGFloat {
        perforationY + 125
    } // literal-ok: board 2HYN-0, the stub is 115 below the row's far edge
    var stubHeight: CGFloat {
        height - perforationY - Self.holeRowHeight / 2
    }
}

struct RTicketShape: Shape {
    enum Part { case whole, body, stub }

    var part: Part = .whole
    var geometry: TicketGeometry

    func path(in rect: CGRect) -> Path {
        let big = RDimension.radiusCard
        let small = RDimension.radiusSmall
        let seam = geometry.perforationY
        let base: Path = switch part {
        case .whole:
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: big, bottomLeading: big, bottomTrailing: big, topTrailing: big), style: RCorner.style)
                .path(in: rect)
        case .body:
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: big, bottomLeading: small, bottomTrailing: small, topTrailing: big), style: RCorner.style)
                .path(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: seam))
        case .stub:
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: small, bottomLeading: big, bottomTrailing: big, topTrailing: small), style: RCorner.style)
                .path(in: CGRect(x: rect.minX, y: seam, width: rect.width, height: rect.height - seam))
        }
        var cuts = Path()
        for x in [rect.minX, rect.maxX] {
            let radius = TicketGeometry.notchRadius
            cuts.addEllipse(in: CGRect(x: x - radius, y: seam - radius, width: radius * 2, height: radius * 2))
        }
        return base.subtracting(cuts)
    }
}

extension View {
    /// The ticket's depth (board `2IV3-0`, "shadow follows the cut"): paper fill, inner strokes and
    /// the drop-shadow stack, all on the cut shape. `shadowed: false` leaves the shadow to a group.
    func rTicketSurface(_ shape: RTicketShape, shadowed: Bool = true) -> some View {
        // a stroke twice the inset's width, clipped to the shape, leaves the inset half inside
        let inset = RDimension.sizeBorderDefault * 2
        return background(RColor.backgroundRaised, in: shape)
            .overlay {
                ZStack(alignment: .top) {
                    shape.stroke(RColor.depthStrokeInner, lineWidth: inset).clipShape(shape)
                    shape.stroke(RColor.depthStrokeInnerTop, lineWidth: inset)
                        .clipShape(shape)
                        .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
                    // the rim: light mode's warm hairline; on night a faint light edge, so the paper never
                    // sinks into the canvas where its shadow can't show (TEAR.motion, founder 27 Oct)
                    shape.stroke(RTicketRim.color, lineWidth: RDimension.sizeBorderHairline)
                }
                .mask { RTicketSeamGap(shape: shape, band: inset * 1.5) } // literal-ok: the strokes' reach either side of the edge
            }
            .modifier(RTicketShadow(amount: shadowed ? 1 : 0))
    }

    func rTicketShadow(enabled: Bool) -> some View {
        modifier(RTicketShadow(amount: enabled ? 1 : 0))
    }

    /// The same shadow at a share of its strength (0…1), for a hand-over between two shadows that
    /// must never pop (the tear's stub leaving the body).
    func rTicketShadow(amount: Double) -> some View {
        modifier(RTicketShadow(amount: min(max(amount, 0), 1)))
    }
}

/// Contact `0 1 1` and cast `0 10 14` (no ambient, no spread), as drawn. SwiftUI's radius is half
/// the CSS blur. Off (amount 0) the colours are transparent, so the view's identity never changes.
private struct RTicketShadow: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: RColor.depthShadowContact.opacity(amount), radius: 0.5, y: 1) // literal-ok: board 2IV3-0
            .shadow(color: RColor.depthShadowCast.opacity(amount), radius: 7, y: 10) // literal-ok: board 2IV3-0
    }
}

/// Where a half's edge strokes may draw: everywhere but the perforation between the notches. Paper
/// draws the perforation as punched circles only (founder 27 Oct: "there isn't a line that goes
/// through the circles; it's just circles"), so the body's and the stub's edges along it carry no
/// stroke, joined, tearing or torn; the paper parts through the bridges with no line drawn.
struct RTicketSeamGap: View {
    let shape: RTicketShape
    let band: CGFloat

    var body: some View {
        let geometry = shape.geometry
        ZStack(alignment: .topLeading) {
            Rectangle()
            if shape.part != .whole {
                Rectangle()
                    .frame(width: geometry.width - TicketGeometry.notchRadius * 2, height: band) // literal-ok: between the two notches
                    .offset(x: TicketGeometry.notchRadius, y: geometry.perforationY - band / 2)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }
}

/// The ticket's outside edge (`depth.stroke.rim`). Debug builds can draw it as before the rim
/// (`-TicketRim off`), for the dark-mode question card's side-by-side; release always draws the rim.
enum RTicketRim {
    static var color: Color {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "TicketRim") == "off" {
            return RColor.depthStrokeOuter
        }
        #endif
        return RColor.depthStrokeRim
    }
}
