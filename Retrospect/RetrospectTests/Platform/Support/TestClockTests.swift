import Testing

@Suite(.timeLimit(.minutes(1)))
struct TestClockTests {
    @Test("a sleep wakes only once the clock passes its deadline")
    func aSleepWakesOnlyOnceTheClockPassesItsDeadline() async throws {
        let clock = TestClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        let sleep = Task { try await clock.sleep(until: deadline) }
        try await Self.waitUntil { clock.pendingSleeps == 1 }

        clock.advance(by: .seconds(1))
        #expect(clock.pendingSleeps == 1)

        clock.advance(by: .seconds(1))
        try await sleep.value
        #expect(clock.pendingSleeps == 0)
        #expect(clock.now == deadline)
    }

    @Test("a sleep whose deadline has passed returns at once")
    func aSleepWhoseDeadlineHasPassedReturnsAtOnce() async throws {
        let clock = TestClock()
        clock.advance(by: .seconds(5))

        try await clock.sleep(until: clock.now.advanced(by: .seconds(-1)))

        #expect(clock.pendingSleeps == 0)
    }

    @Test("a cancelled sleep throws and stops waiting")
    func aCancelledSleepThrowsAndStopsWaiting() async throws {
        let clock = TestClock()
        let sleep = Task { try await clock.sleep(until: clock.now.advanced(by: .seconds(60))) }
        try await Self.waitUntil { clock.pendingSleeps == 1 }

        sleep.cancel()

        await #expect(throws: CancellationError.self) { try await sleep.value }
        #expect(clock.pendingSleeps == 0)
        #expect(clock.heldSleeps == 0)
    }

    @Test("a cancel after a sleep has ended leaves nothing behind")
    func aCancelAfterASleepHasEndedLeavesNothingBehind() async throws {
        let clock = TestClock()
        let sleep = Task { try await clock.sleep(until: clock.now.advanced(by: .seconds(1))) }
        try await Self.waitUntil { clock.pendingSleeps == 1 }
        clock.advance(by: .seconds(1))
        try await sleep.value

        sleep.cancel()

        #expect(clock.heldSleeps == 0)
    }

    @Test("advancing wakes every sleep that is due and leaves later ones waiting")
    func advancingWakesEverySleepThatIsDue() async throws {
        let clock = TestClock()
        let start = clock.now
        let first = Task { try await clock.sleep(until: start.advanced(by: .seconds(1))) }
        let second = Task { try await clock.sleep(until: start.advanced(by: .seconds(2))) }
        let later = Task { try await clock.sleep(until: start.advanced(by: .seconds(5))) }
        try await Self.waitUntil { clock.pendingSleeps == 3 }

        clock.advance(by: .seconds(2))
        try await first.value
        try await second.value

        #expect(clock.pendingSleeps == 1)
        later.cancel()
        await #expect(throws: CancellationError.self) { try await later.value }
        #expect(clock.heldSleeps == 0)
    }

    /// Yields until `condition` holds, giving up after a second of real time:
    /// the sleeping task needs a turn to register, never longer.
    private static func waitUntil(_ condition: () -> Bool) async throws {
        let limit = ContinuousClock.now.advanced(by: .seconds(1))
        while !condition(), ContinuousClock.now < limit {
            await Task.yield()
        }
        try #require(condition())
    }
}
