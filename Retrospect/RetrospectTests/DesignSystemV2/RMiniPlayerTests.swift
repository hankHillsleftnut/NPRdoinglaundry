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

    @Test("the surface draws Paper's GX0-0 stack through rBoxShadows: spreads kept, hairline outside, top light inset")
    func surfaceShadow() {
        let stack = RMiniPlayer.surfaceShadow
        #expect(stack == RElevation.boxShadowMiniPlayer)
        #expect(stack.count == 5)
        // the top light is the only inset layer, and it is 0 1 0 (a crescent, not a strip)
        #expect(stack.filter(\.inset) == [RShadowLayer(color: RColor.depthStrokeInnerTop, x: 0, y: 1, blur: 0, spread: 0, inset: true)])
        // the 0.5 hairline sits fully outside the edge (a spread, not a centred stroke)
        #expect(stack.contains(RShadowLayer(color: RColor.depthStrokeOuter, x: 0, y: 0, blur: 0, spread: 0.5)))
        // the cast and ambient keep their negative spread, which SwiftUI's .shadow would drop (the "lip")
        let cast = stack.first { $0.color == RColor.depthShadowCast }
        let ambient = stack.first { $0.color == RColor.depthShadowAmbient }
        #expect(cast.map { [$0.y, $0.blur, $0.spread] } == [4, 10, -4])
        #expect(ambient.map { [$0.y, $0.blur, $0.spread] } == [10, 30, -10])
    }

    @Test("an existing shadow token is unchanged by the additive mini-player one")
    func existingTokensUnchanged() {
        #expect(RElevation.boxShadowStrokeOuter == [RShadowLayer(color: RColor.depthStrokeOuter, x: 0, y: 0, blur: 0, spread: 0.5)])
        #expect(RElevation.boxShadowComposerRest.count == 6)
        #expect(RElevation.boxShadowPillRaisedRest.count == 5)
    }

    @Test("each phase picks its well glyph and VoiceOver label", arguments: [
        (RMiniPlayer.Phase.playing, "pause.fill", "pause"),
        (.buffering, "pause.fill", "pause"),
        (.paused, "play.fill", "play"),
        (.failed, "arrow.clockwise", "try again"),
    ])
    func wellMapping(phase: RMiniPlayer.Phase, symbol: String, label: String) {
        #expect(phase.wellSymbol == symbol)
        #expect(phase.wellLabel == label)
        #expect(UIImage(systemName: phase.wellSymbol) != nil)
    }

    @Test("the progress line shows in every phase but failed (GXB-0)")
    func progressLine() {
        #expect(RMiniPlayer.Phase.playing.showsProgress)
        #expect(RMiniPlayer.Phase.paused.showsProgress)
        #expect(RMiniPlayer.Phase.buffering.showsProgress)
        #expect(!RMiniPlayer.Phase.failed.showsProgress)
    }

    @Test("the played share stays inside 0...1")
    func playedClamp() {
        #expect(RMiniPlayer.played(0.34) == 0.34)
        #expect(RMiniPlayer.played(-1) == 0)
        #expect(RMiniPlayer.played(3) == 1)
        #expect(RMiniPlayer.played(.nan) == 0)
    }
}
