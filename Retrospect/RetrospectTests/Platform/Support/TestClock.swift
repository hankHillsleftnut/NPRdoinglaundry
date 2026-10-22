import Foundation

/// A clock that only moves when a test says so. Code under test sleeps on it
/// (backoff, timeouts); the test calls `advance(by:)` and the sleepers whose
/// deadline has passed wake, in deadline order. No real time passes.
final class TestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [UUID: Sleeper] = [:]
    private var cancelledBeforeWaiting: Set<UUID> = []

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Duration {
        .zero
    }

    /// How many sleeps are waiting for the clock to move.
    var pendingSleeps: Int {
        lock.withLock { sleepers.count }
    }

    func sleep(until deadline: Instant, tolerance _: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let outcome: Result<Void, Error>? = lock.withLock {
                    if cancelledBeforeWaiting.remove(id) != nil {
                        return .failure(CancellationError())
                    }
                    if deadline <= current {
                        return .success(())
                    }
                    sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let outcome {
                    continuation.resume(with: outcome)
                }
            }
        } onCancel: {
            // Cancellation can arrive before the sleep is registered; remember
            // it so the registration sees it and throws instead of waiting.
            let sleeper: Sleeper? = lock.withLock {
                guard let sleeper = sleepers.removeValue(forKey: id) else {
                    cancelledBeforeWaiting.insert(id)
                    return nil
                }
                return sleeper
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock forward and wakes every sleep that is now due.
    func advance(by duration: Duration) {
        let due: [Sleeper] = lock.withLock {
            current = current.advanced(by: duration)
            let ready = sleepers.filter { $0.value.deadline <= current }
            ready.keys.forEach { sleepers.removeValue(forKey: $0) }
            return ready.values.sorted { $0.deadline < $1.deadline }
        }
        due.forEach { $0.continuation.resume() }
    }
}
