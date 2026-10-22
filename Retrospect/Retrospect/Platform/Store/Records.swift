import Foundation
import GRDB

extension Store {
    enum EntryKind: String, Flows.ContractEnum {
        case typed, voice, conversation, imported, unknown
    }

    enum SyncState: String, Flows.ContractEnum {
        /// Saved here, not yet sent.
        case local
        case sending
        case sent
        /// Refused for good; `failureCode` says why.
        case failed
        /// Brought over from the old app (PL2.6); never sent.
        case legacy
        case unknown
    }

    enum Reading: String, Flows.ContractEnum {
        case waiting, reading, read, failed, unknown
    }

    enum Origin: String, Flows.ContractEnum {
        /// Written in the new app: the only rows that enter the outbox.
        case new
        /// Came from the server.
        case server
        /// Imported from the old app's files.
        case migrated
        case unknown
    }

    /// What an outbox row sends. Stored as its raw value.
    enum OutboxOperation: String, Flows.ContractEnum {
        case entryCreate = "entry.create"
        case unknown
    }

    /// A failure as the outbox stores it (`last_error_code`, `failure_code`)
    /// and the log carries it: a contract 00 code when the server answered,
    /// else the phone's own kind. A closed list, never a message.
    enum FailureCode: String, Flows.ContractEnum {
        case invalidRequest = "invalid_request"
        case invalidCredentials = "invalid_credentials"
        case unauthenticated
        case sessionRevoked = "session_revoked"
        case inviteRequired = "invite_required"
        case suspended
        case notFound = "not_found"
        case idempotencyMismatch = "idempotency_mismatch"
        case updateRequired = "update_required"
        case rateLimited = "rate_limited"
        case spendLimited = "spend_limited"
        case upstreamTimeout = "upstream_timeout"
        case upstreamUnavailable = "upstream_unavailable"
        case `internal`
        case inviteInvalid = "invite_invalid"
        case inviteUsed = "invite_used"
        case inviteExpired = "invite_expired"
        /// Phone-side: no connection.
        case offline
        case timedOut = "timed_out"
        case decoding
        case transport
        case unknown
    }

    enum OutboxStatus: String, Flows.ContractEnum {
        case pending, inFlight, done, dead, unknown
    }

    /// A media path that isn't relative to the app's container. Stores keep
    /// relative paths, because the container's absolute path changes.
    struct AbsoluteMediaPath: Error, Equatable {}

    /// One entry. `localID` is the entry's own id: for new entries also its
    /// `clientEntryId` and its outbox key.
    struct EntryRow: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
        static let databaseTableName = "entries"

        var localID: String
        var serverID: String?
        var kind: EntryKind
        var text: String
        var createdAt: Date
        /// `YYYY-MM-DD` in the person's time zone.
        var day: String
        /// Relative to the app's container, never absolute.
        var mediaPath: String?
        var syncState: SyncState
        /// A failure kind, never a message.
        var failureCode: String?
        var attempts: Int = 0
        var reading: Reading?
        var origin: Origin

        enum CodingKeys: String, CodingKey {
            case localID = "local_id", serverID = "server_id", kind, text, createdAt = "created_at", day
            case mediaPath = "media_path", syncState = "sync_state", failureCode = "failure_code", attempts, reading, origin
        }

        /// One day's entries, oldest first (the `entries(day, created_at)` index).
        static func onDay(_ day: String) -> QueryInterfaceRequest<EntryRow> {
            filter(Column(CodingKeys.day) == day).order(Column(CodingKeys.createdAt))
        }

        func willSave(_: GRDB.Database) throws {
            if let mediaPath, mediaPath.hasPrefix("/") || mediaPath.hasPrefix("file:") {
                throw AbsoluteMediaPath()
            }
        }

        static func databaseDateEncodingStrategy(for _: String) -> DatabaseDateEncodingStrategy {
            Store.Timestamp.encoding
        }

