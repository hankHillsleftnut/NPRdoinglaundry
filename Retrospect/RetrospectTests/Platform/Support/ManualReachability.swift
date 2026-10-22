import Foundation
@testable import Retrospect

/// Reachability a test sets by hand.
final class ManualReachability: Backend.Reachability, @unchecked Sendable {
    private let lock = NSLock()
    private var online: Bool

    init(online: Bool = true) {
        self.online = online
    }

    var isOnline: Bool {
        get async { lock.withLock { online } }
    }

    func set(online value: Bool) {
        lock.withLock { online = value }
    }

    func changes() -> AsyncStream<Bool> {
        let current = lock.withLock { online }
        return AsyncStream { $0.yield(current) }
    }
}
