@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · the mini-player (part 45: playing GX0-0, failed GXB-0): Paper's sizes from tokens, the
/// failure line as Paper words it, and a real symbol for every well glyph.
@MainActor
struct RMiniPlayerTests {
    @Test("Paper's numbers: 64 tall, a 44 thumb and well, 2pt progress, 12 between, 8 at the sides")
    func sizes() {
        #expect(RDimension.sizePlayerTray == 64)
        #expect(RDimension.sizeControlDefault == 44)
        #expect(RDimension.sizeBorderRing == 2)
        #expect(RDimension.space3 == 12)
        #expect(RDimension.space2 == 8)
        #expect(RDimension.radiusControl >= RDimension.sizePlayerTray / 2) // a true pill
    }

    @Test("the failure line is Paper's (GXF-0)")
    func failedLine() {
        #expect(RMiniPlayer.failedLine == "couldn't play · tap to retry")
    }

    @Test("the well's glyphs exist")
    func glyphs() {
        for name in ["pause.fill", "play.fill", "arrow.clockwise"] {
            #expect(UIImage(systemName: name) != nil, "no SF Symbol \(name)")
        }
    }

    @Test("the title style is SF text-md medium (GX3-0); additive")
    func titleStyle() {
        #expect(RTextStyle.miniPlayerTitle.size == RDimension.fontSizeMd)
        #expect(RTextStyle.miniPlayerTitle.weight == .medium)
    }
}