        static func databaseDateDecodingStrategy(for _: String) -> DatabaseDateDecodingStrategy {
            Store.Timestamp.decoding
        }
    }

    /// One thing to send. `id` is the request's `Idempotency-Key`.
    struct OutboxRow: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
        static let databaseTableName = "outbox"

        var id: String
        /// What to send: `entry.create`; later `entry.edit`, `guess.answer`…
        var operation: OutboxOperation
        var entityID: String
        /// The encoded request body, exactly as it will be sent every time.
        var payload: Data
        var attempts: Int = 0
        /// Pending: the earliest time to send. In flight: the time the send
        /// counts as lost to a crash (sent at + `Outbox.crashedSendAfter`), so
        /// the drainer finds stale sends through the same index.
        var nextAttemptAt: Date
        var status: OutboxStatus
        /// A failure kind, never a message.
        var lastErrorCode: String?
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, operation, entityID = "entity_id", payload, attempts, nextAttemptAt = "next_attempt_at", status
            case lastErrorCode = "last_error_code", createdAt = "created_at"
        }

        static func databaseDateEncodingStrategy(for _: String) -> DatabaseDateEncodingStrategy {
            Store.Timestamp.encoding
        }

        static func databaseDateDecodingStrategy(for _: String) -> DatabaseDateDecodingStrategy {
            Store.Timestamp.decoding
        }
    }

    /// A contract response kept as received (`brief.latest`, `guesses`,
    /// `entries.today.<day>`…), shown first next time.
    struct CachedDocument: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
        static let databaseTableName = "cached_documents"

        var key: String
        var body: Data
        var fetchedAt: Date
        var etag: String?

        enum CodingKeys: String, CodingKey {
            case key, body, fetchedAt = "fetched_at", etag
        }

        static func databaseDateEncodingStrategy(for _: String) -> DatabaseDateEncodingStrategy {
            Store.Timestamp.encoding
        }

        static func databaseDateDecodingStrategy(for _: String) -> DatabaseDateDecodingStrategy {
            Store.Timestamp.decoding
        }
    }

    /// Dates are written as ISO 8601 UTC with milliseconds
    /// (`2026-10-21T08:00:04.200Z`): they sort as text and read like the
    /// contracts. They're read with or without the fraction, so one odd row
    /// never fails a whole fetch.
    enum Timestamp {
        static let encoding = DatabaseDateEncodingStrategy.custom { Backend.Coding.timestamp($0) }
        static let decoding = DatabaseDateDecodingStrategy.custom { value in
            String.fromDatabaseValue(value).flatMap(date)
        }

        static func date(_ text: String) -> Date? {
            if let date = try? Date(text, strategy: withFraction) {
                return date
            }
            return try? Date(text, strategy: wholeSeconds)
        }

        private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt)
        private static let wholeSeconds = Date.ISO8601FormatStyle(timeZone: .gmt)
    }
}

extension Backend.Failure.Kind {
    /// The code the outbox stores for this failure.
    var storedCode: Store.FailureCode {
        switch self {
        case .invalidRequest: .invalidRequest
        case .invalidCredentials: .invalidCredentials
        case .unauthenticated: .unauthenticated
        case .sessionRevoked: .sessionRevoked
        case .inviteRequired: .inviteRequired
        case .suspended: .suspended
        case .notFound: .notFound
        case .idempotencyMismatch: .idempotencyMismatch
        case .updateRequired: .updateRequired
        case .rateLimited: .rateLimited
        case .spendLimited: .spendLimited
        case .upstreamTimeout: .upstreamTimeout
        case .upstreamUnavailable: .upstreamUnavailable
        case .internal: .internal
        case .inviteInvalid: .inviteInvalid
        case .inviteUsed: .inviteUsed
        case .inviteExpired: .inviteExpired
        case .offline: .offline
        case .timedOut: .timedOut
        case .decoding: .decoding
        case .transport: .transport
        case .unknown: .unknown
        }
    }
}
