import Foundation

extension Backend {
    /// When a request is sent again. Reads retry; writes retry only with an
    /// idempotency key, so the server can tell a retry from a second write.
    enum RetryPolicy: Sendable, Equatable {
        case never
        /// GETs: up to `attempts` sends in all.
        case read(attempts: Int = 3)
        /// Writes carrying an `Idempotency-Key`: up to `attempts` sends, all with the same key.
        case keyedWrite(attempts: Int = 3)

        static func `default`(for method: Method, hasIdempotencyKey: Bool) -> RetryPolicy {
            switch method {
            case .get: .read()
            case .post, .put, .patch, .delete: hasIdempotencyKey ? .keyedWrite() : .never
            }
        }

        /// The policy the client actually uses. A write with no idempotency key
        /// is never sent twice, whatever its endpoint asks for: the server
        /// couldn't tell a retry from a second write.
        static func effective(_ requested: RetryPolicy, method: Method, hasIdempotencyKey: Bool) -> RetryPolicy {
            method != .get && !hasIdempotencyKey ? .never : requested
        }

        /// The most sends any policy allows: a client never hammers a door.
        static let mostAttempts = 5

        /// How many sends in all, 1...`mostAttempts`.
        var attempts: Int {
            switch self {
            case .never: 1
            case let .read(attempts), let .keyedWrite(attempts): min(Self.mostAttempts, max(1, attempts))
            }
        }

        /// The longest wait for a server's retry-after that's worth a retry;
        /// anything longer goes back to the screen.
        static let longestRetryAfter: Duration = .seconds(10)

        /// What to do after `failure` on send number `attempt` (from 1): wait this
        /// long and send again, or give up (nil). `jitter` picks a duration
        /// between zero and its argument.
        func retryDelay(after failure: Failure, attempt: Int, jitter: (Duration) -> Duration) -> Duration? {
            guard attempt < attempts else { return nil }
            switch failure.kind {
            // `.offline` here arrived mid-flight (the connection dropped after the
            // send began); the client checks reachability again before resending.
            case .timedOut, .transport, .offline, .upstreamTimeout, .upstreamUnavailable:
                return jitter(Self.backoffCeiling(attempt: attempt))
            case let .rateLimited(retryAfter), let .spendLimited(retryAfter):
                // Once only, and only for a short wait.
                guard attempt == 1, let retryAfter, retryAfter <= Self.longestRetryAfter else { return nil }
                return retryAfter
            default:
                return nil
            }
        }

        /// Full jitter's upper bound: `min(8 s, 0.5 s × 2^attempt)`.
        static func backoffCeiling(attempt: Int) -> Duration {
            let exponent = min(max(attempt, 0), 4)
            return min(.seconds(8), .milliseconds(500) * (1 << exponent))
        }
    }
}
