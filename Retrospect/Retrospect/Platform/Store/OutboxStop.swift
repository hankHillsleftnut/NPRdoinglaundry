import Foundation

extension Store.Outbox {
    /// Stopping (PL3.1a). The person signed out: no new drain starts, the send in flight is cancelled, and this returns
    /// when the drain has ended, so nothing of theirs is sent or written after it.
    func stop() async {
        stopped = true
        for task in [reachabilityWatch, retryWake] {
            task?.cancel()
        }
        reachabilityWatch = nil
        retryWake = nil
        inFlightSend?.cancel()
        if isDraining {
            // Parked, not polled: a cancelled caller cannot spin here, and the drain's end wakes it.
            await withCheckedContinuation { drainEndWaiters.append($0) }
        }
    }

    /// For tests: a retry timer is waiting.
    var retryWakeArmed: Bool { retryWake != nil }

    func endDrain() {
        isDraining = false
        let waiters = drainEndWaiters
        drainEndWaiters = []
        waiters.forEach { $0.resume() }
    }

    /// One send as a task of its own, so `stop` can cancel it.
    func send(_ item: Store.OutboxRow, with sender: any Store.OutboxSending) async throws -> Store.OutboxSendResult {
        let task = Task { try await sender.send(item) }
        inFlightSend = task
        defer { inFlightSend = nil }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}
