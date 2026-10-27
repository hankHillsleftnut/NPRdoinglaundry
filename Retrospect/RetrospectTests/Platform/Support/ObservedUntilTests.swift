import Observation
import Testing

@MainActor @Observable
private final class Counter {
    var value = 0
}

/// How often a wait read its condition (a plain count, not observed, so counting never wakes the wait).
@MainActor
private final class Reads {
    var count = 0
}

/// Whether a wait has ended (plain, not observed).
@MainActor
private final class Woke {
    var yes = false
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ObservedUntilTests {
    /// Lets the waiting task run until it has read its condition at least `count` times.
    /// Stops at the time limit too (it cancels the test), so a regression fails instead of hanging.
    private func untilRead(_ reads: Reads, _ count: Int) async {
        while reads.count < count, !Task.isCancelled {
            await Task.yield()
        }
    }

    /// Waits for `task`, passing the test's cancellation (the time limit) on to it.
    private func finished(_ task: Task<Void, Never>) async {
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @Test("a condition that is already true returns at once")
    func alreadyTrue() async {
        let counter = Counter()
        counter.value = 1
        await observedUntil { counter.value == 1 }
        #expect(counter.value == 1)
    }

    @Test("it waits through a change that doesn't meet the condition and wakes on the one that does")
    func wakesOnTheChangeThatMeetsIt() async {
        let counter = Counter()
        let reads = Reads()
        let woke = Woke()
        let waiting = Task {
            await observedUntil {
                reads.count += 1
                return counter.value == 2
            }
            woke.yes = true
        }
        // the wait reads the condition twice (the check, then the tracked read) and suspends
        await untilRead(reads, 2)
        counter.value = 1
        // woken by the change, it reads twice more, finds it unmet and waits again
        await untilRead(reads, 4)
        #expect(!woke.yes, "a change that doesn't meet the condition doesn't end the wait")
        counter.value = 2
        await finished(waiting)
        #expect(woke.yes)
    }

    @Test("a wait whose condition never comes true returns when its task is cancelled")
    func cancelledWaitReturns() async {
        let counter = Counter()
        let reads = Reads()
        let waiting = Task {
            await observedUntil {
                reads.count += 1
                return counter.value == 99
            }
        }
        await untilRead(reads, 2)
        waiting.cancel()
        await finished(waiting)
        #expect(counter.value == 0)
    }
}
