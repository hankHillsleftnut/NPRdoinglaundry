import Testing

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
    }

    /// Yields until `condition` holds; the sleeping task needs a turn to register.
    private static func waitUntil(_ condition: () -> Bool) async throws {
        var turns = 0
        while !condition(), turns < 10000 {
            await Task.yield()
            turns += 1
        }
        try #require(condition())
    }
}
