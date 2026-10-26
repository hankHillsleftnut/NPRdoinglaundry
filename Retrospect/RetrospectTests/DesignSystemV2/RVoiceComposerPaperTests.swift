import CoreGraphics
@testable import Retrospect
import SwiftUI
import Testing

/// SH.composer: the Paper look draws Paper's box-shadows exactly (spread kept, outer layers only
/// outside the shape, the top light as the inset crescent), and today's look stays the default.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RVoiceComposerPaperTests {
    /// Geometry only (x, y, blur, spread), in Paper's order.
    private func geometry(_ layers: [RShadowLayer]) -> [[CGFloat]] {
        layers.map { [$0.x, $0.y, $0.blur, $0.spread] }
    }

    @Test("rest: depth.boxShadow.composer.rest is Paper's c:voice-composer (1F7K-0), insets included")
    func restStackIsPaper() {
        let rest = RComposerPaperSurface.rest
        #expect(geometry(rest) == [[0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 0.5], [0, 1, 2, 0], [0, 12, 28, -12], [0, 24, 60, -20]])
        #expect(rest.map(\.inset) == [true, true, false, false, false, false])
        #expect(rest.map(\.color) == [
            RColor.depthStrokeInnerTop, RColor.depthStrokeInner, RColor.depthStrokeOuter,
            RColor.depthShadowContact, RColor.depthShadowCast, RColor.depthShadowAmbient,
        ])
    }

    @Test("listening: depth.boxShadow.composer.listening is Paper's 26LI-0 / 1F6E-0 / GEG-0")
    func listeningStackIsPaper() {
        let listening = RComposerPaperSurface.listening
        #expect(geometry(listening) == [
            [0, 1, 0, 0], [0, 0, 0, 0.5], [0, 1, 2, 0], [-64, 10, 34, -16], [72, -6, 30, -14], [18, 20, 36, -18], [-10, -12, 26, -16],
        ])
        #expect(listening.map(\.inset) == [true, false, false, false, false, false, false])
        #expect(listening.map(\.color) == [
            RColor.depthStrokeInnerTop, RColor.glowPrimaryRing, RColor.depthShadowContact,
            RColor.voiceGlowPool, RColor.voiceGlowLift, RColor.voiceGlowUnder, RColor.voiceGlowTop,
        ])
        #expect(Array(listening.dropFirst(2)) == RElevation.glowListening)
    }

    @Test("raised pill: depth.boxShadow.pill.raised rest (D9Z-0) and pressed (DA6-0)")
    func pillStacksArePaper() {
        #expect(geometry(RElevation.boxShadowPillRaisedRest) == [[0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 0.5], [0, 1, 1.5, 0], [0, 4, 6, -2]])
        #expect(geometry(RElevation.boxShadowPillRaisedPressed) == [[0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 0.5], [0, 0.5, 1, 0], [0, 1, 2, -1]])
        #expect(Array(RElevation.boxShadowPillRaisedRest.dropFirst(3)) == RElevation.pillRaisedRest)
        #expect(Array(RElevation.boxShadowPillRaisedPressed.dropFirst(3)) == RElevation.pillRaisedPressed)
    }

    @Test("today's look stays the default for the composer and the pill")
    func defaultsUnchanged() {
        #expect(RVoiceComposer(mode: .constant(.speaking), text: .constant("")).look == .current)
        #expect(RPill(title: "connect", style: .raised) {}.look == .current)
    }

    @Test("outer shadows are never drawn under the shape, and do reach below it")
    func outerShadowsStayOutside() throws {
        let image = try render(RBoxShadows(layers: RComposerPaperSurface.rest.filter { !$0.inset }, radius: RDimension.radiusComposer))
        // the middle of the bar: nothing (a translucent surface would otherwise show its own shadow)
        #expect(image.alpha(x: 177, y: 28) == 0)
        #expect(image.alpha(x: 30, y: 28) == 0)
        // 6pt under the bottom edge: the cast and ambient
        #expect(image.alpha(x: 177, y: 62) > 0)
    }

    @Test("the top light is Paper's inset 0 1 0: 1pt on the flat top, gone below it, thinning round the corner")
    func topLightIsTheInsetCrescent() throws {
        let image = try render(RInsetShadows(layers: [RPaperStrokes.innerTop], radius: RDimension.radiusComposer))
        #expect(image.alpha(x: 177, y: 0.5) > 0.9)
        #expect(image.alpha(x: 177, y: 1.5) == 0)
        // on the left curve 6pt down the crescent is still there (edge at x 10.7, shifted edge at 12.0);
        // the old strip stopped at the top row
        #expect(image.alpha(x: 11.3, y: 6) > 0)
        #expect(image.alpha(x: 14, y: 6) == 0)
    }

    // MARK: Rendering

    /// The view on a 354 × 56 frame (the bar) inside 80pt of room, at @3x, light mode.
    private func render(_ view: some View) throws -> RenderedImage {
        let room = RDimension.space16 + RDimension.space4
        let renderer = ImageRenderer(content: view
            .frame(width: 354, height: 56) // literal-ok: Paper's bar, 1F7K-0
            .padding(room)
            .environment(\.colorScheme, .light))
        renderer.scale = 3
        let cgImage = try #require(renderer.cgImage)
        return try #require(RenderedImage(cgImage, scale: 3, origin: room))
    }
}

/// Premultiplied RGBA pixels, read at points relative to the bar's top-left.
private struct RenderedImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]
    let scale: CGFloat
    let origin: CGFloat

    init?(_ image: CGImage, scale: CGFloat, origin: CGFloat) {
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        bytes = data
        self.scale = scale
        self.origin = origin
    }

    func alpha(x: CGFloat, y: CGFloat) -> Double {
        let px = Int(((x + origin) * scale).rounded(.down))
        let py = Int(((y + origin) * scale).rounded(.down))
        guard px >= 0, py >= 0, px < width, py < height else { return 0 }
        return Double(bytes[(py * width + px) * 4 + 3]) / 255
    }
}
