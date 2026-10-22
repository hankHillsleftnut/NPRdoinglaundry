//
//  SampleReportSender.swift
//  DG.6: a report sender that makes up counts and "delivers" after a moment, for the lab page,
//  previews and tests of the sheet. It sends nothing anywhere.
//
import Foundation

@MainActor
final class SampleReportSender: Flows.ReportSending {
    enum Scenario {
        case online
        case offline
        case failing
    }

    let scenario: Scenario
    private(set) var notes: [String?] = []
    private var listeners: [AsyncStream<Flows.ReportReceipt>.Continuation] = []

    init(scenario: Scenario = .online) {
        self.scenario = scenario
    }

    func included() async -> Flows.ReportIncluded {
        Flows.ReportIncluded(events: 1284, requests: 396, problems: 2, unsent: scenario == .offline ? 1 : 0, days: 3)
    }

    func send(note: String?) async -> Flows.ReportOutcome {
        notes.append(note)
        if scenario == .failing {
            return .failed(Flows.Failure(.unknown))
        }
        let id = UUID().uuidString.lowercased()
        if scenario == .online {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.deliver(Flows.ReportReceipt(reportID: id, reference: "r-7KQ2"))
            }
        }
        return .queued(reportID: id, online: scenario == .online)
    }

    func receipts() -> AsyncStream<Flows.ReportReceipt> {
        let (stream, continuation) = AsyncStream.makeStream(of: Flows.ReportReceipt.self)
        listeners.append(continuation)
        return stream
    }

    private func deliver(_ receipt: Flows.ReportReceipt) {
        listeners.forEach { $0.yield(receipt) }
    }
}

#if DEBUG
import SwiftUI

/// Lab page "report": the settings rows over a page, the sheet from the row, and a shake
/// in the simulator (Device › Shake).
struct SendReportGallery: View {
    @State private var sender = SampleReportSender(scenario: .online)

    var body: some View {
        RSheetHost {
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space6) {
                    Text("settings").rText(.inkTitle).foregroundStyle(RColor.textPrimary)
                    DiagnosticsSettingsGroup()
                }
                .padding(RDimension.spaceScreenMargin)
            }
            .background(RColor.backgroundCanvas)
            .sendReport(bottomInset: RDimension.spaceScreenMargin)
        }
        .environment(\.reportSender, sender)
    }
}

#Preview("send a report") { SendReportGallery() }
#endif
