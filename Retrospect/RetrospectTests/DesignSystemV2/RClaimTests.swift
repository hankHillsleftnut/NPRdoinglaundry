@testable import Retrospect
import SwiftUI
import Testing

/// V2 lane 0 · the claim (part 41 G2A-0 stated, G3C-0 asked): Paper's type, and the guess look shared
/// with the guess card. New styles are additive; the ones they sit next to are unchanged.
@MainActor
struct RClaimTests {
    @Test("the asked question is the inky card face one size up; meta and label are Geist 12")
    func styles() {
        #expect(RTextStyle.inkClaimAsked.size == RDimension.fontSize2xl)
        #expect(abs(Double(RTextStyle.inkClaimAsked.tracking) - RNumber.fontTrackingCard) < 0.0001)
        // the meta line is the shared .metaLine (Geist 12, snug, no tracking), like G2C-0
        #expect(RTextStyle.metaLine.size == RDimension.fontSizeSm)
        #expect(abs(Double(RTextStyle.metaLine.tracking) - RNumber.fontTrackingNone) < 0.0001)
        #expect(RTextStyle.claimGuessLabel.weight == .medium)
        // additive: the styles beside them keep their values
        #expect(RTextStyle.inkCard.size == RDimension.fontSizeXl)
        #expect(RTextStyle.inkTitle.size == RDimension.fontSize3xl)
    }

    @Test("balanced wrapping is opt-in: off by default, on where a screen asks (YO-4's belief)")
    func balancedOptIn() {
        #expect(!RClaim(kind: .stated, text: "x", meta: "y").balanced)
        #expect(RClaim(kind: .stated, text: "x", meta: "y", balanced: true).balanced)
        // YO-4 asks: the sheet's belief is the balanced claim at text-2xl
        let sheet = NodeSheet(node: SampleYou.priya, answer: { _ in }, close: {})
        #expect(sheet.claim.balanced)
        #expect(sheet.claim.statedStyle.size == RDimension.fontSize2xl)
        #expect(sheet.claim.text == SampleYou.priya.belief)
    }

    @Test("balanced, YO-4's belief keeps its three lines but no lone last word, at Paper's 346 width")
    func balancedLines() throws {
        let belief = "a close colleague. you come back lighter after time with her."
        let width: CGFloat = 346 // literal-ok: Paper 1GDU-0 width
        func rendered(_ balanced: Bool) throws -> CGImage {
            let claim = RClaim(kind: .stated, text: belief, meta: "fairly sure", statedStyle: .inkNodeBelief, balanced: balanced)
            let renderer = ImageRenderer(content: claim.frame(width: width))
            return try #require(renderer.cgImage)
        }
        let balanced = try rendered(true)
        let ragged = try rendered(false)
        // same height (the same number of lines), so balancing only evens them out
        #expect(balanced.height == ragged.height)
        // and it does even them out: the claim fills its 346 either way, but balanced its longest line
        // ends sooner ("a close colleague. you" against "a close colleague. you come"), so the ink stops
        // further from the right edge. Without the flag the two renders are the same picture.
        #expect(Self.inkedRightEdge(balanced) < Self.inkedRightEdge(ragged))
    }

    /// The right-most column with any ink in an RGBA image: where the longest line ends.
    private static func inkedRightEdge(_ image: CGImage) -> Int {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var edge = 0
        for y in 0 ..< height {
            for x in stride(from: width - 1, to: edge, by: -1) where bytes[(y * width + x) * 4 + 3] > 32 { // literal-ok: alpha threshold
                edge = x
                break
            }
        }
        return edge
    }

    @Test("VoiceOver reads the meta line with commas, not dots")
    func kinds() {
        let stated = RClaim(kind: .stated, text: "your best days start early.", meta: "stated · from what you did · very sure")
        let asked = RClaim(kind: .asked, text: "are mornings when you do your best work?", meta: "asked · fairly sure · rests on 3 mornings")
        #expect(stated.spokenMeta == "stated, from what you did, very sure")
        #expect(asked.spokenMeta == "asked, fairly sure, rests on 3 mornings")
    }
}
