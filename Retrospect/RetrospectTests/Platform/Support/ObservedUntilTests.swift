import Observation
import Testing

@MainActor @Observable
private final class Counter {
    var value = 0
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ObservedUntilTests {
    @Test("a condition that is already true returns at once")
    func alreadyTrue() async {
        let counter = Counter()
        counter.value = 1
        await observedUntil { counter.value == 1 }
        #expect(counter.value == 1)
    }

    @Test("it waits through changes that don't meet the condition and wakes on the one that does")
    func wakesOnTheChangeThatMeetsIt() async {
        let counter = Counter()
        let waiting = Task { await observedUntil { counter.value == 3 } }
        for _ in 0 ..< 3 {
            await Task.yield()
            counter.value += 1
        }
        await waiting.value
        #expect(counter.value == 3)
    }
}
