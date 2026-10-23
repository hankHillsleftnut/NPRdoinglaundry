import CoreGraphics
@testable import Retrospect
import Testing

/// PI2.2: the tear's arithmetic (docs/team/flows/first-run/views.md): clamped progress, the rubber
/// band, 0.61 springs back and 0.62 commits, a fast flick commits, one tick per hole and never two
/// within 40ms.
struct TearMathTests {
    let math = TearMath(width: 354)

    @Test("progress follows the finger and is held to the line")
    func clamped() {
        #expect(math.progress(x: 177) == 0.5)
        #expect(math.progress(x: -50) == 0)
        #expect(math.progress(x: 500) == 1)
    }

    @Test("past either end the movement is rubber-banded by 0.55")
    func rubberBand() {
        #expect(abs(math.rawProgress(x: -35.4) - -0.055) < 0.0001)
        #expect(abs(math.rawProgress(x: 389.4) - 1.055) < 0.0001)
    }

    @Test("0.61 springs back, 0.62 commits")
    func threshold() {
        #expect(!TearMath.commits(progress: 0.61, velocity: 0))
        #expect(TearMath.commits(progress: 0.62, velocity: 0))
    }

    @Test("a 900 pt/s flick at 0.3 commits, 700 pt/s doesn't")
    func flick() {
        #expect(TearMath.commits(progress: 0.3, velocity: 900))
        #expect(!TearMath.commits(progress: 0.3, velocity: 700))
        #expect(!TearMath.commits(progress: 0.3, velocity: -900))
    }

    @Test("progress 0.5 hides the first 10 holes and shows 11")
    func holes() {
        #expect(TearMath.hiddenHoles(progress: 0.5) == 10)
        #expect(TearMath.holeCount - TearMath.hiddenHoles(progress: 0.5) == 11)
        #expect(TearMath.hiddenHoles(progress: 1) == 21)
        #expect(TearMath.hiddenHoles(progress: 0) == 0)
    }

    @Test("the stub droops in proportion to the torn length, up to 11 degrees")
    func droop() {
        #expect(TearMath.droop(progress: 0) == 0)
        #expect(TearMath.droop(progress: 1) == 11)
        #expect(TearMath.droop(progress: 2) == 11)
    }

    @Test("a finger more than 44pt off the line is a release")
    func wander() {
        #expect(TearMath.isTearing(dy: 44))
        #expect(!TearMath.isTearing(dy: -45))
    }

    @Test("a tick fires once per hole and never twice within 40ms")
    func ticks() {
        var ticker = HoleTicker()
        let first = ticker.tick(progress: 0.01, at: .milliseconds(0))
        let second = ticker.tick(progress: 0.05, at: .milliseconds(100))
        // the next hole arrives 10ms later: held back, and not replayed afterwards
        let tooSoon = ticker.tick(progress: 0.10, at: .milliseconds(110))
        let replay = ticker.tick(progress: 0.10, at: .milliseconds(300))
        let next = ticker.tick(progress: 0.15, at: .milliseconds(400))
        let same = ticker.tick(progress: 0.15, at: .milliseconds(500))
        #expect(!first)
        #expect(second)
        #expect(!tooSoon)
        #expect(!replay)
        #expect(next)
        #expect(!same)
    }
}
