//
//  RCalendarGlyph.swift
//  YOU.calendar-icon: Paper's calendar glyph (c:icon/calendar, in use on YO-4 1GD7-0): an outlined
//  rounded page with two ring tabs on top and one header line, and no grid. SF Symbols has no gridless
//  calendar (DISCREPANCIES YO-D29), so this one is drawn. Paper draws it on a 24 grid at an 18 box with a
//  2-unit stroke and round ends; this shape keeps that grid and scales to whatever box it is given.
//  Used only where Paper draws this calendar (the evidence row's `.calendar` well); everywhere else keeps
//  the SF `calendar`. Decoration: hidden from VoiceOver by its callers.
//
import SwiftUI

/// The calendar's strokes on Paper's 24 grid, scaled into `rect`.
struct RCalendarGlyphShape: Shape {
    /// Paper's grid (the SVG's viewBox).
    static let grid: CGFloat = 24 // literal-ok: Paper icon viewBox
    /// Paper's stroke on that grid: the outline is 2 units wide (5.25 inside 3.25).
    static let stroke: CGFloat = 2 // literal-ok: Paper icon stroke
    /// The stroke under Bold Text: 3 units, so it thickens like the SF glyphs beside it (RSymbol's
    /// `.regular` goes bold through `legibilityWeight`) and the two kinds of well stay one weight.
    static let strokeBold: CGFloat = 3 // literal-ok: Paper icon stroke under Bold Text

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / Self.grid
        let origin = CGPoint(x: rect.midX - Self.grid * unit / 2, y: rect.midY - Self.grid * unit / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        }
        var path = Path()
        // the page: Paper's outer edge 3.25…20.75 × 4.5…21.25, so its centre line sits 1 unit in
        path.addRoundedRect(
            in: CGRect(origin: point(4.25, 5.5), size: CGSize(width: 15.5 * unit, height: 14.75 * unit)),
            cornerSize: CGSize(width: 3 * unit, height: 3 * unit)
        ) // literal-ok: Paper 1GD7-0 geometry
        // the header line under the tabs (Paper's filled band at 9…11)
        path.move(to: point(5.25, 10)) // literal-ok: Paper 1GD7-0 geometry
        path.addLine(to: point(18.75, 10)) // literal-ok: Paper 1GD7-0 geometry
        // the two ring tabs (Paper's centres 8.5 and 15.5, from 2.5 into the page)
        for x in [8.5, 15.5] as [CGFloat] { // literal-ok: Paper 1GD7-0 geometry
            path.move(to: point(x, 3.5)) // literal-ok: Paper 1GD7-0 geometry
            path.addLine(to: point(x, 7.25)) // literal-ok: Paper 1GD7-0 geometry
        }
        return path
    }
}

/// The calendar glyph at a size, in a tint (icon.default by default), stroked as Paper draws it.
struct RCalendarGlyph: View {
    var size: CGFloat = RDimension.sizeIconInWell
    var tint: Color = RColor.iconDefault

    @Environment(\.legibilityWeight) private var legibilityWeight

    /// Paper's stroke at this size; under Bold Text the heavier one, as the SF glyph in the row above.
    var lineWidth: CGFloat {
        let units = legibilityWeight == .bold ? RCalendarGlyphShape.strokeBold : RCalendarGlyphShape.stroke
        return units * size / RCalendarGlyphShape.grid
    }

    var body: some View {
        RCalendarGlyphShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("calendar glyph") {
    HStack(spacing: RDimension.space4) {
        RCalendarGlyph()
            .frame(width: RDimension.sizeSourceIcon, height: RDimension.sizeSourceIcon)
            .background(RColor.surfaceWash, in: RShape.rect(RDimension.radiusDefault))
        RCalendarGlyph(size: RDimension.sizeIconLarge)
        RSymbol(name: "calendar")
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
