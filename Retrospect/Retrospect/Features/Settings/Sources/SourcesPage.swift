//
//  SourcesPage.swift
//  V2.settings · ST-3 sources (Paper 1GL7-0): everything retro reads, what each is for, and anything
//  that needs you. Group "connected": source rows with their wells and status (connected, the
//  "+ connect" pill, a red dot with "reconnect", the syncing ring). Only a source with its own page
//  drawn (calendar, ST-4) opens one (ST-D12). Paper's second group, "add a source ›" and "import a
//  file ›", has no drawn destination, so it is hidden until it is drawn (ST-D9; DECISIONS 5's
//  precedent for "see all").
//
import SwiftUI

struct SourcesPage: View {
    let data: any Flows.SettingsData
    let open: (SettingsRoute) -> Void
    let back: () -> Void

    var body: some View {
        SettingsPageFrame(title: "sources", back: back) {
            SettingsLabelledGroup(label: "connected") {
                RSettingsGroup(inset: .afterIcon) {
                    ForEach(data.sources) { source in
                        RSourceRow(
                            title: source.name,
                            purpose: source.purpose,
                            symbol: source.symbol,
                            state: Self.rowState(source.status),
                            connect: { Task { await data.connect(source.id) } },
                            open: source.hasPage ? { open(.source(source.id)) } : nil
                        )
                        .accessibilityIdentifier("sources.row.\(source.id)")
                    }
                }
            }
        }
    }

    static func rowState(_ status: Flows.Settings.SourceStatus) -> RSourceRow.State {
        switch status {
        case .connected: .connected
        case .syncing: .syncing
        case .needsYou: .needsAttention
        case .notConnected: .notConnected
        }
    }
}
