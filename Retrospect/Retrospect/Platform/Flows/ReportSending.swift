//
//  ReportSending.swift
//  The "send a report" seam (DG.6, docs/team/flows/diagnostics.md): what the sheet shows
//  ("what's included", counts only), how it hands a report over, and the reference that comes
//  back. The sheet builds against `Flows.ReportSending` with sample data; Platform's
//  `LiveReportSender` builds the report and queues it through the outbox (DG.5b).
//
import Foundation
import SwiftUI

extension Flows {
    /// What a report would hold right now: counts only, never content.
    struct ReportIncluded: Equatable, Sendable {
        var events: Int
        var requests: Int
        var problems: Int
        var unsent: Int
        /// How many days of activity the events cover (at most 7).
        var days: Int

        static let empty = ReportIncluded(events: 0, requests: 0, problems: 0, unsent: 0, days: 0)
    }

    enum ReportOutcome: Equatable, Sendable {
        /// Saved on the phone. `online`: it is going out now; otherwise it waits for a connection.
        case queued(reportID: String, online: Bool)
        case failed(Failure)
    }

    /// A report the server has taken, with the short reference to quote.
    struct ReportReceipt: Equatable, Sendable {
        let reportID: String
        let reference: String
    }

    @MainActor
    protocol ReportSending: AnyObject {
        func included() async -> ReportIncluded
        /// Builds the report (with the person's note, trimmed and cut by the report itself) and
        /// queues it through the outbox. Never throws to a view.
        func send(note: String?) async -> ReportOutcome
        /// Each report as it's delivered. Reports delivered while nobody listens are not replayed.
        func receipts() -> AsyncStream<ReportReceipt>
    }
}

extension EnvironmentValues {
    /// The report sender: `SampleReportSender` or `LiveReportSender`. Nil outside the app.
    @Entry var reportSender: (any Flows.ReportSending)?
    /// Opens the "send a report" sheet from anywhere under `.sendReport()` (the settings row, a crash prompt).
    @Entry var openSendReport: () -> Void = {}
}
