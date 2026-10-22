import Foundation

extension Backend {
    /// Why a request failed, in full: one kind per contract 00 code, the invite
    /// codes, and what can go wrong on the phone's side. Platform code (the
    /// session, the outbox, invites) needs these distinctions; screens get the
    /// coarser `Flows.Failure` through `flowFailure`.
    ///
    /// Two failures are equal when their kinds are; `message` is for display.
    struct Failure: Error, Sendable, Equatable {
        enum Kind: Sendable, Equatable {
            case invalidRequest
            case invalidCredentials
            case unauthenticated
            case sessionRevoked
            case inviteRequired
            case suspended
            case notFound
            case idempotencyMismatch
            case updateRequired
            case rateLimited(retryAfter: Duration?)
            case spendLimited(retryAfter: Duration?)
            case upstreamTimeout
            case upstreamUnavailable
            case `internal`
            case inviteInvalid
            case inviteUsed
            case inviteExpired
            /// No connection.
            case offline
            /// The request took longer than the endpoint allows.
            case timedOut
            /// The server answered with a body the app couldn't read.
            case decoding
            /// Any other failure between the phone and the server.
            case transport
            /// A code outside the contract's list. Logged as a kind, never with its text.
            case unknown(code: String)
        }

        let kind: Kind
        /// The server's plain-words message (contract 00 §2), safe to show as is;
        /// nil when the failure didn't come from the server.
        let message: String?

        init(_ kind: Kind, message: String? = nil) {
            self.kind = kind
            self.message = message
        }

        /// The failure a server error body describes.
        init(_ body: ErrorBody) {
            self.init(Self.kind(code: body.code, retryAfterSeconds: body.retryAfterSeconds), message: body.message)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.kind == rhs.kind
        }

        /// Whether sending the same request again can work.
        var isRetryable: Bool {
            switch kind {
            case .rateLimited, .upstreamTimeout, .upstreamUnavailable, .internal, .offline, .timedOut, .transport:
                true
            case .invalidRequest, .invalidCredentials, .unauthenticated, .sessionRevoked, .inviteRequired, .suspended, .notFound,
                 .idempotencyMismatch, .updateRequired, .spendLimited, .inviteInvalid, .inviteUsed, .inviteExpired, .decoding, .unknown:
                false
            }
        }

        /// What a screen is told. `unauthenticated` reaches a screen only when the
        /// refresh (PL1.5) has already failed, so it reads as signed out.
        var flowFailure: Flows.Failure {
            switch kind {
            case .offline, .timedOut, .transport: .network
            case .upstreamTimeout, .upstreamUnavailable, .internal, .decoding: Flows.Failure(.server, message: message)
            case .notFound: Flows.Failure(.notFound, message: message)
            case let .rateLimited(retryAfter): Flows.Failure(.rateLimited(retryAfterSeconds: retryAfter?.wholeSeconds), message: message)
            case let .spendLimited(retryAfter): Flows.Failure(.spendLimited(retryAfterSeconds: retryAfter?.wholeSeconds), message: message)
            case .updateRequired: Flows.Failure(.updateRequired, message: message)
            case .unauthenticated, .sessionRevoked: Flows.Failure(.signedOut, message: message)
            case .inviteRequired: Flows.Failure(.inviteRequired, message: message)
            case .suspended: Flows.Failure(.suspended, message: message)
            case .invalidRequest, .idempotencyMismatch: Flows.Failure(.invalid, message: message)
            case .invalidCredentials: Flows.Failure(.invalidCredentials, message: message)
            case .inviteInvalid: Flows.Failure(.inviteInvalid, message: message)
            case .inviteUsed: Flows.Failure(.inviteUsed, message: message)
            case .inviteExpired: Flows.Failure(.inviteExpired, message: message)
            case .unknown: Flows.Failure(.unknown, message: message)
            }
        }

        private static func kind(code: String, retryAfterSeconds: Int?) -> Kind {
            let retryAfter = retryAfterSeconds.map { Duration.seconds($0) }
            switch code {
            case "rate_limited": return .rateLimited(retryAfter: retryAfter)
            case "spend_limited": return .spendLimited(retryAfter: retryAfter)
            default: return codes[code] ?? .unknown(code: code)
            }
        }

        /// Contract 00 §2's codes and §4's invite codes, except the two that carry a retry-after.
        private static let codes: [String: Kind] = [
            "invalid_request": .invalidRequest,
            "invalid_credentials": .invalidCredentials,
            "unauthenticated": .unauthenticated,
            "session_revoked": .sessionRevoked,
            "invite_required": .inviteRequired,
            "suspended": .suspended,
            "not_found": .notFound,
            "idempotency_mismatch": .idempotencyMismatch,
            "update_required": .updateRequired,
            "upstream_timeout": .upstreamTimeout,
            "upstream_unavailable": .upstreamUnavailable,
            "internal": .internal,
            "invite_invalid": .inviteInvalid,
            "invite_used": .inviteUsed,
            "invite_expired": .inviteExpired,
        ]
    }
}

private extension Duration {
    var wholeSeconds: Int {
        Int(components.seconds)
    }
}
