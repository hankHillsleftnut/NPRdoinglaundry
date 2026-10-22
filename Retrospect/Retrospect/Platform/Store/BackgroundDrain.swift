import BackgroundTasks
import Foundation

extension Store {
    /// The outbox's background task: `com.shauryanarang.Retrospect.outbox.drain`,
    /// a `BGAppRefreshTask` scheduled when the app goes to the background with
    /// unsent items, so they go while the app sleeps. Registered once, before
    /// `didFinishLaunching` returns (the app delegate); the test host never
    /// builds the delegate, so tests never register.
    final class BackgroundDrain: @unchecked Sendable {
        static let identifier = "com.shauryanarang.Retrospect.outbox.drain"
        /// Not before this long after backgrounding; the system picks the time.
        static let earliestAfter: TimeInterval = 15 * 60

        /// Where the outbox is once the store has opened; nil before sign-in.
        var outbox: @Sendable () async -> Outbox? {
            get { lock.withLock { provider } }
            set { lock.withLock { provider = newValue } }
        }

        private let lock = NSLock()
        private var provider: @Sendable () async -> Outbox? = { nil }
        private let scheduler: Scheduler

        /// The system calls, so tests can pass their own.
        struct Scheduler {
            var register: (_ identifier: String, _ handler: @escaping (BGTask) -> Void) -> Bool
            var submit: (_ identifier: String, _ earliest: Date) throws -> Void

            static let system = Scheduler(
                register: { identifier, handler in
                    BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil, launchHandler: handler)
                },
                submit: { identifier, earliest in
                    let request = BGAppRefreshTaskRequest(identifier: identifier)
                    request.earliestBeginDate = earliest
                    try BGTaskScheduler.shared.submit(request)
                }
            )
        }

        init(scheduler: Scheduler = .system) {
            self.scheduler = scheduler
        }

        /// Registers the handler. Once, at launch.
        @discardableResult
        func register() -> Bool {
            scheduler.register(Self.identifier) { [weak self] task in
                self?.handle(task)
            }
        }

        /// Asks for a background launch when there's something to send.
        /// Returns whether a request was submitted.
        @discardableResult
        func scheduleIfNeeded(unsent: Int, now: Date = Date()) -> Bool {
            guard unsent > 0 else { return false }
            do {
                try scheduler.submit(Self.identifier, now.addingTimeInterval(Self.earliestAfter))
                return true
            } catch {
                return false
            }
        }

        /// One drain, cancelled cleanly if the system's time runs out.
        func handle(_ task: BGTask) {
            let drain = Task { [outbox] in
                guard let outbox = await outbox() else { return }
                await outbox.drain(reason: .backgroundTask)
            }
            task.expirationHandler = { drain.cancel() }
            Task {
                await drain.value
                task.setTaskCompleted(success: !drain.isCancelled)
            }
        }
    }
}
