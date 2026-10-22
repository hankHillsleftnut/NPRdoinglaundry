import Foundation

/// A clock that only moves when a test says so. Code under test sleeps on it
/// (backoff, timeouts); the test calls `advance(by:)`, and every sleep whose
/// deadline has passed is resumed, earliest deadline first. (When the resumed
/// tasks then run is up to the scheduler.) No real time passes.
final class TestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    /// One sleep's life. It's in `sleeps` from the moment it starts until it
    /// ends, so a cancellation that arrives at any point finds it or finds
    /// nothing, and never leaves anything behind.
    private enum Sleep {
        /// Started, not yet waiting on its continuation.
        case starting
        /// Cancelled while starting; the wait throws as soon as it begins.
        case cancelled
        case waiting(deadline: Instant, continuation: CheckedContinuation<Void, Error>)
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleeps: [UUID: Sleep] = [:]

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Duration {
        .zero
    }

    /// How many sleeps are waiting for the clock to move.
    var pendingSleeps: Int {
        lock.withLock {
            sleeps.values.filter {
                if case .waiting = $0 {
                    true
                } else {
                    false
                }
            }.count
        }
    }

    func sleep(until deadline: Instant, tolerance _: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        lock.withLock { sleeps[id] = .starting }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let outcome: Result<Void, Error>? = lock.withLock {
                    if case .cancelled = sleeps[id] {
                        sleeps[id] = nil
                        return .failure(CancellationError())
                    }
                    if deadline <= current {
                        sleeps[id] = nil
                        return .success(())
                    }
                    sleeps[id] = .waiting(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let outcome {
                    continuation.resume(with: outcome)
                }
            }
        } onCancel: {
            let waiting: CheckedContinuation<Void, Error>? = lock.withLock {
                switch sleeps[id] {
                case .starting:
                    sleeps[id] = .cancelled
                    return nil
                case let .waiting(_, continuation):
                    sleeps[id] = nil
                    return continuation
                case .cancelled, nil:
                    // Already ended: nothing to cancel, nothing to keep.
                    return nil
                }
            }
            waiting?.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock forward and resumes every sleep that is now due,
    /// earliest deadline first.
    func advance(by duration: Duration) {
        let due: [CheckedContinuation<Void, Error>] = lock.withLock {
            current = current.advanced(by: duration)
            var ready: [UUID: Instant] = [:]
            var continuations: [UUID: CheckedContinuation<Void, Error>] = [:]
            for (id, sleep) in sleeps {
                if case let .waiting(deadline, continuation) = sleep, deadline <= current {
                    ready[id] = deadline
                    continuations[id] = continuation
                }
            }
            ready.keys.forEach { sleeps[$0] = nil }
            return ready.sorted { $0.value < $1.value }.compactMap { continuations[$0.key] }
        }
        due.forEach { $0.resume() }
    }

    /// Sleeps the clock is still holding in any state; zero once every sleep
    /// has ended, however it ended.
    var heldSleeps: Int {
        lock.withLock { sleeps.count }
    }
}
