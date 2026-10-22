import Foundation
import os

extension Platform {
    /// The one way new code logs. An event is a closed list of cases carrying
    /// only enums and counts, so a log line can never hold someone's words, a
    /// token or a URL. Each byte that needs a new line adds a case here.
    enum Log {}

    /// Where log events go. Production uses `Log.SystemSink`; tests and previews
    /// use `Log.Recorder`.
    protocol LogSink: Sendable {
        func record(_ event: Log.Event)
    }
}

extension Platform.Log {
    enum Event: Equatable, Sendable {
        /// The session was refreshed.
        case refreshed
        /// One outbox drain finished.
        case outboxDrained(sent: Int, failed: Int)
        /// One request finished: its door, the HTTP status (0 when nothing came
        /// back) and how long it took.
        case requestSent(path: Backend.PathTemplate, status: Int, ms: Int)
        /// A door answered with an error code outside the contract's list. The
        /// code itself is never logged.
        case unknownErrorCode(path: Backend.PathTemplate)
    }

    /// Writes to the unified log, subsystem `com.shauryanarang.Retrospect`,
    /// category `platform`. Every line is a fixed string; only integers are
    /// interpolated, and the system keeps those public by default, so nothing
    /// is marked `.public`.
    struct SystemSink: Platform.LogSink {
        private let logger = Logger(subsystem: "com.shauryanarang.Retrospect", category: "platform")

        func record(_ event: Event) {
            switch event {
            case .refreshed:
                logger.info("session refreshed")
            case let .outboxDrained(sent, failed):
                logger.info("outbox drained: sent \(sent), failed \(failed)")
            case let .requestSent(path, status, ms):
                switch path {
                case .meta: logger.info("request /v2/meta: status \(status), \(ms) ms")
                }
            case let .unknownErrorCode(path):
                switch path {
                case .meta: logger.error("unknown error code from /v2/meta")
                }
            }
        }
    }

    /// Keeps events in memory, in order. For tests and previews.
    final class Recorder: Platform.LogSink, @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Event] = []

        init() {}

        var events: [Event] {
            lock.withLock { recorded }
        }

        func record(_ event: Event) {
            lock.withLock { recorded.append(event) }
        }
    }
}
