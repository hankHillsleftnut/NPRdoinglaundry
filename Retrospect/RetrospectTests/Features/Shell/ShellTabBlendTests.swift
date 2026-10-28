@testable import Retrospect
import SwiftUI
import Testing

/// TABBAR.blend: the shell's tab edge. Content runs under the bar and dissolves into it: the blur
/// ramps over blur.tabBlend.rise to the tab screens' strength with colour kept, the canvas eases in
/// on gradient.fadeToCanvas to fully opaque at the bar (never a hard edge), drawn with the masked
/// material on every iOS (the system edge lives under the bar, where the bar's canvas would hide it).
/// Tokens are additive: the tab screens' own edge is unchanged for the pages outside the shell.
@MainActor
struct ShellTabBlendTests {
    @Test("the blend rises 90 above the bar (72 on a short phone) to the tab screens' blur, colour kept")
    func rise() {
        let blend = RProgressiveBlurStyle.tabBarBlend
        #expect(blend.edge == .bottom)
        #expect(blend.band == RDimension.blurTabBlendRise)
        #expect(RDimension.blurTabBlendRise == 90)
        #expect(blend.bandCompact == RDimension.blurTabBlendRiseCompact)
        #expect(RDimension.blurTabBlendRiseCompact == 72)
        #expect(blend.maxRadius == RDimension.blurTabMax)
        #expect(blend.saturation == RNumber.blurTabSaturation)
        #expect(blend.saturation > 1, "the edge must keep colour, never grey")
        #expect(blend.maskedBlur, "the blur sits above the bar, where the system scroll edge can't draw it")
    }

    @Test("the canvas eases in over the whole band and is opaque at the bar, in light and dark alike")
    func tint() throws {
        let tint = try #require(RProgressiveBlurStyle.tabBarBlend.tint)
        #expect(tint.start == RColor.backgroundCanvas)
        #expect(tint.end == RColor.backgroundCanvas)
        #expect(tint.startOpacity == 0)
        #expect(tint.endOpacity == 1, "nothing may read through the bar's labels")
        #expect(tint.from.resolved(in: RDimension.blurTabBlendRise) == 0)
        #expect(tint.solidFrom.resolved(in: RDimension.blurTabBlendRise) == 1)
        #expect(tint.curve == .fadeToCanvas)
    }

    @Test("gradient.fadeToCanvas: 13 stops, 0 to 1, never stepping back, eased at both ends")
    func fadeToCanvas() throws {
        let stops = RTintCurve.fadeToCanvas.stops
        #expect(stops.count == 13)
        #expect(stops.first == 0)
        #expect(stops.last == 1)
        for (earlier, later) in zip(stops, stops.dropFirst()) {
            #expect(later > earlier)
        }
        // eased: the first and last steps are the smallest, the middle step the largest
        let steps = zip(stops, stops.dropFirst()).map { $1 - $0 }
        let middle = try #require(steps.max())
        #expect(steps[0] < middle && steps[steps.count - 1] < middle)
        #expect(steps[0] < steps[1] && steps[steps.count - 1] < steps[steps.count - 2])
        #expect(RTintCurve.straight.stops == [0, 1])
    }

    @Test("the pages' own tab edge is unchanged, and the shell's override is off outside the shell")
    func tabEdgeUnchanged() {
        let edge = RProgressiveBlurStyle.tabEdge
        #expect(edge.band == 70)
        #expect(edge.bandCompact == 60)
        #expect(edge.maxRadius == 14)
        #expect(edge.tint?.endOpacity == RNumber.opacityDisabled)
        #expect(edge.tint?.curve == .straight)
        #expect(!edge.maskedBlur)
        #expect(edge != .tabBarBlend)
        #expect(EnvironmentValues().rShellTabEdge == nil)
    }
}
