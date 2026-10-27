//
//  TearTicket.swift
//  TEAR.motion: the ticket drawn from a tear frame (TearSimulation). One structure from the first
//  touch to rest, never a branch swap, so the stub is never cross-faded: it is the same view while
//  it peels, hangs, snaps, falls and lies kept. The stub is one sheet bent by TearBend.metal.
//
import SwiftUI

struct TearTicket: View {
    let geometry: TicketGeometry
    let frame: TearFrame
    var face: Session.TicketFace?
    var tiles: String
    var date: String
    var label: RTicketStubLabel = .admitsOne

    /// Room below the stub for the curve and the fall to draw into (a distortion only draws inside its
    /// layer): a full 17° peel of the widest stub hangs about 80 below its line.
    static let room: CGFloat = 150 // literal-ok: drawing room for the bend, not layout

    var body: some View {
        let width = geometry.width
        let stub = frame.stub
        let padded = geometry.height + Self.room
        let anchor = UnitPoint(x: stub.anchor.x / width, y: stub.anchor.y / padded)
        let hinge = UnitPoint(x: stub.anchor.x / width, y: geometry.perforationY / padded)
        let separated = frame.separated
        return ZStack(alignment: .topLeading) {
            RTicketStubPiece(geometry: geometry, tiles: tiles, date: date, label: label, hiddenHoles: frame.hiddenHoles)
                .frame(width: width, height: padded, alignment: .top)
                .distortionEffect(
                    ShaderLibrary.tearBend(
                        .float(stub.bendFront), .float(geometry.perforationY), .float(stub.bendAngle * .pi / 180),
                        .float(stub.bendLength), .float(RNumber.motionTearCurveExponent)
                    ),
                    maxSampleOffset: CGSize(width: width, height: Self.room)
                )
                // the soft shadow under the torn edge while it hangs (TicketStage's, at 60%)
                .shadow(color: RColor.depthShadowCast.opacity(separated ? 0 : stub.shadow * 0.6), radius: 3, y: 3) // literal-ok: TicketStage's torn-edge shadow
                .rotation3DEffect(.degrees(stub.tilt), axis: (x: 1, y: 0, z: 0), anchor: hinge, perspective: TicketStage.perspective)
                .scaleEffect(stub.lift, anchor: anchor)
                .rotationEffect(.degrees(stub.angle), anchor: anchor)
                .rTicketShadow(enabled: separated)
                .offset(stub.offset)
            RTicketBody(geometry: geometry, face: face, hiddenHoles: frame.hiddenHoles)
                .rotationEffect(.degrees(frame.body.angle), anchor: .top)
                .offset(y: frame.body.y)
                .rTicketShadow(enabled: separated)
        }
        .frame(width: width, height: geometry.height, alignment: .topLeading)
        .offset(x: frame.lean)
        // the poses are the simulation's, frame by frame: no transaction may animate them
        .transaction { $0.animation = nil }
    }
}
