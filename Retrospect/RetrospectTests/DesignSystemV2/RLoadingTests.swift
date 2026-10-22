@testable import Retrospect
import Testing

/// C39.1: no skeleton under motion.duration.skeletonDelay, a skeleton at it, and "still working"
/// at motion.duration.stillWorking, all on an injected clock.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RLoadingTests {
    @Test("the phase follows the elapsed time at each threshold")
    func phaseThresholds() {
        #expect(RLoadingPhase(after: .milliseconds(399)) == .waiting)
        #expect(RLoadingPhase(after: .milliseconds(400)) == .skeleton)
        #expect(RLoadingPhase(after: .milliseconds(7999)) == .skeleton)
        #expect(RLoadingPhase(after: .seconds(8)) == .stillWorking)
    }

    private func settle(_ clock: TestClock) async {
        for _ in 0 ..< 1000 where clock.pendingSleeps == 0 {
            await Task.yield()
        }
    }

    @Test("no skeleton when content arrives at 399ms")
    func noSkeletonAt399() async {
        let clock = TestClock()
        let timer = RLoadingTimer()
        let run = Task { await timer.run(on: clock) }
        await settle(clock)
        clock.advance(by: .milliseconds(399))
        await Task.yield()
        #expect(timer.phase == .waiting)
        // the content arrives: the host cancels the wait
        run.cancel()
        await run.value
        #expect(timer.phase == .waiting)
        #expect(clock.heldSleeps == 0)
    }

    @Test("a late wake never pushes still working past 8s from the start")
    func deadlinesFromTheStart() async {
        let clock = TestClock()
        let timer = RLoadingTimer()
        let run = Task { await timer.run(on: clock) }
        await settle(clock)
        // one jump past both deadlines: the second sleep is already due, so both phases pass
        clock.advance(by: .seconds(8))
        await run.value
        #expect(timer.phase == .stillWorking)
    }

    @Test("the skeleton shows at 400ms, and still working at 8s")
    func skeletonThenStillWorking() async {
        let clock = TestClock()
        let timer = RLoadingTimer()
        let run = Task { await timer.run(on: clock) }
        await settle(clock)
        clock.advance(by: .milliseconds(400))
        await settle(clock)
        #expect(timer.phase == .skeleton)
        clock.advance(by: .milliseconds(7599))
        await Task.yield()
        #expect(timer.phase == .skeleton)
        clock.advance(by: .milliseconds(1))
        await run.value
        #expect(timer.phase == .stillWorking)
    }
}
