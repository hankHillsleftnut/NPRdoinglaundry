import Foundation

extension Platform.Diagnostics {
    /// What the recorder and the store don't know: the device and the account.
    struct ReportContext {
        var environment: Environment
        var account: Account
    }

    /// The live "send a report" (DG.6): builds the report from the rings, the outbox and what
    /// the app knows of the device and the account, then queues it with the outbox (DG.5b),
    /// which keeps it until it's delivered. Counts for the sheet come from the same builder, so
    /// the preview is the report.
    @MainActor
    final class LiveReportSender: Flows.ReportSending {
        private let recorder: Recorder
        private let outbox: Store.Outbox
        private let reachability: any Backend.Reachability
        private let context: @MainActor () -> ReportContext
        private let now: @Sendable () -> Date

        init(
            recorder: Recorder,
            outbox: Store.Outbox,
            reachability: any Backend.Reachability,
            context: @escaping @MainActor () -> ReportContext,
            now: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.recorder = recorder
            self.outbox = outbox
            self.reachability = reachability
            self.context = context
            self.now = now
        }

        func included() async -> Flows.ReportIncluded {
            guard let report = try? await build(note: nil) else { return .empty }
            return Self.included(in: report, now: now())
        }

        func send(note: String?) async -> Flows.ReportOutcome {
            do {
                let report = try await build(note: note)
                try await outbox.enqueueReport(report)
                return await .queued(reportID: report.reportId, online: reachability.isOnline)
            } catch {
                return .failed(Flows.Failure(.unknown))
            }
        }

        func receipts() -> AsyncStream<Flows.ReportReceipt> {
            let (stream, continuation) = AsyncStream.makeStream(of: Flows.ReportReceipt.self)
            let outbox = outbox
            let forwarding = Task {
                for await receipt in await outbox.receipts() {
                    continuation.yield(Flows.ReportReceipt(reportID: receipt.reportID, reference: receipt.reference))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in forwarding.cancel() }
            return stream
        }

        private func build(note: String?) async throws -> Report {
            let known = context()
            let builtAt = now()
            let summary = try OutboxSummary.read(from: outbox.database, now: builtAt)
            return try await ReportBuilder.build(
                now: builtAt,
                inputs: ReportBuilder.Inputs(
                    note: note, environment: known.environment, account: known.account, outbox: summary
                ),
                recorder: recorder
            )
        }

        /// The counts the sheet shows.
        static func included(in report: Report, now: Date) -> Flows.ReportIncluded {
            let oldest = report.events.map(\.at).min() ?? now
            let days = report.events.isEmpty ? 0 : min(7, max(1, Int(now.timeIntervalSince(oldest) / 86400) + 1))
            return Flows.ReportIncluded(
                events: report.events.count, requests: report.network.count,
                problems: report.failures.count + report.crashes.count,
                unsent: report.outbox.queued + report.outbox.sending + report.outbox.failed, days: days
            )
        }
    }
}
