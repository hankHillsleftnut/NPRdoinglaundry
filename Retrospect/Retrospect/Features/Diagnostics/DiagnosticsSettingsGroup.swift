//
//  DiagnosticsSettingsGroup.swift
//  DG.6: the settings rows for reports: "send a report", which opens the sheet, and "shake to
//  send a report", the trigger's switch (docs/team/flows/diagnostics.md). One group the settings
//  page drops in; the page itself waits for phase 6, so this is shown on the lab page until then.
//
import SwiftUI

struct DiagnosticsSettingsGroup: View {
    @Environment(\.openSendReport) private var open
    @AppStorage(ShakePreference.key) private var shakeOn = ShakePreference.defaultValue

    var body: some View {
        RSettingsGroup {
            RSettingsRow(
                title: "send a report", subline: "tell us what went wrong, with what the app did", symbol: "paperplane",
                trailing: .nav, action: open
            )
            .accessibilityIdentifier("settings.sendReport")
            RSettingsRow(
                title: "shake to send a report", subline: shakeOn ? "shake the phone anywhere" : "off", symbol: "iphone.radiowaves.left.and.right",
                trailing: .toggle($shakeOn)
            )
            .accessibilityIdentifier("settings.shakeToReport")
        }
    }
}
