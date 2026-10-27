//
//  SettingsPrivacyPage.swift
//  V2.settings · ST-5 privacy (Paper 1GP6-0). Your ambient switch ("read in the background": off means
//  retro learns only from what you send it), where your data is processed, a copy of your data, and,
//  alone and last in the thumb zone, deleting it. The switch applies at once. Undrawn, so inert and
//  saying "not available yet": the processed page and the export (G13, ST-D18). The delete dialog's
//  words are provisional (ST-D19) and nothing after a delete is drawn, so confirming closes it. The
//  founder's paused-for-everyone switch has no look yet (ST-D20).
//
import SwiftUI

struct SettingsPrivacyPage: View {
    let data: any Flows.SettingsTrustData
    let back: () -> Void
    @State private var deleting: Bool
    @State private var status = RDialog.Status.rest

    init(data: any Flows.SettingsTrustData, deleting: Bool = false, back: @escaping () -> Void) {
        self.data = data
        self.back = back
        _deleting = State(initialValue: deleting)
    }

    var body: some View {
        SettingsPageFrame(title: "privacy", back: back) {
            RSettingsGroup {
                SettingsSwitchRow(
                    title: "read in the background",
                    subline: "off means retro only learns from what you send it",
                    isOn: Binding { data.readsInBackground } set: { data.setReadsInBackground($0) }
                )
                .accessibilityIdentifier("privacy.readInBackground")
                RSettingsRow(title: "where it's processed", subline: data.processedWhere)
                    .accessibilityHint("not available yet")
                    .accessibilityIdentifier("privacy.processed")
                SettingsActionRow(title: "download my data", pill: "export", symbol: "arrow.down.to.line")
            }
        } danger: {
            RSettingsRow(
                title: "delete my data…",
                subline: "everything retro knows about you",
                symbol: "exclamationmark.circle",
                trailing: .none,
                danger: true
            ) {
                status = .rest
                deleting = true
            }
            .accessibilityIdentifier("privacy.delete")
        }
        .rDialog(isPresented: $deleting) {
            RDialog(
                title: "delete my data?",
                line: "this removes everything retro knows about you. your account stays. it can't be undone.",
                confirmTitle: "delete my data",
                status: status
            ) {
                Task { await confirmDelete() }
            } cancel: {
                deleting = false
            }
        }
    }

    private func confirmDelete() async {
        status = .pending
        await data.deleteMyData()
        status = .rest
        deleting = false
    }
}

#if DEBUG
#Preview("ST-5 privacy") {
    SettingsPrivacyPage(data: SampleSettings(), back: {})
}
#endif
