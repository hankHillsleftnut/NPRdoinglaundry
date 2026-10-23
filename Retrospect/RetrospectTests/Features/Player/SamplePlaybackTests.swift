import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SamplePlaybackTests {
    private let clock = TestClock()

    private func player(_ scenario: Flows.PlaybackScenario) -> SamplePlayback {
        SamplePlayback(scenario: scenario, clock: clock)
    }

    /// Lets the ticker reach its next sleep on the test clock.
    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 400 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Moves the test clock one beat at a time, waiting for the ticker between beats.
    private func beats(_ count: Int, _ player: SamplePlayback) async {
        for _ in 0 ..< count {
            await settle { clock.pendingSleeps == 1 }
            let before = (player.position, player.state)
            clock.advance(by: SamplePlayback.beat)
            await settle { player.position != before.0 || player.state != before.1 || clock.pendingSleeps == 1 }
        }
    }

    @Test("play is buffering first, then playing on the next beat; never playing straight away")
    func bufferingThenPlaying() async {
        let p = player(.briefPaused)
        p.play()
        #expect(p.state == .buffering)
        await beats(1, p)
        #expect(p.state == .playing)
        #expect(p.position == 0)
    }

    @Test("playing moves the position one second per simulated second, and at the rate")
    func oneSecondPerSecond() async {
        let p = player(.briefPaused)
        p.play()
        await beats(1, p)
        await beats(4, p)
        #expect(p.position == 1)
        p.rate = 2
        await beats(4, p)
        #expect(p.position == 3)
    }

    @Test("time never comes from the wall clock: without the test clock moving, nothing moves")
    func noWallClock() async throws {
        let p = player(.briefPlaying)
        let start = p.position
        try await Task.sleep(for: .milliseconds(600))
        #expect(p.position == start)
        #expect(p.state == .playing)
    }

    @Test("skip back 15 at 0:05 clamps to 0, and keeps the state")
    func skipBackClamps() {
        let p = player(.briefPaused)
        p.seek(to: 5)
        p.skip(by: -RTransport.backSeconds)
        #expect(p.position == 0)
        #expect(p.state == .paused)
    }

    @Test("skip forward under one minute is 15 seconds; a minute or longer is 30")
    func forwardUnderAMinute() {
        let short = player(.shortUnderMinute)
        RTransport.perform(.forward, on: short)
        #expect(short.position == 15)
        let long = player(.briefPaused)
        RTransport.perform(.forward, on: long)
        #expect(long.position == 30)
    }

    @Test("a seek past the end ends playback at the end; play after the end starts from 0")
    func seekPastEndEnds() async {
        let p = player(.briefPaused)
        p.play()
        await beats(1, p)
        p.seek(to: 500)
        #expect(p.state == .ended)
        #expect(p.position == 130)
        p.play()
        #expect(p.position == 0)
        #expect(p.state == .buffering)
    }

    @Test("playing to the end ends by itself")
    func playsToTheEnd() async {
        let p = player(.briefQuiet)
        p.seek(to: 39.5)
        p.play()
        await beats(3, p)
        #expect(p.state == .ended)
        #expect(p.position == 40)
    }

    @Test("a failed scenario never reports playing, whatever is tapped", arguments: [Flows.PlaybackScenario.failed, .offline])
    func failedNeverPlays(scenario: Flows.PlaybackScenario) async {
        let p = player(scenario)
        let start = p.state
        p.play()
        #expect(p.state == start)
        p.seek(to: 20)
        p.skip(by: 30)
        #expect(p.position == 0)
        clock.advance(by: .seconds(10))
        await settle { false }
        #expect(p.state == start)
        #expect(p.state != .playing)
    }

    @Test("the buffering scenario stays buffering")
    func staysBuffering() async {
        let p = player(.buffering)
        p.play()
        clock.advance(by: .seconds(5))
        await settle { false }
        #expect(p.state == .buffering)
    }

    @Test("pause stops the clock's effect; the current part follows the position")
    func pauseAndParts() async {
        let p = player(.briefPlaying)
        #expect(p.currentPart == 1)
        p.pause()
        #expect(p.state == .paused)
        clock.advance(by: .seconds(10))
        await settle { false }
        #expect(p.position == 48)
        p.seek(to: 95)
        #expect(p.currentPart == 2)
        p.seek(to: 0)
        #expect(p.currentPart == 0)
    }

    @Test("briefs show no buffered fraction; the rate stays in the live player's range")
    func bufferedAndRate() {
        let p = player(.long)
        #expect(p.buffered == nil)
        #expect(p.item?.parts.count == 12)
        p.rate = 5
        #expect(p.rate == 2)
        p.rate = 0.1
        #expect(p.rate == 0.5)
    }
}
