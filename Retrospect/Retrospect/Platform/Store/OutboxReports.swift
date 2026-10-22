import Foundation
import GRDB

// MARK: Reports (DG.5b)

extension Store.Outbox {
    /// A report was delivered: its id and the short reference to quote.
    struct ReportReceipt: Sendable, Equatable {
        let reportID: String
        let reference: String
    }

    /// Queues a report. The row's id, entity and key are the report's id, so
    /// queueing the same report twice stores one row, and the door, which is
    /// idempotent on that key, makes one reference. Like an entry, it survives
    /// a relaunch and goes out when there is a connection. Throws if the
    /// report's id isn't a UUID.
    @discardableResult
    func enqueueReport(_ report: Platform.Diagnostics.Report) throws -> UUID {
        guard let reportID = UUID(uuidString: report.reportId) else { throw Backend.Failure(.invalidRequest) }
        let payload = try Backend.Coding.encoder.encode(report)
        let id = reportID.uuidString.lowercased()
        let queuedAt = now()
        let item = Store.OutboxRow(
            id: id, operation: .diagnosticsSend, entityID: id, payload: payload, attempts: 0,
            nextAttemptAt: queuedAt, status: .pending, lastErrorCode: nil, createdAt: queuedAt
        )
        let isNew = try database.writer.write { db -> Bool in
            if let existing = try Store.OutboxRow.fetchOne(db, key: id) {
                // Sending again a report that was refused puts it back in the queue.
                guard existing.status == .dead else { return false }
                try db.execute(
                    sql: "UPDATE outbox SET status = ?, attempts = 0, last_error_code = NULL, next_attempt_at = ?, payload = ? WHERE id = ?",
                    arguments: [Store.OutboxStatus.pending.rawValue, Backend.Coding.timestamp(queuedAt), payload, id]
                )
                return true
            }
            try item.insert(db)
            return true
        }
        guard isNew else { return reportID }
        log.record(.outbox(.enqueued(operation: .diagnosticsSend)))
        if started {
            Task { await drain(reason: .afterWrite) }
        }
        return reportID
    }

    /// Drops every report that hasn't been delivered (queued, in flight or
    /// refused). Sign-out calls it (PL1.5): a report holds the person's note and
    /// device facts, and must never be sent under whoever signs in next.
    func discardReports() throws {
        try database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM outbox WHERE operation = ? AND status <> ?",
                arguments: [Store.OutboxOperation.diagnosticsSend.rawValue, Store.OutboxStatus.done.rawValue]
            )
        }
    }

    /// Each report as it's delivered, with its reference (for the "sent"
    /// toast). Reports delivered while nobody listens are not replayed.
    func receipts() -> AsyncStream<ReportReceipt> {
        let token = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: ReportReceipt.self)
        receiptListeners[token] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.dropListener(token) }
        }
        return stream
    }

    private func dropListener(_ token: UUID) {
        receiptListeners[token] = nil
    }

    func publish(_ receipt: ReportReceipt) {
        receiptListeners.values.forEach { $0.yield(receipt) }
    }
}
