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
        /// The launch install check ran (PL1.3): what it found.
        case installChecked(Session.InstallCheck)
        /// The launch install check failed with this Keychain status; the next
        /// launch tries again.
        case installCheckFailed(status: OSStatus)
        /// A launch argument was ignored (debug builds only).
        case launchOptionIgnored(Platform.LaunchOptions.Problem)
        /// A batch of diagnostics couldn't be written; it was dropped.
        case diagnosticsWriteFailed
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
                recordRequest(path, status: status, ms: ms)
            case let .unknownErrorCode(path):
                recordUnknownErrorCode(path)
            case let .launchOptionIgnored(problem):
                record(problem)
            case let .installChecked(check):
                record(check)
            case let .installCheckFailed(status):
                logger.error("install check failed: keychain status \(status)")
            case .diagnosticsWriteFailed:
                logger.error("diagnostics: a batch couldn't be written, dropped")
            }
        }

        /// One fixed line per door: the template is never interpolated.
        private func recordRequest(_ path: Backend.PathTemplate, status: Int, ms: Int) {
            switch path {
            case .meta: logger.info("request /v2/meta: status \(status), \(ms) ms")
            }
        }

        private func recordUnknownErrorCode(_ path: Backend.PathTemplate) {
            switch path {
            case .meta: logger.error("unknown error code from /v2/meta")
            }
        }

        private func record(_ check: Session.InstallCheck) {
            switch check {
            case .alreadyDone: logger.debug("install check: already done")
            case .wipedLeftovers: logger.info("install check: fresh install, leftovers wiped")
            case .keptUpdate: logger.info("install check: update from the old app, nothing wiped")
            case .deferredUntilUnlock: logger.info("install check: deferred until the phone is unlocked")
            }
        }

        private func record(_ problem: Platform.LaunchOptions.Problem) {
            switch problem {
            case .unknownValue(.data): logger.error("launch option -Data: unknown value, using live")
            case .unknownValue(.environment): logger.error("launch option -Environment: unknown value, using production")
            case .unknownValue(.account): logger.error("launch option -Account: unknown value, ignored")
            case .missingValue(.data): logger.error("launch option -Data: no value, using live")
            case .missingValue(.environment): logger.error("launch option -Environment: no value, using production")
            case .missingValue(.account): logger.error("launch option -Account: no value, ignored")
            case .accountNeedsStaging: logger.error("launch option -Account needs -Environment local or staging, ignored")
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
