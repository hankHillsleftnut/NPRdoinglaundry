//
//  FlowTypes.swift
//  The shapes every flow protocol shares (ui-engineer.md §4, the seam). Views read these;
//  sample data (Features/…/Sample) and live data (Platform) both produce them, so swapping
//  one for the other never changes what a screen can show.
//
import Foundation

/// The flows' namespace: every model and protocol a screen reads lives under it, so no new
/// name can collide with the old app's types. (PL0.2 places it beside the other namespaces.)
enum Flows {}

extension Flows {
    /// Why a read or a write didn't work, in the terms a screen needs to pick its state
    /// (C39: error with try again, offline line, gone, the invite gate…). Platform maps
    /// contract 00's error codes and transport failures onto these; views never see a status.
    ///
    /// Two failures are equal when their kinds are: `message` is for display, not identity,
    /// so `.failed(.network)` matches whatever the server said.
    struct Failure: Error, Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            /// No connection, or the request couldn't reach the server.
            case network
            /// The server or the brain failed (contract 00: internal, upstream_*).
            case server
            /// The thing doesn't exist, or isn't yours (contract 00: not_found).
            case notFound
            /// Too many tries (contract 00: rate_limited).
            case rateLimited(retryAfterSeconds: Int?)
            /// The day's model spend is used up (contract 00: spend_limited).
            case spendLimited(retryAfterSeconds: Int?)
            /// This version of the app is too old (contract 00: update_required).
            case updateRequired
            /// Signed out, or the session ended (contract 00: session_revoked).
            case signedOut
            /// Waitlisted: only the invite gate is open (contract 00: invite_required).
            case inviteRequired
            /// Paused by the founder (contract 00: suspended).
            case suspended
            /// The app sent something the server refused as malformed: a bug state
            /// (contract 00: invalid_request, idempotency_mismatch). Logged as a count.
            case invalid
            /// Anything the app doesn't recognise yet.
            case unknown
        }

        let kind: Kind
        /// The server's plain-words message (contract 00 §2), safe to show as is; nil when
        /// the failure didn't come from the server.
        let message: String?

        init(_ kind: Kind, message: String? = nil) {
            self.kind = kind
            self.message = message
        }

        /// Whether "try again" can help now (the screen offers it only then).
        var isRetryable: Bool {
            switch kind {
            case .network, .server, .rateLimited, .unknown:
                true
            case .notFound, .spendLimited, .updateRequired, .signedOut, .inviteRequired, .suspended, .invalid:
                false
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.kind == rhs.kind
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(kind)
        }

        static let network = Self(.network)
        static let server = Self(.server)
        static let notFound = Self(.notFound)
        static let updateRequired = Self(.updateRequired)
        static let signedOut = Self(.signedOut)
        static let inviteRequired = Self(.inviteRequired)
        static let suspended = Self(.suspended)
        static let invalid = Self(.invalid)
        static let unknown = Self(.unknown)

        static func rateLimited(retryAfterSeconds: Int?) -> Self {
            Self(.rateLimited(retryAfterSeconds: retryAfterSeconds))
        }

        static func spendLimited(retryAfterSeconds: Int?) -> Self {
            Self(.spendLimited(retryAfterSeconds: retryAfterSeconds))
        }
    }

    /// A value a screen waits for. `loading` never carries stale content: a screen showing
    /// cached content while offline is `loaded`, with the flow's `isOnline` false.
    enum Loadable<Value: Sendable>: Sendable {
        case loading
        case loaded(Value)
        case failed(Failure)

        var value: Value? {
            if case let .loaded(value) = self {
                return value
            }
            return nil
        }
    }

    /// One page of a cursor-paged list (contracts: `{ items, nextCursor }`).
    struct Page<Item: Sendable>: Sendable {
        let items: [Item]
        /// Pass back to get the next page; nil on the last page.
        let nextCursor: String?
    }

    /// Contracts rule 5: enums are closed lists, and a value the app doesn't know decodes to
    /// `unknown` instead of failing the whole response.
    protocol ContractEnum: RawRepresentable, Codable, Sendable, Hashable where RawValue == String {
        static var unknown: Self { get }
    }
}

extension Flows.Loadable: Equatable where Value: Equatable {}
extension Flows.Loadable: Hashable where Value: Hashable {}
extension Flows.Page: Equatable where Item: Equatable {}
extension Flows.Page: Hashable where Item: Hashable {}

extension Flows.ContractEnum {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

extension JSONDecoder {
    /// Contracts rule 2: ISO 8601 UTC with milliseconds (`2026-10-21T08:00:04.200Z`); a value
    /// without milliseconds is accepted too. Calendar days stay strings (`YYYY-MM-DD`).
    /// PL1.1a's client uses this same decoder.
    static var contract: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(text, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not an ISO 8601 date")
        }
        return decoder
    }
}
