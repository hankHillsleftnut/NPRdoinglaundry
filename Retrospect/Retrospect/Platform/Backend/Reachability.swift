import Foundation
import Network

extension Backend {
    /// Whether the phone has a route to the internet right now, and when that changes.
    protocol Reachability: Sendable {
        var isOnline: Bool { get async }
        /// The current value first, then every change.
        func changes() -> AsyncStream<Bool>
    }

    /// Reachability from `NWPathMonitor`, on a queue of its own. Until the
    /// first path arrives it says online, so nothing waits on it.
    actor PathReachability: Reachability {
        private let monitor: NWPathMonitor?
        private var online = true
        private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

        /// Watches `monitor` on `queue`. With no monitor, only `receive(_:)` moves
        /// it (tests).
        init(monitor: NWPathMonitor? = NWPathMonitor(), queue: DispatchQueue = DispatchQueue(label: "com.shauryanarang.Retrospect.reachability")) {
            self.monitor = monitor
            monitor?.pathUpdateHandler = { [weak self] path in
                let status = path.status
                Task { await self?.receive(status) }
            }
            monitor?.start(queue: queue)
        }

        deinit {
            monitor?.cancel()
            continuations.values.forEach { $0.finish() }
        }

        var isOnline: Bool {
            online
        }

        nonisolated func changes() -> AsyncStream<Bool> {
            let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
            let id = UUID()
            Task { await self.add(continuation, id: id) }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
            return stream
        }

        /// A new path status from the monitor. Publishes only real changes.
        func receive(_ status: NWPath.Status) {
            let now = Self.isOnline(status)
            guard now != online else { return }
            online = now
            continuations.values.forEach { $0.yield(now) }
        }

        /// `.satisfied` is online, whatever it costs (expensive and constrained
        /// paths count); `.unsatisfied` and `.requiresConnection` are offline.
        static func isOnline(_ status: NWPath.Status) -> Bool {
            status == .satisfied
        }

        private func add(_ continuation: AsyncStream<Bool>.Continuation, id: UUID) {
            continuations[id] = continuation
            continuation.yield(online)
        }

        private func remove(_ id: UUID) {
            continuations[id] = nil
        }
    }
}
