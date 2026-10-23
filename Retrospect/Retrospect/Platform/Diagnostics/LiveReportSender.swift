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
    ///
    /// The device is read only on send (`context`), never for the counts: the free-disk class is
    /// declared for "send a report" alone (privacy reason 7D9E.1). The report names where it came
    /// from with the existing ids: the sheet opening, then the send button on `origin`.
    @MainActor
    final class LiveReportSender: Flows.ReportSending {
        private let recorder: Recorder
        private let outbox: Store.Outbox
        private let reachability: any Backend.Reachability
        private let origin: Screen
        private let context: @MainActor (_ isOnline: Bool) -> ReportContext
        private let now: @Sendable () -> Date

        init(
            recorder: Recorder,
            outbox: Store.Outbox,
            reachability: any Backend.Reachability,
            origin: Screen = .settings,
            context: @escaping @MainActor (_ isOnline: Bool) -> ReportContext,
            now: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.recorder = recorder
            self.outbox = outbox
            self.reachability = reachability
            self.origin = origin
            self.context = context
            self.now = now
        }

        func included() async -> Flows.ReportIncluded {
            // A closed stack records nothing: a record waiting in memory would land in the next person's rings.
            guard await !outbox.stopped else { return .empty }
            await recorder.record(.event(.sheetOpened(.sendReport)))
            let preview = ReportContext(environment: .unread, account: .preview)
            guard let report = try? await build(note: nil, known: preview) else { return .empty }
            return Self.included(in: report, now: now())
        }

        func send(note: String?) async -> Flows.ReportOutcome {
            guard await !outbox.stopped else { return .failed(Flows.Failure(.unknown)) }
            await recorder.record(.event(.controlTapped(.reportSend, on: origin)))
            do {
                let online = await reachability.isOnline
                let report = try await build(note: note, known: context(online))
                // The person's stack closed while the sheet was up: nothing is written anywhere.
                guard try await outbox.enqueueReportIfRunning(report) else { return .failed(Flows.Failure(.unknown)) }
                return .queued(reportID: report.reportId, online: online)
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

        private func build(note: String?, known: ReportContext) async throws -> Report {
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

extension Platform.Diagnostics.Environment {
    /// Nothing read from the phone. The counts preview's stand-in; never sent.
    static var unread: Self {
        Self(sources: Sources(
            info: nil, osVersion: OperatingSystemVersion(), machine: nil, locale: Locale(identifier: ""), timeZone: .gmt,
            contentSize: .unspecified, reduceMotion: false, voiceOver: false, network: .unknown, freeDiskBytes: nil
        ))
    }
}

extension Platform.Diagnostics.Account {
    /// The counts preview's stand-in; never sent (a sent report takes the account from `context`).
    static let preview = Self(provider: .apple, access: .member, entitlement: .none)
}

extension Store.Outbox {
    /// Queues `report` unless this outbox has stopped (its person signed out, or their session
    /// ended, while the sheet was up). One step on the outbox, so a stop can't land between the
    /// check and the write. False when nothing was written.
    func enqueueReportIfRunning(_ report: Platform.Diagnostics.Report) throws -> Bool {
        guard !stopped else { return false }
        try enqueueReport(report)
        return true
    }
}
