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
    ///
    /// The monitor's updates go into one stream, in the order the monitor
    /// gave them, and one task reads that stream, so a later path can never
    /// be overtaken by an earlier one.
    actor PathReachability: Reachability {
        private let monitor: NWPathMonitor?
        private var online = true
        private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
        private let paths: AsyncStream<NWPath.Status>.Continuation
        private var reader: Task<Void, Never>?

        /// Watches `monitor` on `queue`. With no monitor, only `receive(_:)` moves
        /// it (tests).
        init(monitor: NWPathMonitor? = NWPathMonitor(), queue: DispatchQueue = DispatchQueue(label: "com.shauryanarang.Retrospect.reachability")) {
            let (stream, paths) = AsyncStream.makeStream(of: NWPath.Status.self, bufferingPolicy: .unbounded)
            self.monitor = monitor
            self.paths = paths
            monitor?.pathUpdateHandler = { path in
                paths.yield(path.status)
            }
            monitor?.start(queue: queue)
            Task { await self.read(stream) }
        }

        deinit {
            monitor?.cancel()
            paths.finish()
            reader?.cancel()
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

        /// Queues a path status exactly as the monitor does: in order, read by
        /// the one reader. (Tests feed it directly.)
        nonisolated func enqueue(_ status: NWPath.Status) {
            paths.yield(status)
        }

        /// A new path status. Publishes only real changes.
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

        /// The one reader of the monitor's updates. Holds the actor only weakly
        /// between updates, so the actor can go away and end it.
        private func read(_ stream: AsyncStream<NWPath.Status>) {
            reader = Task { [weak self] in
                for await status in stream {
                    guard let self else { return }
                    await receive(status)
                }
            }
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
