import Foundation
import GRDB

extension Platform.Diagnostics {
    /// The append-only recorder: `record` takes a `Record`, stamps it with the
    /// time and keeps it in the ring for its kind (`Store.DiagnosticRow`).
    /// Writes are batched: a batch lands after `flushAfter`, or at once when
    /// it reaches `batchSize`, or when `flush()` is called (on the way to the
    /// background, before a report is built). Every write also trims each
    /// ring it touched to its cap and drops rows older than `retention`.
    ///
    /// Before sign-in there's no database yet: records wait in memory (the
    /// newest `pendingCap`) and land when `attach` is called. A write that
    /// fails is logged as a count and its batch dropped; recording never
    /// throws at its callers.
    actor Recorder: Sink {
        /// 7 days: the report's window (docs/team/flows/diagnostics.md).
        static let retention: TimeInterval = 7 * 24 * 60 * 60
        static let batchSize = 50
        static let flushAfter: Duration = .seconds(2)
        /// The most records kept in memory while no database is attached:
        /// the rings' caps added up, so the first flush can fill every ring.
        static let pendingCap = Ring.allCases.map(\.cap).reduce(0, +)

        private var database: Store.LocalDatabase?
        private var pending: [Store.DiagnosticRow] = []
        private var scheduledFlush: Task<Void, Never>?
        private let now: @Sendable () -> Date
        private let clock: any Clock<Duration>
        private let log: any Platform.LogSink

        init(
            database: Store.LocalDatabase? = nil,
            now: @escaping @Sendable () -> Date = { Date() },
            clock: any Clock<Duration> = ContinuousClock(),
            log: any Platform.LogSink
        ) {
            self.database = database
            self.now = now
            self.clock = clock
            self.log = log
        }

        /// Keeps `record`, stamped with now. Returns before anything is written.
        func record(_ record: Record) {
            let payload: Data
            do {
                payload = try Self.encode(record)
            } catch {
                log.record(.diagnosticsWriteFailed)
                return
            }
            pending.append(Store.DiagnosticRow(id: nil, ring: record.ring, at: now(), payload: payload))
            if pending.count > Self.pendingCap {
                pending.removeFirst(pending.count - Self.pendingCap)
            }
            if database == nil {
                return
            }
            if pending.count >= Self.batchSize {
                flush()
            } else {
                scheduleFlush()
            }
        }

        /// The database to write to, once it's open: drops rows older than
        /// the window ("pruned on launch") and lands what was waiting.
        func attach(_ database: Store.LocalDatabase) {
            self.database = database
            do {
                try database.writer.write { try Store.DiagnosticRow.deleteOlder(than: cutoff, in: $0) }
            } catch {
                log.record(.diagnosticsWriteFailed)
            }
            flush()
        }

        /// Sign-out: lands what's waiting in this person's database, then
        /// forgets the database and anything still in memory, so nothing
        /// recorded before sign-out can reach the next person's rings.
        func detach() {
            flush()
            pending = []
            database = nil
        }

        /// Writes everything waiting, in one transaction, and trims the rings
        /// it touched. Nothing happens without a database. If the write
        /// fails, it's logged and the batch goes back to the front of the
        /// queue (newest `pendingCap` kept) for the next flush.
        func flush() {
            scheduledFlush?.cancel()
            scheduledFlush = nil
            guard let database, !pending.isEmpty else { return }
            let batch = pending
            pending = []
            do {
                try database.writer.write { db in
                    for var row in batch {
                        try row.insert(db)
                    }
                    for ring in Set(batch.map(\.ring)) {
                        try Store.DiagnosticRow.trim(ring, in: db)
                    }
                    try Store.DiagnosticRow.deleteOlder(than: cutoff, in: db)
                }
            } catch {
                log.record(.diagnosticsWriteFailed)
                pending = Array((batch + pending).suffix(Self.pendingCap))
            }
        }

        /// One ring's rows from the last 7 days, oldest first; what's still
        /// waiting in memory is flushed first. Empty without a database.
        func rows(in ring: Ring) throws -> [Store.DiagnosticRow] {
            flush()
            guard let database else { return [] }
            let cutoff = cutoff
            return try database.writer.read { try Store.DiagnosticRow.inRing(ring, since: cutoff).fetchAll($0) }
        }

        /// Waits for a flush the delay scheduled, if one is scheduled. For tests.
        func waitForScheduledFlush() async {
            await scheduledFlush?.value
        }

        private var cutoff: Date {
            now().addingTimeInterval(-Self.retention)
        }

        private func scheduleFlush() {
            guard scheduledFlush == nil else { return }
            scheduledFlush = Task {
                try? await clock.sleep(for: Self.flushAfter)
                guard !Task.isCancelled else { return }
                flush()
            }
        }

        /// The record's JSON (the report's shape), keys sorted.
        static func encode(_ record: Record) throws -> Data {
            switch record {
            case let .event(event): try Backend.Coding.encoder.encode(event)
            case let .request(request): try Backend.Coding.encoder.encode(request)
            case let .failure(failure): try Backend.Coding.encoder.encode(failure)
            case let .crash(crash): try Backend.Coding.encoder.encode(crash)
            }
        }
    }
}
