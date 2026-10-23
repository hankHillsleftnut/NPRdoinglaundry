//
//  RYouMapRest.swift
//  C38.1: the You map at rest, as it sits behind the first-run words (Paper `1F5K-0`). The rings,
//  nine edges, four frosted orbs, five blurred far orbs and the self orb. Labels are hidden on
//  purpose: no node names before sign-in (build notes, plans-consistency 1.23). Static, so Reduce
//  Motion needs nothing; hidden from VoiceOver. The palette fills have no semantic token, so they
//  live here with dark twins, as in RBrandWash.
//
import SwiftUI

struct RYouMapRest: View {
    @Environment(\.colorScheme) private var scheme

    private static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) // literal-ok: palette hex
    }

    private typealias Pair = (light: Color, dark: Color)
    private static let sky200 = hex(0xB3E1FF) // palette.sky.200
    private static let sky300 = hex(0x7FCDFF) // palette.sky.300
    private static let sky700 = hex(0x1F7DBA) // palette.sky.700
    private static let sky800 = hex(0x165E8C) // palette.sky.800
    private static let paper300 = hex(0xE4DBCE) // palette.paper.300

    /// Drawing size inside the 402x380 frame, and the centre every ring is drawn around.
    private static let drawing = CGSize(width: 390, height: 360) // literal-ok: Paper 1F5K-0 drawing
    private static let frame = CGSize(width: 402, height: 380) // literal-ok: Paper 1F5K-0 frame
    private static let centre = CGPoint(x: 195, y: 180) // literal-ok: Paper 1F5K-0 centre

    private static let edgeEnds: [CGPoint] = [
        (115, 134), (265, 121), (275, 226), (125, 239), (168, 24), (351, 153), (249, 328), (141, 328), (47, 126),
    ].map { CGPoint(x: $0.0, y: $0.1) } // literal-ok: Paper edge ends
    /// Top-left corner of each frosted 44 orb.
    private static let frosted: [(CGPoint, Pair)] = [
        (CGPoint(x: 93, y: 112), (sky200, paper300)), (CGPoint(x: 243, y: 99), (sky300, sky700)),
        (CGPoint(x: 253, y: 204), (RColor.mapNodeTheme, sky800)), (CGPoint(x: 103, y: 217), (RColor.mapNodeGoal, sky800)),
    ] // literal-ok: Paper orb positions and fills
    private static let far: [CGPoint] = [
        CGPoint(x: 158, y: 14), CGPoint(x: 341, y: 143), CGPoint(x: 239, y: 318), CGPoint(x: 131, y: 318), CGPoint(x: 37, y: 116),
    ] // literal-ok: Paper far-orb positions

    /// Scale for small phones (build notes: 0.78 at SE).
    var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            rings
            edges
            ForEach(Array(Self.far.enumerated()), id: \.offset) { _, origin in
                Circle().fill(RColor.mapNodeSource).frame(width: 20, height: 20) // literal-ok: Paper far orb 20
                    .blur(radius: 1.5) // literal-ok: Paper blur 1.5
                    .opacity(RNumber.opacityPressed)
                    .offset(x: origin.x, y: origin.y)
            }
            ForEach(Array(Self.frosted.enumerated()), id: \.offset) { _, orb in
                Circle().fill(scheme == .dark ? orb.1.dark : orb.1.light).frame(width: 44, height: 44) // literal-ok: Paper orb 44
                    .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
                    .offset(x: orb.0.x, y: orb.0.y)
            }
            selfOrb.offset(x: 163, y: 148) // literal-ok: Paper self orb
        }
        .frame(width: Self.drawing.width, height: Self.drawing.height, alignment: .topLeading)
        .frame(width: Self.frame.width, height: Self.frame.height)
        .scaleEffect(scale)
        .frame(width: Self.frame.width * scale, height: Self.frame.height * scale)
        .accessibilityHidden(true)
    }

    private var rings: some View {
        ZStack {
            Circle().stroke(RColor.mapEdge, lineWidth: 0.5).frame(width: 184, height: 184).opacity(0.5) // literal-ok: r92
            Circle().stroke(RColor.mapEdge, lineWidth: 0.5).frame(width: 316, height: 316).opacity(0.35) // literal-ok: r158
        }
        .position(Self.centre)
    }

    private var edges: some View {
        Path { path in
            for end in Self.edgeEnds {
                path.move(to: Self.centre)
                path.addLine(to: end)
            }
        }
        .stroke(RColor.mapEdge, style: StrokeStyle(lineWidth: 0.75, lineCap: .round)) // literal-ok: Paper edge 0.75
    }

    private var selfOrb: some View {
        Circle()
            .fill(LinearGradient(
                stops: [.init(color: Self.sky300, location: 0), .init(color: RColor.mapNodeSelf, location: 0.55), .init(color: Self.sky800, location: 1)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 64, height: 64) // literal-ok: Paper self orb 64
            .overlay(Circle().strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault))
            .background(Circle().stroke(RColor.backgroundCanvas, lineWidth: 8).padding(-4)) // literal-ok: 4 canvas ring
            .background(Circle().stroke(RColor.glowPrimaryRing, lineWidth: 10).padding(-5)) // literal-ok: 5 ring
            .shadow(color: RColor.depthTintPrimary, radius: 8, y: 4) // literal-ok: Paper cast
            .shadow(color: RColor.glowPrimaryBloom, radius: 24) // literal-ok: bloom 48
    }
}
