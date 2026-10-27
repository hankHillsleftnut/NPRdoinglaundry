import CoreGraphics
@testable import Retrospect
import SwiftUI
import Testing

/// TEAR.motion (founder, 27 Oct): the perforation is punched circles only. "There isn't a line that
/// goes through the circles; it's just circles." The joined ticket is rendered and the paper on each
/// bridge between two holes, right on the perforation, must be the same paper as just above and just
/// below it: no stroke, seam or hairline drawn along the line, in light or dark.
@MainActor
struct TicketSeamTests {
    private let geometry = TicketGeometry(width: 354, compact: false)
    private let scale: CGFloat = 3

    private func render(_ scheme: ColorScheme) -> (pixels: [UInt8], width: Int)? {
        let ticket = ZStack(alignment: .topLeading) {
            RTicketStubPiece(geometry: geometry, tiles: SampleInvite.code, date: "21 oct 2026")
            RTicketBody(geometry: geometry, face: SampleInvite.face)
        }
        .frame(width: geometry.width, height: geometry.height, alignment: .topLeading)
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: ticket)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (pixels, width) : nil
    }

    /// The largest channel difference between the paper at (x, y) and at (x, y + dy), in points.
    private func difference(_ image: (pixels: [UInt8], width: Int), x: CGFloat, y: CGFloat, dy: CGFloat) -> Int {
        func pixel(_ px: CGFloat, _ py: CGFloat) -> [Int] {
            let index = (Int((py * scale).rounded()) * image.width + Int((px * scale).rounded())) * 4
            return (0 ..< 3).map { Int(image.pixels[index + $0]) }
        }
        let on = pixel(x, y)
        let off = pixel(x, y + dy)
        return zip(on, off).map { abs($0 - $1) }.max() ?? 0
    }

    @Test("no line along the perforation: each bridge between the holes is plain paper, light and dark", arguments: [ColorScheme.light, .dark])
    func circlesOnly(_ scheme: ColorScheme) throws {
        let image = try #require(render(scheme))
        let holes = TearPerforation(width: geometry.width).holes
        var worst = 0
        for (left, right) in zip(holes, holes.dropFirst()) {
            let bridge = (left + right) / 2
            // on the line, and the pixel either side of it, against the paper 4pt above and below
            for offset: CGFloat in [-1.0 / scale, 0, 1.0 / scale] {
                let y = geometry.perforationY + offset
                worst = max(worst, difference(image, x: bridge, y: y, dy: -4))
                worst = max(worst, difference(image, x: bridge, y: y, dy: 4))
            }
        }
        #expect(worst <= 6, "a line is drawn through the holes (\(worst) of 255 off the paper)")
    }
}
