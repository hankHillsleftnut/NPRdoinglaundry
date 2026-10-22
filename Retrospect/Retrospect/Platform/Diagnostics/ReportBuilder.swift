import Foundation
import GRDB

extension Platform.Diagnostics {
    /// Builds a report from the rings, the outbox's state and what the caller
    /// knows (the device, the account, the note). Sending it is the outbox's
    /// job (`diagnostics.send`, once PL2.2a/b are in).
    enum ReportBuilder {
        /// What the caller knows and the rings don't: the note, the device,
        /// the account, the outbox's state and the performance part.
        struct Inputs: Sendable {
            var note: String?
            var environment: Environment
            var account: Account
            var outbox: OutboxSummary
            var performance: Performance

            init(note: String?, environment: Environment, account: Account, outbox: OutboxSummary, performance: Performance = .none) {
                self.note = note
                self.environment = environment
                self.account = account
                self.outbox = outbox
                self.performance = performance
            }
        }

        /// The report for the last 7 days. A ring row whose payload no longer
        /// decodes (written by another build) is skipped, never a failure.
        static func build(reportID: UUID = UUID(), now: Date, inputs: Inputs, recorder: Recorder) async throws -> Report {
            try await Report(
                reportID: reportID,
                createdAt: now,
                note: inputs.note,
                environment: inputs.environment,
                account: inputs.account,
                events: stamped(Event.self, in: .events, from: recorder),
                network: stamped(Request.self, in: .network, from: recorder),
                outbox: inputs.outbox,
                failures: stamped(Failure.self, in: .failures, from: recorder),
                performance: inputs.performance,
                crashes: stamped(Crash.self, in: .crashes, from: recorder)
            )
        }

        /// One ring decoded, oldest first; undecodable rows left out.
        static func stamped<Body: Decodable>(_: Body.Type, in ring: Ring, from recorder: Recorder) async throws -> [Stamped<Body>] {
            let decoder = Backend.Coding.decoder
            return try await recorder.rows(in: ring).compactMap { row in
                (try? decoder.decode(Body.self, from: row.payload)).map { Stamped(at: row.at, body: $0) }
            }
        }
    }
}

extension Platform.Diagnostics.OutboxSummary {
    /// The outbox table's state: pending rows are queued, in-flight ones
    /// sending, done ones sent, dead ones failed. The oldest age is that of
    /// the oldest row not yet done. The last failure codes are the newest
    /// `last_error_code`s that are contract codes; a phone-side kind
    /// (`timedOut`) isn't one and is left out.
    static func read(from database: Store.LocalDatabase, now: Date) throws -> Self {
        try database.writer.read { db in
            let counts = try Row.fetchAll(db, sql: "SELECT status, COUNT(*) AS n FROM outbox GROUP BY status")
                .reduce(into: [String: Int]()) { $0[$1["status"]] = $1["n"] }
            let oldest: String? = try String.fetchOne(
                db,
                sql: "SELECT MIN(created_at) FROM outbox WHERE status <> ?",
                arguments: [Store.OutboxStatus.done.rawValue]
            )
            let codes = try String.fetchAll(
                db,
                sql: "SELECT last_error_code FROM outbox WHERE last_error_code IS NOT NULL ORDER BY created_at DESC, rowid DESC LIMIT ?",
                arguments: [maxFailureCodes]
            )
            let oldestAge = oldest.flatMap(Store.Timestamp.date).map { Int(now.timeIntervalSince($0).rounded(.down)) }
            return Self(
                queued: counts[Store.OutboxStatus.pending.rawValue] ?? 0,
                sending: counts[Store.OutboxStatus.inFlight.rawValue] ?? 0,
                sent: counts[Store.OutboxStatus.done.rawValue] ?? 0,
                failed: counts[Store.OutboxStatus.dead.rawValue] ?? 0,
                oldestAgeSeconds: oldestAge,
                lastFailureCodes: codes.compactMap(Platform.Diagnostics.ErrorCode.init(rawValue:)).reversed()
            )
        }
    }
}
