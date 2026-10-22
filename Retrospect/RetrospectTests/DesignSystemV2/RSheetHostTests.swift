@testable import Retrospect
import Testing

/// C19.1: one progress value drives the page behind, the scrim and the sheet; a release
/// dismisses by distance or velocity and otherwise snaps back.
struct RSheetHostTests {
    @Test("at rest the page behind scales to 0.94 and rounds to 12; closed, it is untouched")
    func behindFollowsProgress() {
        #expect(abs(RSheetProgress.behindScale(1) - RNumber.motionScaleBehindSheet) < 0.0001)
        #expect(abs(RSheetProgress.behindRadius(1) - RDimension.radiusBehindSheet) < 0.0001)
        #expect(RSheetProgress.behindScale(0) == 1)
        #expect(RSheetProgress.behindRadius(0) == 0)
        #expect(RSheetProgress.scrimOpacity(0.5) == 0.5)
    }

    @Test("rubber-banding past the top never moves the page further than at rest")
    func behindClamped() {
        #expect(abs(RSheetProgress.behindScale(1.2) - RNumber.motionScaleBehindSheet) < 0.0001)
        #expect(RSheetProgress.scrimOpacity(1.2) == 1)
    }

    @Test("a release at 141 dismisses and at 139 snaps back")
    func dismissByDistance() {
        #expect(RSheetProgress.dismisses(dragDown: 141, velocity: 0))
        #expect(!RSheetProgress.dismisses(dragDown: 139, velocity: 0))
    }

    @Test("a flick at 801 points a second dismisses from any height")
    func dismissByVelocity() {
        #expect(RSheetProgress.dismisses(dragDown: 10, velocity: 801))
        #expect(!RSheetProgress.dismisses(dragDown: 10, velocity: 799))
    }

    @Test("past the top the overshoot shrinks by 0.55")
    func rubberBand() {
        #expect(abs(RSheetProgress.rubberBanded(overshoot: -100) - -55) < 0.0001)
    }

    @Test("the sheet's offset follows the drag one to one")
    func offsetFollowsDrag() {
        let p = RSheetProgress.progress(dragDown: 100, height: 400)
        #expect(abs(p - 0.75) < 0.0001)
        #expect(abs(RSheetProgress.offset(p, height: 400) - 100) < 0.0001)
        #expect(RSheetProgress.offset(1, height: 400) == 0)
    }

    @Test("detents: medium is half the host, full leaves the strip of the page above")
    func detents() {
        #expect(abs(RSheetDetent.medium.height(in: 800) - 400) < 0.0001)
        #expect(RSheetDetent.full.height(in: 800) == 800 - RDimension.layoutSheetTop)
    }
}
