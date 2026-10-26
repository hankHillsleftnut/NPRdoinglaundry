//
//  RYouMapRest.swift
//  C38.1: the You map at rest, as it sits behind the first-run words (Paper `1F5K-0`). The rings,
//  nine edges, four frosted orbs, five blurred far orbs and the self orb. The splash (ON-1/2) names
//  the four orbs with Paper's sample words (maya, running, the river, work; founder "Fix", 24 Oct);
//  welcome back (AC-1) keeps them hidden, as its build note says (never a person's node names
//  before sign-in). Static, so Reduce
//  Motion needs nothing; hidden from VoiceOver. Each orb is Paper's recipe: a faint white base and
//  two soft washes of colour from opposite corners, a top rim, a hairline and a cast. The palette
//  fills have no semantic token, so they live here with the dark file's twins
//  (`--color-dark-sky-*`, `--color-dark-paper-300`), as in RBrandWash.
//
import SwiftUI

extension RTextStyle {
    /// A name beside an orb (Paper `1F5O-0`): Geist 11, regular, leading snug, no tracking.
    static let mapName = RTextStyle(
        family: .label, size: RDimension.fontSizeXs, weight: .regular,
        tracking: RNumber.fontTrackingNone, leading: 1.3, relativeTo: .caption2
    )
}

struct RYouMapRest: View {
    @Environment(\.colorScheme) private var scheme

