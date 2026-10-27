@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2.topbar-back (founder, 27 Oct): the settings / entry back chevron is onboarding's 11.3pt glyph
/// (Paper ST-1 1GJ7-0, JR-4 1FRX-0 = ON-6 21CA-0), in the top bar's 36 circle.
@MainActor
struct RTopBarBackTests {
    @Test("the top bar's back uses onboarding's chevron scale, not the larger default")
    func backScale() {
        #expect(RTopBar.backGlyphScale == RIconButton.backChevronGlyphScale)
        #expect(RTopBar.backGlyphScale < RSymbol.defaultGlyphScale)
    }

    /// The chevron's inked height in points: the glyph drawn at `scale` of the 20 frame, rows with any ink counted.
    private func inkHeight(scale: CGFloat) throws -> CGFloat {
        let points = RIconButton.Role.topBar.glyph.points * scale
        let image = try #require(UIImage(
            systemName: "chevron.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: points, weight: .regular)
        )?.withTintColor(.black, renderingMode: .alwaysOriginal))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 4
        let size = image.size
        let cg = try #require(UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(at: .zero)
        }.cgImage)
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        let inked = (0 ..< height).filter { row in
            (0 ..< width).contains { pixels[(row * width + $0) * 4 + 3] > 127 }
        }
        let rows = try #require(inked.last.map { $0 - inked[0] + 1 })
        return CGFloat(rows) / format.scale
    }

    @Test("the chevron's ink is Paper's 11.3pt (±0.6) at the top bar's 20 frame; the old default was larger")
    func chevronInk() throws {
        let ink = try inkHeight(scale: RTopBar.backGlyphScale)
        #expect(abs(ink - 11.3) <= 0.6, "ink \(ink)")
        let old = try inkHeight(scale: RSymbol.defaultGlyphScale)
        #expect(old > ink + 1, "old \(old) vs \(ink)")
    }

    @Test("the circle stays the top bar's 36 (only the glyph changed)")
    func circle() {
        #expect(RIconButton.Role.topBar.visible == RDimension.sizeControlIcon)
        #expect(RDimension.sizeControlIcon == 36)
    }
}
