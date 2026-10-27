//
//  SettingsScreens+Launcher.swift
//  V2 lane 4, first half (plan-v2.md §3): ST-1 settings, ST-2 daily brief, ST-3 sources, ST-4 a
//  source, opened with `-Screen ST-<n> -State <state> -Data sample`. Dark: listed here and nowhere
//  in the release root. ST-5…ST-9 are the second half's, in `SettingsTrustScreens+Launcher.swift`,
//  so the two settings builders never edit the same file.
//  Each screen opens inside the settings stack on the sample, so its back and its rows work: ST-2
//  opens over ST-1, and its back returns there.
//
#if DEBUG
import SwiftUI

enum SettingsScreens: ScreenGroup {
    static let name = "settings"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "ST-1", states: ["rest"]) { _ in
            AnyView(SettingsLaunch(path: []))
        },
        LaunchableScreen(id: "ST-2", states: ["rest"]) { _ in
            AnyView(SettingsLaunch(path: [.dailyBrief]))
        },
    ]
}

/// The settings stack on sample data, opened at `path`.
struct SettingsLaunch: View {
    let path: [SettingsRoute]
    @State private var data = SampleSettings()

    var body: some View {
        SettingsStack(data: data, path: path)
    }
}

#Preview("ST-1 settings") { SettingsLaunch(path: []) }
#Preview("ST-2 daily brief") { SettingsLaunch(path: [.dailyBrief]) }
#endif