    private static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255) // literal-ok: palette hex
    }

    /// A palette colour and its twin in Paper's dark file.
    private struct Tone {
        let light: Color
        let dark: Color
    }

    private static let sky200 = Tone(light: hex(0xB3E1FF), dark: hex(0x88B3CF)) // palette.sky.200
    private static let sky300 = Tone(light: hex(0x7FCDFF), dark: hex(0x58A3D2)) // palette.sky.300
    private static let sky700 = Tone(light: hex(0x1F7DBA), dark: hex(0x1271AB)) // palette.sky.700
    private static let sky800 = Tone(light: hex(0x165E8C), dark: hex(0x0C5581)) // palette.sky.800
    private static let paper300 = Tone(light: hex(0xE4DBCE), dark: hex(0xB6ADA1)) // palette.paper.300
    private static let theme = Tone(light: RColor.mapNodeTheme, dark: RColor.mapNodeTheme)
    private static let goal = Tone(light: RColor.mapNodeGoal, dark: RColor.mapNodeGoal)

    /// One wash: an ellipse of colour fading to nothing, sized and placed in shares of the orb.
    private struct Wash {
        let tone: Tone
        let size: CGSize // radii as shares of the orb (CSS `ellipse 80% 70%`)
        let at: UnitPoint
    }

    /// Paper's orb recipes, in the order the JSX draws them.
    private enum Recipe {
        static let skyPaper = [
            Wash(tone: sky200, size: CGSize(width: 0.7, height: 0.6), at: UnitPoint(x: 0.8, y: 0.1)),
            Wash(tone: paper300, size: CGSize(width: 0.8, height: 0.8), at: UnitPoint(x: 0.1, y: 0.9)),
        ]
        static let skyDeep = [
            Wash(tone: sky300, size: CGSize(width: 0.8, height: 0.7), at: UnitPoint(x: 0.25, y: 0.1)),
            Wash(tone: sky700, size: CGSize(width: 0.8, height: 0.8), at: UnitPoint(x: 1, y: 1)),
        ]
        static let theme = [
            Wash(tone: RYouMapRest.theme, size: CGSize(width: 0.7, height: 0.6), at: UnitPoint(x: 0.85, y: 0.15)),
            Wash(tone: sky800, size: CGSize(width: 0.9, height: 0.9), at: UnitPoint(x: 0, y: 1)),
        ]
        static let goal = [
            Wash(tone: RYouMapRest.goal, size: CGSize(width: 0.7, height: 0.6), at: UnitPoint(x: 0.3, y: 0.15)),
            Wash(tone: sky800, size: CGSize(width: 0.85, height: 0.85), at: UnitPoint(x: 0.9, y: 0.95)),
        ]
    } // literal-ok: Paper 1F5K-0 orb gradients

    /// Drawing size inside the 402x380 frame, and the centre every ring is drawn around.
    private static let drawing = CGSize(width: 390, height: 360) // literal-ok: Paper 1F5K-0 drawing
    private static let frame = CGSize(width: 402, height: 380) // literal-ok: Paper 1F5K-0 frame
    private static let centre = CGPoint(x: 195, y: 180) // literal-ok: Paper 1F5K-0 centre

    private static let edgeEnds: [CGPoint] = [
        (115, 134), (265, 121), (275, 226), (125, 239), (168, 24), (351, 153), (249, 328), (141, 328), (47, 126),
    ].map { CGPoint(x: $0.0, y: $0.1) } // literal-ok: Paper edge ends
    /// Top-left corner and recipe of each frosted 44 orb (maya, running, the river, work).
    private static let frosted: [(CGPoint, [Wash])] = [
        (CGPoint(x: 93, y: 112), Recipe.skyDeep), (CGPoint(x: 243, y: 99), Recipe.theme),
        (CGPoint(x: 253, y: 204), Recipe.skyPaper), (CGPoint(x: 103, y: 217), Recipe.goal),
    ] // literal-ok: Paper orb positions
    /// The five far orbs: smaller, blurred, at opacity.pressed.
    private static let far: [(CGPoint, [Wash])] = [
        (CGPoint(x: 158, y: 14), Recipe.skyPaper), (CGPoint(x: 341, y: 143), Recipe.skyDeep),
        (CGPoint(x: 239, y: 318), Recipe.theme), (CGPoint(x: 131, y: 318), Recipe.skyPaper),
        (CGPoint(x: 37, y: 116), Recipe.skyDeep),
    ] // literal-ok: Paper far-orb positions

    /// The four orbs' names (Paper `1F5O-0`, `1F5N-0`, `1F5M-0`, `1F5L-0`): sample words, top-left
    /// corner of each label in the drawing.
    static let names: [(String, CGPoint)] = [
        ("maya", CGPoint(x: 100, y: 86)), ("running", CGPoint(x: 293, y: 113)),
        ("the river", CGPoint(x: 303, y: 218)), ("work", CGPoint(x: 110, y: 266)),
    ] // literal-ok: Paper label positions

    /// Scale for small phones (build notes: 0.78 at SE).
    var scale: CGFloat = 1
    /// Paper's sample names beside the orbs: on for the splash, off for welcome back.
    var labels = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            rings
            edges
            ForEach(Array(Self.far.enumerated()), id: \.offset) { _, orb in
                frostedOrb(orb.1, diameter: 20, castRadius: 2, castY: 3) // literal-ok: Paper far orb 20, cast 0 3 7 -3
                    .blur(radius: 1.5) // literal-ok: Paper blur 1.5
                    .opacity(RNumber.opacityPressed)
                    .offset(x: orb.0.x, y: orb.0.y)
            }
            ForEach(Array(Self.frosted.enumerated()), id: \.offset) { _, orb in
                frostedOrb(orb.1, diameter: 44, castRadius: 5, castY: 7) // literal-ok: Paper orb 44, cast 0 7 15 -5
                    .offset(x: orb.0.x, y: orb.0.y)
            }
            selfOrb.offset(x: 163, y: 148) // literal-ok: Paper self orb
            if labels {
                ForEach(Self.names, id: \.0) { name, corner in
                    Text(name)
                        .rText(.mapName)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize()
                        .padding(.vertical, RDimension.sizeBorderRing)
                        .padding(.horizontal, RDimension.space1)
                        .offset(x: corner.x, y: corner.y)
                }
                // part of the picture, which scales as one: the words don't grow with Dynamic Type
                .dynamicTypeSize(.large)
            }
        }
        .frame(width: Self.drawing.width, height: Self.drawing.height, alignment: .topLeading)
        // Paper draws the 390 × 360 drawing at the frame's top-left (0, 0), not centred in it
        .frame(width: Self.frame.width, height: Self.frame.height, alignment: .topLeading)
        .scaleEffect(scale)
        .frame(width: Self.frame.width * scale, height: Self.frame.height * scale)
        .accessibilityHidden(true)
    }

    private func color(_ tone: Tone) -> Color {
        scheme == .dark ? tone.dark : tone.light
    }

    /// Paper's frosted orb: white 12% base, two washes clipped to the disc, a top rim, a hairline, a cast.
    private func frostedOrb(_ washes: [Wash], diameter: CGFloat, castRadius: CGFloat, castY: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12)) // literal-ok: palette.alpha.white12
            ForEach(Array(washes.enumerated()), id: \.offset) { _, wash in
                Ellipse()
                    .fill(EllipticalGradient(colors: [color(wash.tone), color(wash.tone).opacity(0)], center: .center, endRadiusFraction: 0.5))
                    .frame(width: diameter * wash.size.width * 2, height: diameter * wash.size.height * 2) // literal-ok: radii to diameters
                    .position(x: diameter * wash.at.x, y: diameter * wash.at.y)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(RColor.glowPrimaryRim, lineWidth: 1).offset(y: 1).mask(Circle())) // literal-ok: Paper rim 0 1 0 inset
        .overlay(Circle().strokeBorder(RColor.depthStrokeOuter, lineWidth: 0.5)) // literal-ok: Paper hairline 0.5
        .shadow(color: RColor.depthShadowCast, radius: castRadius, y: castY)
    }

    /// The person: a lit sphere (sky.300 at the highlight, the self colour, sky.800 at the far edge),
    /// a 4 canvas ring then a 1 glow ring, a cool tint below and a bloom around.
    private var selfOrb: some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: color(Self.sky300), location: 0),
                    .init(color: RColor.mapNodeSelf, location: 0.55),
                    .init(color: color(Self.sky800), location: 1),
                ],
                center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: 62 // literal-ok: farthest corner from 34% 28% of 64
            ))
            .frame(width: 64, height: 64) // literal-ok: Paper self orb 64
            .overlay(Circle().stroke(RColor.glowPrimaryRim, lineWidth: 1).offset(y: 1).mask(Circle())) // literal-ok: Paper rim 0 1 0 inset
            .background(Circle().fill(RColor.backgroundCanvas).frame(width: 72, height: 72)) // literal-ok: 4 canvas ring
            .background(Circle().fill(RColor.glowPrimaryRing).frame(width: 74, height: 74)) // literal-ok: 1 glow ring past it
            .shadow(color: RColor.depthTintPrimary, radius: 7, y: 10) // literal-ok: Paper 0 10 22 -8
            .shadow(color: RColor.glowPrimaryBloom, radius: 24) // literal-ok: Paper bloom 48
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
}
