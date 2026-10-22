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
        /// The outbox (PL2.2): what was queued, sent, retried, refused or paused. No text, no ids.
        case outbox(Outbox)
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
    }

    enum Outbox: Equatable, Sendable {
        case enqueued(operation: Store.OutboxOperation)
        /// One drain finished: how many items landed, how many were refused for good.
        case drained(sent: Int, failed: Int)
        case sent(operation: Store.OutboxOperation, attempts: Int, ms: Int)
        /// A retryable failure: the item waits for its next attempt.
        case retry(operation: Store.OutboxOperation, code: Store.FailureCode)
        /// Refused for good (or out of attempts): the item is dead, its entity failed.
        case dead(operation: Store.OutboxOperation, code: Store.FailureCode)
        /// The pass stopped early: offline, or the session needs attention.
        case paused(code: Store.FailureCode)
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
            case let .outbox(event):
                record(event)
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
            }
        }

        /// One fixed line per door: the template is never interpolated.
        private func recordRequest(_ path: Backend.PathTemplate, status: Int, ms: Int) {
            switch path {
            case .meta: logger.info("request /v2/meta: status \(status), \(ms) ms")
            case .entries: logger.info("request /v2/entries: status \(status), \(ms) ms")
            }
        }

        private func recordUnknownErrorCode(_ path: Backend.PathTemplate) {
            switch path {
            case .meta: logger.error("unknown error code from /v2/meta")
            case .entries: logger.error("unknown error code from /v2/entries")
            }
        }

        private func record(_ event: Outbox) {
            switch event {
            case let .enqueued(operation):
                logger.info("outbox: \(Self.name(operation)) queued")
            case let .drained(sent, failed):
                logger.info("outbox drained: sent \(sent), failed \(failed)")
            case let .sent(operation, attempts, ms):
                logger.info("outbox: \(Self.name(operation)) sent on attempt \(attempts), \(ms) ms")
            case let .retry(operation, code):
                logger.info("outbox: \(Self.name(operation)) will retry after \(Self.name(code))")
            case let .dead(operation, code):
                logger.error("outbox: \(Self.name(operation)) refused: \(Self.name(code))")
            case let .paused(code):
                logger.info("outbox: pass paused: \(Self.name(code))")
            }
        }

        /// The fixed name of an operation: a closed list, never a value from the server.
        private static func name(_ operation: Store.OutboxOperation) -> StaticString {
            switch operation {
            case .entryCreate: "entry.create"
            case .unknown: "unknown operation"
            }
        }

        /// The fixed name of a failure code: a closed list, never the server's message.
        private static func name(_ code: Store.FailureCode) -> String {
            code.rawValue
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
            case .tooLong(.screen): logger.error("launch option -Screen: longer than 64 characters, ignored")
            case .tooLong(.state): logger.error("launch option -State: longer than 64 characters, ignored")
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
