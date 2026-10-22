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
            case launch, foreground, reachability, afterWrite, backgroundTask, manual, retryTimer
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
        let now: @Sendable () -> Date
        private let timeZone: @Sendable () -> TimeZone
        private let jitter: @Sendable (Duration) -> Duration
        /// Chooses an acknowledgement line: an index below its argument.
        private let pick: @Sendable (Int) -> Int
        let log: any Platform.LogSink
        /// Sleeps until a retry is due; replaceable so tests don't wait.
        private let sleep: @Sendable (TimeInterval) async throws -> Void
        private var retryWake: Task<Void, Never>?
        private var isDraining = false
        private var needsAnotherPass = false
        var started = false
        private var reachabilityWatch: Task<Void, Never>?
        var receiptListeners: [UUID: AsyncStream<ReportReceipt>.Continuation] = [:]

        /// Without a sender the outbox only queues (previews, the queue's own
        /// tests); `drain` does nothing.
        init(
            database: LocalDatabase,
            sender: (any OutboxSending)? = nil,
            reachability: (any Backend.Reachability)? = nil,
            now: @escaping @Sendable () -> Date = { Date() },
            timeZone: @escaping @Sendable () -> TimeZone = { .current },
            jitter: @escaping @Sendable (Duration) -> Duration = Backend.Client.randomJitter,
            pick: @escaping @Sendable (Int) -> Int = { Int.random(in: 0 ..< max(1, $0)) },
            sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
            log: any Platform.LogSink
        ) {
            self.sleep = sleep
            self.database = database
            self.sender = sender
            self.reachability = reachability
            self.now = now
            self.timeZone = timeZone
            self.jitter = jitter
            self.pick = pick
            self.log = log
        }

        deinit {
            reachabilityWatch?.cancel()
            retryWake?.cancel()
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

        /// Queues a guess's answer (PL3.1 F4): the entity is the guess, the key
        /// is the row's own id (the door ignores it, so a repeat is safe). The
        /// screen flips the guess itself; the drainer never touches it.
        @discardableResult
        func enqueueGuessAnswer(guessID: String, verdict: Flows.Journal.GuessVerdict) throws -> UUID {
            let payload = try Backend.Coding.encoder.encode(Backend.Endpoints.AnswerGuess.Body(verdict: verdict))
            let key = UUID()
            let queuedAt = now()
            let item = OutboxRow(
                id: key.uuidString.lowercased(), operation: .guessAnswer, entityID: guessID, payload: payload, attempts: 0,
                nextAttemptAt: queuedAt, status: .pending, lastErrorCode: nil, createdAt: queuedAt
            )
            try database.writer.write { try item.insert($0) }
            log.record(.outbox(.enqueued(operation: .guessAnswer)))
            if started {
                Task { await drain(reason: .afterWrite) }
            }
            return key
        }

        /// Entries and answers not yet sent: pending, in flight or refused (a
        /// report isn't the person's words, so it isn't counted). Feeds
        /// sign-out's "you have unsent entries" (PL1.5).
        func unsentCount() throws -> Int {
            try database.writer.read { db in
                try Store.OutboxRow
                    .filter([OutboxStatus.pending, .inFlight, .dead].map(\.rawValue).contains(Column(OutboxRow.CodingKeys.status)))
                    .filter(Column(OutboxRow.CodingKeys.operation) != OutboxOperation.diagnosticsSend.rawValue)
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
                let dead = try Store.OutboxRow
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
            var paused = false
            repeat {
                needsAnotherPass = false
                paused = await pass()
            } while needsAnotherPass && !paused && !Task.isCancelled
            // A pause (offline, signed out) is ended by its own trigger:
            // reachability, sign-in, foreground. Otherwise wake for the next retry.
            if !paused, !Task.isCancelled {
                scheduleRetryWake()
            }
        }

        private struct Tally {
            var sent = 0
            var failed = 0
        }

        /// One pass over what's due, oldest first.
        /// Returns true when the pass paused (offline, signed out): no more passes.
        private func pass() async -> Bool {
            guard let sender, (try? resetCrashedSends()) != nil, let due = try? dueItems() else { return false }
            var paused = false
            var tally = Tally()
            for queued in due where !Task.isCancelled {
                guard let item = try? markInFlight(queued) else { continue }
                let startedAt = now()
                do {
                    let result = try await sender.send(item)
                    try markDone(item, result: result)
                    tally.sent += 1
                    if item.operation == .diagnosticsSend, let reference = result.reference {
                        publish(ReportReceipt(reportID: item.id, reference: reference))
                    }
                    log.record(.outbox(.sent(operation: item.operation, attempts: item.attempts + 1, ms: Self.milliseconds(since: startedAt, now: now()))))
                } catch is CancellationError {
                    try? markPending(item, at: now())
                    break
                } catch {
                    if settle(error, item: item, tally: &tally) == .pause {
                        paused = true
                        break
                    }
                }
            }
            log.record(.outbox(.drained(sent: tally.sent, failed: tally.failed)))
            return paused
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
            var included: Set<String> = []
            var due: [OutboxRow] = []
            for row in rows where row.operation != .unknown {
                let isDue = row.status == .pending && Backend.Coding.timestamp(row.nextAttemptAt) <= cutoff
                guard !taken.contains(row.entityID) else {
                    // Due, behind an item this pass is sending: one more pass picks it up.
                    // Behind a stuck one (not due, in flight, refused): it waits, no extra pass.
                    if isDue, included.contains(row.entityID) {
                        needsAnotherPass = true
                    }
                    continue
                }
                taken.insert(row.entityID)
                if isDue {
                    included.insert(row.entityID)
                    due.append(row)
                }
            }
            return due
        }

        /// Marks the item in flight with its crash deadline and the entry
        /// `sending`; returns the item as stored, which is what the sender sees.
        private func markInFlight(_ item: OutboxRow) throws -> OutboxRow {
            let deadline = now().addingTimeInterval(Self.crashedSendAfter)
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .inFlight, nextAttemptAt: deadline, attempts: item.attempts, code: item.lastErrorCode), db)
                try Self.setEntry(of: item, EntryChange(state: .sending), db)
            }
            var sending = item
            sending.status = .inFlight
            sending.nextAttemptAt = deadline
            return sending
        }

        /// `done`, and for an entry: `sent`, the server's id, reading, `createdAt`
        /// and `day`, and its acknowledgement line, chosen now if it has none
        /// (never the newest line already stored) and never changed after.
        private func markDone(_ item: OutboxRow, result: OutboxSendResult) throws {
            let pick = pick
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .done, nextAttemptAt: item.nextAttemptAt, attempts: item.attempts + 1, code: nil), db)
                if item.operation == .diagnosticsSend {
                    // Delivered: the report's bytes aren't kept (the rings they came from are the device's own).
                    try db.execute(sql: "UPDATE outbox SET payload = ? WHERE id = ?", arguments: [Data(), item.id])
                }
                guard item.operation == .entryCreate else { return }
                let previous = try String.fetchOne(
                    db, sql: "SELECT acknowledgement FROM entries WHERE acknowledgement IS NOT NULL ORDER BY created_at DESC, rowid DESC LIMIT 1"
                )
                let line = Flows.Journal.Acknowledgements.next(after: previous, pick: pick)
                try Self.setEntry(of: item, EntryChange(
                    state: .sent, attempts: item.attempts + 1, serverID: result.serverID, reading: result.reading,
                    createdAt: result.createdAt, day: result.day, acknowledgement: line
                ), db)
            }
        }

        private func markPending(_ item: OutboxRow, at date: Date) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .pending, nextAttemptAt: date, attempts: item.attempts, code: item.lastErrorCode), db)
                try Self.setEntry(of: item, EntryChange(state: .local), db)
            }
        }

        private func markRetry(_ item: OutboxRow, attempts: Int, at date: Date, code: FailureCode) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .pending, nextAttemptAt: date, attempts: attempts, code: code.rawValue), db)
                try Self.setEntry(of: item, EntryChange(state: .local, attempts: attempts), db)
            }
            log.record(.outbox(.retry(operation: item.operation, code: code)))
        }

        private func markDead(_ item: OutboxRow, attempts: Int, code: FailureCode) throws {
            try database.writer.write { db in
                try Self.setItem(item.id, ItemChange(status: .dead, nextAttemptAt: item.nextAttemptAt, attempts: attempts, code: code.rawValue), db)
                try Self.setEntry(of: item, EntryChange(state: .failed, attempts: attempts, failureCode: code.rawValue), db)
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
            var createdAt: Date?
            var day: String?
            /// Kept only if the row has none yet (`COALESCE`).
            var acknowledgement: String?
            var failureCode: String?

            init(
                state: SyncState, attempts: Int? = nil, serverID: String? = nil, reading: Reading? = nil,
                createdAt: Date? = nil, day: String? = nil, acknowledgement: String? = nil, failureCode: String? = nil
            ) {
                self.state = state
                self.attempts = attempts
                self.serverID = serverID
                self.reading = reading
                self.createdAt = createdAt
                self.day = day
                self.acknowledgement = acknowledgement
                self.failureCode = failureCode
            }
        }

        /// Only an entry's own item writes to `entries`; another operation's
        /// entity (a guess) lives elsewhere and is never touched here.
        private static func setEntry(of item: OutboxRow, _ change: EntryChange, _ db: GRDB.Database) throws {
            guard item.operation == .entryCreate else { return }
            try db.execute(
                sql: """
                UPDATE entries SET sync_state = ?, attempts = COALESCE(?, attempts), server_id = COALESCE(?, server_id),
                reading = COALESCE(?, reading), created_at = COALESCE(?, created_at), day = COALESCE(?, day),
                acknowledgement = COALESCE(acknowledgement, ?), failure_code = ? WHERE local_id = ?
                """,
                arguments: [
                    change.state.rawValue, change.attempts, change.serverID, change.reading?.rawValue,
                    change.createdAt.map(Backend.Coding.timestamp), change.day, change.acknowledgement, change.failureCode, item.entityID,
                ]
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

extension Store.Outbox {
    /// One sleeping task, for the earliest pending item that isn't due yet.
    private func scheduleRetryWake() {
        retryWake?.cancel()
        retryWake = nil
        guard started, let next = try? earliestPendingAt() else { return }
        let wait = max(0, next.timeIntervalSince(now()))
        let sleep = sleep
        retryWake = Task { [weak self] in
            do { try await sleep(wait) } catch { return }
            await self?.drain(reason: .retryTimer)
        }
    }

    private func earliestPendingAt() throws -> Date? {
        let current = now()
        return try database.writer.read { db in
            try Store.OutboxRow
                .filter(Column(Store.OutboxRow.CodingKeys.status) == Store.OutboxStatus.pending.rawValue)
                .fetchAll(db)
                .map(\.nextAttemptAt)
                .filter { $0 > current }
                .min()
        }
    }
}
