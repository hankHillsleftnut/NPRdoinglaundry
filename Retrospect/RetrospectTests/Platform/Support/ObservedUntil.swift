import Foundation
import Observation

/// Waits until `condition` reads true, with no clock: it is read now, and again after every change to an
/// `@Observable` property it read. Nothing here sleeps or guesses how long a busy machine takes, so a slow CI
/// runner can't fail it. A condition that never comes true is caught by the test's time limit: that cancels the
/// test, a cancelled wait returns, and the test's own `#expect`s then fail with a clear message.
///
/// The condition must read at least one observable property, or nothing but cancellation can wake it.
@MainActor
func observedUntil(_ condition: @escaping @MainActor () -> Bool) async {
    while !condition(), !Task.isCancelled {
        let once = ResumeOnce()
        await withTaskCancellationHandler {
            // Read and track in the same main-actor turn as the check above: a change can't slip in between.
            await withCheckedContinuation { (changed: CheckedContinuation<Void, Never>) in
                once.hold(changed)
                withObservationTracking {
                    _ = condition()
                } onChange: {
                    once.resume()
                }
            }
        } onCancel: {
            once.resume()
        }
    }
}

/// Resumes a continuation exactly once, whichever comes first: a change, or a cancellation (even one that
/// arrives before the continuation is held).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var resumed = false

    func hold(_ continuation: CheckedContinuation<Void, Never>) {
        let resumeNow: Bool = lock.withLock {
            if resumed {
                return true
            }
            self.continuation = continuation
            return false
        }
        if resumeNow {
            continuation.resume()
        }
    }

    func resume() {
        let held: CheckedContinuation<Void, Never>? = lock.withLock {
            resumed = true
            defer { continuation = nil }
            return continuation
        }
        held?.resume()
    }
}
