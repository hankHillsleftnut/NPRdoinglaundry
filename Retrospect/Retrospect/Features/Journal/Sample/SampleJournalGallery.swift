//
//  SampleJournalGallery.swift
//  UI1.0's proof page (lab page "journaldata"): every scenario loaded, with what each gives the
//  journal's screens, until the screen launcher (T02) opens real screens on them.
//
#if DEBUG
import SwiftUI

struct SampleJournalGallery: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RDimension.space3) {
                ForEach(JournalScenario.allCases, id: \.self) { scenario in
                    ScenarioRow(scenario: scenario)
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
    }
}

private struct ScenarioRow: View {
    let scenario: JournalScenario
    @State private var data: SampleJournalData

    init(scenario: JournalScenario) {
        self.scenario = scenario
        _data = State(initialValue: SampleJournalData(scenario: scenario))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            Text(scenario.rawValue).rText(.labelMedium).foregroundStyle(RColor.textPrimary)
            Text(summary).rText(.metaLine).foregroundStyle(RColor.textLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .task { await data.load() }
    }

    private var summary: String {
        let today = switch data.today {
        case .loading: "today loading"
        case let .failed(failure): "today failed (\(failure.kind))"
        case let .loaded(entries): "today \(entries.count) · " + deliveries(entries)
        }
        let brief = switch data.brief {
        case .loading: "brief loading"
        case let .failed(failure): "brief failed (\(failure.kind))"
        case let .loaded(slot): "brief \(name(slot))"
        }
        let guesses = data.guesses.map(\.status.rawValue).joined(separator: ", ")
        return [today, brief, "guesses [\(guesses)]", data.isOnline ? "online" : "offline"].joined(separator: " · ")
    }

    private func deliveries(_ entries: [Flows.Journal.Entry]) -> String {
        entries.map { entry in
            switch entry.delivery {
            case .sent: "sent"
            case .sending: "sending"
            case .waiting: "waiting"
            case .failed: "failed"
            }
        }
        .joined(separator: " ")
    }

    private func name(_ slot: Flows.Journal.BriefSlot) -> String {
        switch slot {
        case .off: "off"
        case .making: "making"
        case let .ready(brief): "ready (\(brief.parts.count) parts)"
        case .quiet: "quiet"
        case .none: "none"
        }
    }
}

#Preview("sample journal data") { SampleJournalGallery() }
#endif
