import Observation

/// Waits until `condition` reads true, with no clock: it is read now, and again after every change to an
/// `@Observable` property it read. Nothing here sleeps or guesses how long a busy machine takes, so a slow CI
/// runner can't fail it; a condition that never comes true is caught by the test's time limit instead.
///
/// The condition must read at least one observable property, or nothing can wake it.
@MainActor
func observedUntil(_ condition: @escaping @MainActor () -> Bool) async {
    while !condition() {
        // Read and track in the same main-actor turn as the check above: a change can't slip in between.
        await withCheckedContinuation { (changed: CheckedContinuation<Void, Never>) in
            withObservationTracking {
                _ = condition()
            } onChange: {
                changed.resume()
            }
        }
    }
}
