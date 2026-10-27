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
    @State private var deleting = false
    @State private var status = RDialog.Status.rest

    var body: some View {
        SettingsPageFrame(title: "privacy", back: back) {
            RSettingsGroup {
                SettingsSwitchRow(
                    title: "read in the background",
                    subline: "off means retro only learns from what you send it",
                    isOn: Binding { data.ambient.enabled } set: { isOn in
                        // the switch shows what is saved: if this fails, it snaps back (contract 06 §1)
                        Task { try? await data.setAmbient(enabled: isOn) }
                    }
                )
                .accessibilityIdentifier("privacy.readInBackground")
                RSettingsRow(title: "where it's processed", subline: Self.processedWhere)
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
        #if DEBUG
        .modifier(SettingsLaunchDialogOpen(isPresented: $deleting))
        #endif
    }

    /// Paper 1GPU-0. An app string, not a server value: contract 06 has no field for it.
    static let processedWhere = "europe · named providers"

    private func confirmDelete() async {
        // a second tap before the dialog re-renders does nothing
        guard status != .pending else { return }
        status = .pending
        do {
            try await data.deleteMyData()
            status = .rest
            deleting = false
        } catch {
            // provisional words, as the RDialog gallery's (ST-D19)
            status = .error(message: "retro couldn't be reached. try again.")
        }
    }
}

#if DEBUG
#Preview("ST-5 privacy") {
    SettingsPrivacyPage(data: SampleSettings(), back: {})
}
#endif
