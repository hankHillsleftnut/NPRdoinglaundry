//
//  SettingsTrustScreens+Launcher.swift
//  V2 lane 4, second half (plan-v2.md §3): ST-5 privacy, ST-6 how straight i am with you, ST-7
//  voice and listening, ST-8 what i've learned, ST-9 account, opened with
//  `-Screen ST-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//  The built account page keeps its own `-Screen account` in `Features/Account`.
//  Each page opens inside the first half's settings stack (SettingsLaunch) on the sample, over ST-1,
//  so its back returns there and what it changes shows on ST-1.
//
#if DEBUG
import SwiftUI

enum SettingsTrustScreens: ScreenGroup {
    static let name = "settings · trust"
    static let screens: [LaunchableScreen] = [
        LaunchableScreen(id: "ST-6", states: ["rest"]) { _ in
            AnyView(SettingsLaunch(path: [.howStraight]))
        },
        LaunchableScreen(id: "ST-8", states: ["rest"]) { _ in
            AnyView(SettingsLaunch(path: [.learned]))
        },
    ]
}
#endif
