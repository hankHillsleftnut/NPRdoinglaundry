import Foundation
@testable import Retrospect

/// Stands in for the client: answers each send from a script, remembers
/// every send it saw, and can hold a send open until a test lets it go.
final class ScriptedSender: Store.OutboxSending, @unchecked Sendable {
    struct Send: Equatable {
        let id: String
        let payload: Data
        let attempts: Int
    }

    private let lock = NSLock()
    private var scripts: [String: [Result<Store.OutboxSendResult, Backend.Failure>]] = [:]
    private var sendsSeen: [Send] = []
    private var inFlight = 0
    private var mostInFlight = 0
    /// Called with the row while it's being sent, before the answer.
    var inspect: (@Sendable (Store.OutboxRow) -> Void)?
    /// Every send waits here until the gate opens.
    var gate: Gate?

    var sends: [Send] {
        lock.withLock { sendsSeen }
    }

    /// The most sends that were ever open at once.
    var peakConcurrency: Int {
        lock.withLock { mostInFlight }
    }

    /// Answers for `id`, in order; after the script runs out, success.
    func script(_ id: String, _ outcomes: [Result<Store.OutboxSendResult, Backend.Failure>]) {
        lock.withLock { scripts[id] = outcomes }
    }

    func send(_ item: Store.OutboxRow) async throws -> Store.OutboxSendResult {
        lock.withLock {
            sendsSeen.append(Send(id: item.id, payload: item.payload, attempts: item.attempts))
            inFlight += 1
            mostInFlight = max(mostInFlight, inFlight)
        }
        defer { lock.withLock { inFlight -= 1 } }
        inspect?(item)
        if let gate {
            try await gate.wait()
        }
        let next: Result<Store.OutboxSendResult, Backend.Failure>? = lock.withLock {
            guard var queue = scripts[item.id], !queue.isEmpty else { return nil }
            let first = queue.removeFirst()
            scripts[item.id] = queue
            return first
        }
        return try (next ?? .success(Store.OutboxSendResult(serverID: "server-\(item.id)", reading: .waiting))).get()
    }
}

/// A door tests open by hand. Waiting on a closed gate suspends; cancelling
/// the waiting task throws `CancellationError`.
final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var waiters: [CheckedContinuation<Void, any Error>] = []

    init() {}

    var waiting: Int {
        lock.withLock { waiters.count }
    }

    func open() {
        let resumed: [CheckedContinuation<Void, any Error>] = lock.withLock {
            opened = true
            defer { waiters = [] }
            return waiters
        }
        resumed.forEach { $0.resume() }
    }

    func wait() async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let openNow: Bool = lock.withLock {
                    if opened {
                        return true
                    }
                    waiters.append(continuation)
                    return false
                }
                if openNow {
                    continuation.resume()
                }
            }
        } onCancel: {
            let cancelled: [CheckedContinuation<Void, any Error>] = lock.withLock {
                defer { waiters = [] }
                return waiters
            }
            cancelled.forEach { $0.resume(throwing: CancellationError()) }
        }
    }
}
