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
        LaunchableScreen(id: "ST-3", states: ["rest"]) { _ in
            AnyView(SettingsLaunch(path: [.sources]))
        },
        LaunchableScreen(id: "ST-4", states: SourcePageScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(SourcePageLaunch(scenario: SourcePageScenario(rawValue: arguments.state) ?? .rest))
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

/// ST-4 at rest, or with one of its two questions open (for stills).
enum SourcePageScenario: String, CaseIterable {
    case rest, disconnect, delete

    var asking: SourcePage.Asking? {
        switch self {
        case .rest: nil
        case .disconnect: .disconnect
        case .delete: .delete
        }
    }
}

/// ST-4 (calendar) over ST-3 over ST-1, on the sample.
struct SourcePageLaunch: View {
    let scenario: SourcePageScenario
    @State private var data = SampleSettings()

    var body: some View {
        SettingsStack(data: data, path: [.sources, .source("calendar")], asking: scenario.asking)
    }
}

#Preview("ST-1 settings") { SettingsLaunch(path: []) }
#Preview("ST-2 daily brief") { SettingsLaunch(path: [.dailyBrief]) }
#Preview("ST-3 sources") { SettingsLaunch(path: [.sources]) }
#Preview("ST-4 disconnect") { SourcePageLaunch(scenario: .disconnect) }
#endif
