//
//  SourcePage.swift
//  V2.settings · ST-4 a source (Paper 1GNV-0, calendar): what it reads and what it helps retro see,
//  in two labelled sentences; when it last read, with "sync now"; then, alone and last in the thumb
//  zone, "disconnect…" and "delete what it read…", each asking first in the part 24 dialog.
//  ST-D14: the dialogs' words aren't drawn; these are the settings cards' (C50.1 #1, #2), to confirm.
//  ST-D15: after a sync the line reads "last read just now" (not drawn).
//
import SwiftUI

struct SourcePage: View {
    enum Asking: Equatable {
        case disconnect, delete
    }

    let data: any Flows.SettingsData
    let id: Flows.Settings.Source.ID
    let back: () -> Void
    @State private var asking: Asking?
    @State private var syncing = false

    init(data: any Flows.SettingsData, id: Flows.Settings.Source.ID, asking: Asking? = nil, back: @escaping () -> Void) {
        self.data = data
        self.id = id
        self.back = back
        _asking = State(initialValue: asking)
    }

    var body: some View {
        let source = data.source(id)
        SettingsPageFrame(title: source?.name ?? "", groupSpacing: RDimension.space6, back: back) {
            if let source {
                about("reads", source.reads)
                about("helps me see", source.helpsMeSee)
                SettingsActionRow(
                    title: source.lastRead ?? "",
                    pill: "sync now",
                    pending: syncing,
                    action: sync
                )
            }
        } danger: {
            if let source {
                VStack(spacing: RDimension.space0) {
                    RSettingsRow(
                        title: "disconnect…",
                        subline: "stops reading; keeps what it read",
                        symbol: "exclamationmark.circle",
                        trailing: .none,
                        danger: true
                    ) { asking = .disconnect }
                    RSettingsRow(
                        title: "delete what it read…",
                        subline: "removes it from what retro knows",
                        symbol: "exclamationmark.circle",
                        trailing: .none,
                        danger: true
                    ) { asking = .delete }
                }
                .accessibilityIdentifier("source.danger.\(source.id)")
            }
        }
        .rDialog(isPresented: isAsking) { dialog }
    }

    @ViewBuilder private func about(_ label: String, _ sentence: String?) -> some View {
        if let sentence {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                RSectionLabel(title: label)
                Text(sentence)
                    .rText(.body)
                    .foregroundStyle(RColor.textPrimary)
                    .rBalancedLines()
                    .padding(.top, RDimension.space1)
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var dialog: some View {
        let name = data.source(id)?.name ?? ""
        switch asking {
        case .disconnect:
            RDialog(
                title: "disconnect \(name)?",
                line: "retro stops reading \(name). what it already read stays. you can connect it again any time.",
                confirmTitle: "disconnect",
                cancelTitle: "cancel",
                confirm: disconnect,
                cancel: { asking = nil }
            )
        case .delete:
            RDialog(
                title: "delete what \(name) gave retro?",
                line: "everything retro took from \(name) goes, and what it learned from it. this can't be undone.",
                confirmTitle: "delete it",
                cancelTitle: "cancel",
                confirm: deleteData,
                cancel: { asking = nil }
            )
        case nil:
            EmptyView()
        }
    }

    private var isAsking: Binding<Bool> {
        Binding { asking != nil } set: {
            if !$0 {
                asking = nil
            }
        }
    }

    private func sync() {
        syncing = true
        Task {
            await data.sync(id)
            syncing = false
        }
    }

    /// Stops reading, then back to the list, where the source now offers "connect".
    private func disconnect() {
        asking = nil
        Task {
            await data.disconnect(id)
            back()
        }
    }

    private func deleteData() {
        asking = nil
        Task { await data.deleteData(of: id) }
    }
}
