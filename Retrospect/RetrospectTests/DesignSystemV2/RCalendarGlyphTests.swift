@testable import Retrospect
import SwiftUI
import Testing

/// YOU.calendar-icon: Paper's gridless calendar (c:icon/calendar, YO-4 1GD7-0), drawn because SF Symbols has
/// none (YO-D29). It must render, stay inside its box, and be the stroked page + header + two tabs, no grid.
@MainActor
struct RCalendarGlyphTests {
    @Test("it renders: an 18pt glyph draws ink inside its box, on a clear ground")
    func renders() throws {
        let renderer = ImageRenderer(content: RCalendarGlyph(tint: .black).frame(width: 18, height: 18)) // literal-ok: test box
        renderer.scale = 3 // literal-ok: test scale
        let image = try #require(renderer.cgImage)
        #expect(image.width == 54 && image.height == 54)
        let inked = Self.inkedPixels(image)
        // a stroked outline: some of the box, never all of it (a filled square would mean the grid or a fill)
        #expect(inked > 54 * 54 / 10)
        #expect(inked < 54 * 54 / 2)
    }

    @Test("the shape is the page, the header line and two tabs, and fits Paper's 24 grid")
    func shape() {
        let box = CGRect(x: 0, y: 0, width: 24, height: 24) // literal-ok: Paper grid
        let path = RCalendarGlyphShape().path(in: box)
        let bounds = path.boundingRect
        #expect(bounds.minX >= 4 && bounds.maxX <= 20) // literal-ok: inside the page's outer edge
        #expect(bounds.minY >= 3 && bounds.maxY <= 21) // literal-ok: tabs to the page's foot
        // the page's middle is empty: no grid lines cross its lower half (the stroke, not the fill)
        let ink = path.strokedPath(StrokeStyle(lineWidth: RCalendarGlyphShape.stroke))
        #expect(!ink.contains(CGPoint(x: 12, y: 15))) // literal-ok: page centre
        #expect(!ink.contains(CGPoint(x: 8.5, y: 15))) // literal-ok: under a tab, where a grid would cross
        #expect(ink.contains(CGPoint(x: 12, y: 10))) // literal-ok: the header line
    }

    @Test("the evidence row draws it for the calendar well; VoiceOver text is unchanged")
    func row() {
        let row = REvidenceRow(leading: .calendar, meta: "18 oct · calendar", words: "lunch with priya, an hour")
        #expect(row.accessibilityText == "18 oct, calendar, lunch with priya, an hour")
    }

    /// Pixels with any opacity in an RGBA image.
    private static func inkedPixels(_ image: CGImage) -> Int {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 32 }.count // literal-ok: alpha threshold
    }
}
