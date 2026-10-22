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

        /// Sends of one item that keep failing for a reason worth retrying
        /// (a timeout, a 5xx) stop here: the item is refused, the entry
        /// `failed`, and the person can retry it by hand (integrator, 22 Oct).
        static let attemptLimit = 5
        /// Full jitter between attempts: `min(5 min, 2 s × 2^(attempt−1))`.
        static let backoffBase: Duration = .seconds(2)
        static let backoffCap: Duration = .seconds(300)

        let database: LocalDatabase
        private let sender: (any OutboxSending)?
        private let reachability: (any Backend.Reachability)?
        private let now: @Sendable () -> Date
        private let timeZone: @Sendable () -> TimeZone
        private let jitter: @Sendable (Duration) -> Duration
        private let log: any Platform.LogSink
        private var isDraining = false
        private var needsAnotherPass = false
        private var started = false
        private var reachabilityWatch: Task<Void, Never>?

        /// Without a sender the outbox only queues (previews, the queue's own
        /// tests); `drain` does nothing.
        init(
            database: LocalDatabase,
            sender: (any OutboxSending)? = nil,
            reachability: (any Backend.Reachability)? = nil,
            now: @escaping @Sendable () -> Date = { Date() },
            timeZone: @escaping @Sendable () -> TimeZone = { .current },
            jitter: @escaping @Sendable (Duration) -> Duration = Backend.Client.randomJitter,
            log: any Platform.LogSink
        ) {
            self.database = database
            self.sender = sender
            self.reachability = reachability
            self.now = now
            self.timeZone = timeZone
            self.jitter = jitter
            self.log = log
        }

        deinit {
            reachabilityWatch?.cancel()
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
            log.record(.outbox(.enqueued(operation: .entryCreate)))
            if started {
                Task { await drain(reason: .afterWrite) }
            }
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

        // MARK: Draining (PL2.2b)

        /// Turns the triggers on: a drain now (the first reachability value),
        /// one whenever the phone comes back online, and one after every
        /// enqueue. Foreground and the background task call `drain` themselves.
        func start() {
            guard !started else { return }
            started = true
            guard let reachability else {
                Task { await drain(reason: .launch) }
                return
            }
            reachabilityWatch = Task { [weak self] in
                for await online in reachability.changes() where online {
                    guard let self else { return }
                    await drain(reason: .reachability)
                }
            }
        }

        /// Sends what's due. Safe to call any time: at most one drain runs, and
        /// a call during a drain adds one more pass at its end, never a second
        /// drainer. Returns when the drain is over (or was cancelled).
        func drain(reason _: DrainReason) async {
            guard sender != nil else { return }
            if isDraining {
                needsAnotherPass = true
                return
            }
            isDraining = true
            defer { isDraining = false }
            repeat {
                needsAnotherPass = false
                await pass()
            } while needsAnotherPass && !Task.isCancelled
        }

        private struct Tally {
            var sent = 0
            var failed = 0
        }

        /// One pass over what's due, oldest first.
        private func pass() async {
            guard let sender, (try? resetCrashedSends()) != nil, let due = try? dueItems() else { return }
            var tally = Tally()
            for item in due where !Task.isCancelled {
                guard (try? markInFlight(item)) != nil else { continue }
                let startedAt = now()
                do {
                    let result = try await sender.send(item)
                    try markDone(item, result: result)
                    tally.sent += 1
                    log.record(.outbox(.sent(operation: item.operation, attempts: item.attempts + 1, ms: Self.milliseconds(since: startedAt, now: now()))))
                } catch is CancellationError {
                    try? markPending(item, at: now())
                    break
                } catch {
                    if settle(error, item: item, tally: &tally) == .pause {
                        break
                    }
                }
            }
            log.record(.outbox(.drained(sent: tally.sent, failed: tally.failed)))
        }

        /// Writes a failed send back: the item waits, is refused, or the pass pauses.
        private func settle(_ error: any Error, item: OutboxRow, tally: inout Tally) -> Outcome {
            let failure = (error as? Backend.Failure) ?? Backend.Failure(.transport)
            let code = failure.kind.storedCode
            let outcome = Self.outcome(of: failure)
            switch outcome {
            case .pause:
                try? markPending(item, at: now())
                log.record(.outbox(.paused(code: code)))
            case .retry:
                let attempts = item.attempts + 1
                if attempts >= Self.attemptLimit {
                    try? markDead(item, attempts: attempts, code: code)
                    tally.failed += 1
                } else {
                    try? markRetry(item, attempts: attempts, at: now().addingTimeInterval(retryWait(failure, attempt: attempts)), code: code)
                }
            case .dead:
                try? markDead(item, attempts: item.attempts + 1, code: code)
                tally.failed += 1
            }
            return outcome
        }

        enum Outcome: Equatable {
            /// Stop the pass; the item goes back to pending, no attempt counted.
            case pause
            /// Count an attempt and wait; dead once the attempts run out.
            case retry
            /// Refused for good.
            case dead
        }

        /// What a failure means for the item and the pass.
        static func outcome(of failure: Backend.Failure) -> Outcome {
            switch failure.kind {
            case .offline, .unauthenticated, .sessionRevoked: .pause
            case .rateLimited, .upstreamTimeout, .upstreamUnavailable, .internal, .timedOut, .transport: .retry
            case .invalidRequest, .invalidCredentials, .inviteRequired, .suspended, .notFound, .idempotencyMismatch, .updateRequired,
                 .spendLimited, .inviteInvalid, .inviteUsed, .inviteExpired, .decoding, .unknown: .dead
            }
        }

        /// How long to wait before attempt `attempt + 1`: full jitter under the
        /// backoff ceiling, or the server's retry-after when that's longer.
        func retryWait(_ failure: Backend.Failure, attempt: Int) -> TimeInterval {
            let ceiling = Self.backoffCeiling(attempt: attempt)
            var wait = jitter(ceiling)
            if case let .rateLimited(retryAfter?) = failure.kind, retryAfter > wait {
                wait = retryAfter
            }
            return TimeInterval(wait.components.seconds) + TimeInterval(wait.components.attoseconds) / 1e18
        }

        /// `min(5 min, 2 s × 2^(attempt−1))`.
        static func backoffCeiling(attempt: Int) -> Duration {
            let exponent = min(max(attempt - 1, 0), 8)
            return min(backoffCap, backoffBase * (1 << exponent))
        }

        /// In-flight items whose deadline has passed were lost to a crash
        /// mid-send: back to pending, to be sent again with the same key.
        private func resetCrashedSends() throws {
            let cutoff = Backend.Coding.timestamp(now())
            try database.writer.write { db in
                try db.execute(
                    sql: "UPDATE outbox SET status = ? WHERE status = ? AND next_attempt_at <= ?",
                    arguments: [OutboxStatus.pending.rawValue, OutboxStatus.inFlight.rawValue, cutoff]
                )
            }
        }

        /// The pending items that are due, oldest first (`created_at`, then
        /// rowid), at most one per entity, and none whose entity has an earlier
        /// item still waiting, in flight or refused. An entity's items go in
        /// order; a stuck entity never blocks another. An operation this build
        /// doesn't know (written by a newer one) is left for that build.
        private func dueItems() throws -> [OutboxRow] {
            let cutoff = Backend.Coding.timestamp(now())
            let rows = try database.writer.read { db in
                try OutboxRow.fetchAll(
                    db,
                    sql: "SELECT * FROM outbox WHERE status <> ? ORDER BY created_at, rowid",
                    arguments: [OutboxStatus.done.rawValue]
                )
            }
            var taken: Set<String> = []
            var due: [OutboxRow] = []
            for row in rows where row.operation != .unknown {
                guard !taken.contains(row.entityID) else {
                    if row.status == .pending, Backend.Coding.timestamp(row.nextAttemptAt) <= cutoff {
                        needsAnotherPass = true
                    }
                    continue
                }
                taken.insert(row.entityID)
                if row.status == .pending, Backend.Coding.timestamp(row.nextAttemptAt) <= cutoff {
                    due.append(row)
                }
            }
            return due
        }

        private func markInFlight(_ item: OutboxRow) throws {
            let deadline = now().addingTimeInterval(Self.crashedSendAfter)
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .inFlight, nextAttemptAt: deadline, attempts: item.attempts, code: item.lastErrorCode), db)
                try Self.setEntry(item.entityID, EntryChange(state: .sending), db)
            }
        }

        private func markDone(_ item: OutboxRow, result: OutboxSendResult) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .done, nextAttemptAt: item.nextAttemptAt, attempts: item.attempts + 1, code: nil), db)
                try Self.setEntry(
                    item.entityID, EntryChange(state: .sent, attempts: item.attempts + 1, serverID: result.serverID, reading: result.reading), db
                )
            }
        }

        private func markPending(_ item: OutboxRow, at date: Date) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .pending, nextAttemptAt: date, attempts: item.attempts, code: item.lastErrorCode), db)
                try Self.setEntry(item.entityID, EntryChange(state: .local), db)
            }
        }

        private func markRetry(_ item: OutboxRow, attempts: Int, at date: Date, code: FailureCode) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .pending, nextAttemptAt: date, attempts: attempts, code: code.rawValue), db)
                try Self.setEntry(item.entityID, EntryChange(state: .local, attempts: attempts), db)
            }
            log.record(.outbox(.retry(operation: item.operation, code: code)))
        }

        private func markDead(_ item: OutboxRow, attempts: Int, code: FailureCode) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .dead, nextAttemptAt: item.nextAttemptAt, attempts: attempts, code: code.rawValue), db)
                try Self.setEntry(item.entityID, EntryChange(state: .failed, attempts: attempts, failureCode: code.rawValue), db)
            }
            log.record(.outbox(.dead(operation: item.operation, code: code)))
        }

        /// What a pass writes back to an item.
        private struct ItemChange {
            var status: OutboxStatus
            var nextAttemptAt: Date
            var attempts: Int
            var code: String?
        }

        private static func setItem(_ id: String, _ change: ItemChange, _ db: GRDB.Database) throws {
            try db.execute(
                sql: "UPDATE outbox SET status = ?, next_attempt_at = ?, attempts = ?, last_error_code = ? WHERE id = ?",
                arguments: [change.status.rawValue, Backend.Coding.timestamp(change.nextAttemptAt), change.attempts, change.code, id]
            )
        }

        /// What a send writes back to its entry; a nil field keeps the column.
        private struct EntryChange {
            var state: SyncState
            var attempts: Int?
            var serverID: String?
            var reading: Reading?
            var failureCode: String?

            init(state: SyncState, attempts: Int? = nil, serverID: String? = nil, reading: Reading? = nil, failureCode: String? = nil) {
                self.state = state
                self.attempts = attempts
                self.serverID = serverID
                self.reading = reading
                self.failureCode = failureCode
            }
        }

        /// An entity that isn't an entry (later operations) is left alone.
        private static func setEntry(_ id: String, _ change: EntryChange, _ db: GRDB.Database) throws {
            try db.execute(
                sql: """
                UPDATE entries SET sync_state = ?, attempts = COALESCE(?, attempts), server_id = COALESCE(?, server_id),
                reading = COALESCE(?, reading), failure_code = ? WHERE local_id = ?
                """,
                arguments: [change.state.rawValue, change.attempts, change.serverID, change.reading?.rawValue, change.failureCode, id]
            )
        }

        private static func milliseconds(since start: Date, now: Date) -> Int {
            max(0, Int((now.timeIntervalSince(start) * 1000).rounded()))
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
