import Foundation
import GRDB

extension Store {
    /// A new entry as the person sent it, before it's saved. Nil when the
    /// text is empty once trimmed: an empty entry is never saved or sent.
    struct EntryDraft: Sendable, Equatable {
        let id: UUID
        let kind: Backend.Endpoints.CreateEntry.Kind
        let text: String
        let createdAt: Date
        /// Relative to the app's container (a voice note's audio), never absolute.
        let mediaPath: String?

        init?(id: UUID = UUID(), kind: Backend.Endpoints.CreateEntry.Kind, text: String, createdAt: Date, mediaPath: String? = nil) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            self.id = id
            self.kind = kind
            self.text = trimmed
            self.createdAt = createdAt
            self.mediaPath = mediaPath
        }
    }

    /// `retry(entityID:)` found no refused item for that entity.
    struct NothingToRetry: Error, Equatable {}

    /// Write locally, send exactly once. An entry and the outbox row that
    /// sends it are saved in one transaction, so neither exists without the
    /// other. The row's id is the entry's `local_id`, its `clientEntryId` and
    /// its `Idempotency-Key`: every attempt carries the same key, so the server
    /// keeps one entry however often it's sent.
    ///
    /// PL2.2a is the queue; the drainer and its triggers are PL2.2b.
    actor Outbox {
        enum DrainReason: String, Sendable {
            case launch, foreground, reachability, afterWrite, backgroundTask, manual
        }

        /// An item still in flight this long after it was sent was lost to a
        /// crash; the drainer (PL2.2b) sends it again with the same key.
        static let crashedSendAfter: TimeInterval = 120

        let database: LocalDatabase
        private let now: @Sendable () -> Date
        private let timeZone: @Sendable () -> TimeZone
        private let log: any Platform.LogSink

        init(
            database: LocalDatabase,
            now: @escaping @Sendable () -> Date = { Date() },
            timeZone: @escaping @Sendable () -> TimeZone = { .current },
            log: any Platform.LogSink
        ) {
            self.database = database
            self.now = now
            self.timeZone = timeZone
            self.log = log
        }

        /// Saves the entry (`local`, from the new app) and its `entry.create`
        /// row (`pending`, due now) in one transaction, and returns the entry's
        /// id. If either write fails, neither exists.
        @discardableResult
        func enqueueEntry(_ draft: EntryDraft) throws -> UUID {
            let payload = try Backend.Coding.encoder.encode(
                Backend.Endpoints.CreateEntry.Body(text: draft.text, kind: draft.kind, clientEntryID: draft.id, createdAt: draft.createdAt)
            )
            let id = draft.id.uuidString.lowercased()
            let queuedAt = now()
            let entry = EntryRow(
                localID: id, serverID: nil, kind: EntryKind(rawValue: draft.kind.rawValue) ?? .unknown, text: draft.text,
                createdAt: draft.createdAt, day: Self.day(of: draft.createdAt, in: timeZone()), mediaPath: draft.mediaPath,
                syncState: .local, failureCode: nil, attempts: 0, reading: nil, origin: .new
            )
            let item = OutboxRow(
                id: id, operation: .entryCreate, entityID: id, payload: payload, attempts: 0,
                nextAttemptAt: queuedAt, status: .pending, lastErrorCode: nil, createdAt: queuedAt
            )
            try database.writer.write { db in
                try entry.insert(db)
                try item.insert(db)
            }
            log.record(.outboxEnqueued(operation: .entryCreate))
            return draft.id
        }

        /// Items not yet sent: pending, in flight or refused. Feeds sign-out's
        /// "you have unsent entries" (PL1.5).
        func unsentCount() throws -> Int {
            try database.writer.read { db in
                try OutboxRow
                    .filter([OutboxStatus.pending, .inFlight, .dead].map(\.rawValue).contains(Column(OutboxRow.CodingKeys.status)))
                    .fetchCount(db)
            }
        }

        /// Puts a refused item back in the queue, due now with its attempts
        /// reset, and its entry back to `local`. Throws `NothingToRetry`
        /// (changing nothing) when the entity has no refused item.
        func retry(entityID: UUID) throws {
            let id = entityID.uuidString.lowercased()
            let due = now()
            try database.writer.write { db in
                let dead = try OutboxRow
                    .filter(Column(OutboxRow.CodingKeys.entityID) == id && Column(OutboxRow.CodingKeys.status) == OutboxStatus.dead.rawValue)
                    .fetchAll(db)
                guard !dead.isEmpty else { throw NothingToRetry() }
                // Only the four fields that change: a row whose operation this
                // build reads as `unknown` keeps its stored operation.
                for var item in dead {
                    item.status = .pending
                    item.attempts = 0
                    item.nextAttemptAt = due
                    item.lastErrorCode = nil
                    try item.update(db, columns: [
                        Column(OutboxRow.CodingKeys.status), Column(OutboxRow.CodingKeys.attempts),
                        Column(OutboxRow.CodingKeys.nextAttemptAt), Column(OutboxRow.CodingKeys.lastErrorCode),
                    ])
                }
                if var entry = try EntryRow.fetchOne(db, key: id), entry.syncState == .failed {
                    entry.syncState = .local
                    entry.failureCode = nil
                    entry.attempts = 0
                    try entry.update(db)
                }
            }
        }

        /// The sync state of every entry written in the new app, by id: the
        /// current states first, then again after each change. Ends if the
        /// database fails.
        nonisolated func states() -> AsyncStream<[UUID: SyncState]> {
            let observation = ValueObservation.tracking(Self.syncStates).removeDuplicates()
            let writer = database.writer
            return AsyncStream { continuation in
                let cancellable = observation.start(
                    in: writer,
                    scheduling: .async(onQueue: DispatchQueue(label: "com.shauryanarang.Retrospect.outbox.states")),
                    onError: { _ in continuation.finish() },
                    onChange: { continuation.yield($0) }
                )
                continuation.onTermination = { _ in cancellable.cancel() }
            }
        }

        static func syncStates(_ db: GRDB.Database) throws -> [UUID: SyncState] {
            let rows = try EntryRow.filter(Column(EntryRow.CodingKeys.origin) == Origin.new.rawValue).fetchAll(db)
            return Dictionary(rows.compactMap { row in UUID(uuidString: row.localID).map { ($0, row.syncState) } }) { first, _ in first }
        }

        /// `YYYY-MM-DD` of `date` in `timeZone`: the person's day.
        static func day(of date: Date, in timeZone: TimeZone) -> String {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }
    }
}
