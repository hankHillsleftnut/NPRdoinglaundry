//
//  YouMap.swift
//  V2.you · YO-1's map (Paper c:you-map/orbits/rest 1G6Z-0): the at-rest picture with its four names
//  (RYouMapRest, labels on), a 390 × 360 window centred on the 354 column so it bleeds past the margins,
//  and a 44 target on each named orb. RYouMapRest is leased to SI.fidelity, so it is used as it is, never
//  edited (DISCREPANCIES YO-D19); the orb centres below are Paper's (1G75-0 … 1G78-0, the same in 1F5K-0).
//  A tap opens that node's sheet (YO-4); with no `open` the orbs are only the picture.
//
import SwiftUI

struct YouMap: View {
    /// Opens a named orb (by its name); nil: the map is only a picture.
    var open: ((String) -> Void)?
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.dynamicTypeSize) private var typeSize

    /// As on the splash: 0.78 on a short phone (build notes), 0.6 at accessibility sizes so the rows
    /// under it keep their room; the 44 targets never shrink.
    private var scale: CGFloat {
        typeSize.isAccessibilitySize ? 0.6 : (compact ? 0.78 : 1)
    } // literal-ok: map scales, as SignInScreen

    /// Paper's window onto the drawing (1G6Z-0) and the column it centres on (1G6Y-0).
    static let window = CGSize(width: 390, height: 360) // literal-ok: Paper 1G6Z-0

    /// Centre of each frosted orb in the drawing, by name (Paper 1G78-0, 1G77-0, 1G76-0, 1G75-0: 44 orbs).
    static let orbCentres: [String: CGPoint] = [
        "maya": CGPoint(x: 115, y: 134), "running": CGPoint(x: 265, y: 121),
        "the river": CGPoint(x: 275, y: 226), "work": CGPoint(x: 125, y: 239),
    ] // literal-ok: Paper orb centres

    var body: some View {
        ZStack(alignment: .topLeading) {
            RYouMapRest(scale: scale, labels: true)
            if let open {
                ForEach(RYouMapRest.names, id: \.0) { name, _ in
                    if let centre = Self.orbCentres[name] {
                        Button { open(name) } label: {
                            Color.clear
                                .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                        .accessibilityHint("opens what i know about them")
                        .offset(
                            x: centre.x * scale - RDimension.sizeTouchTarget / 2,
                            y: centre.y * scale - RDimension.sizeTouchTarget / 2
                        )
                    }
                }
            }
        }
        .frame(width: Self.window.width * scale, height: Self.window.height * scale, alignment: .topLeading)
        .clipped()
        // the window is wider than the column: centre it and let it bleed past the margins (1G6Y-0)
        .frame(maxWidth: .infinity)
        .frame(height: Self.window.height * scale)
    }
}
