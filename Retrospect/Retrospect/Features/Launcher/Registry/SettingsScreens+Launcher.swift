//
//  SettingsScreens+Launcher.swift
//  V2 lane 4, first half (plan-v2.md §3): ST-1 settings, ST-2 daily brief, ST-3 sources, ST-4 a
//  source, opened with `-Screen ST-<n> -State <state> -Data sample`. Dark: listed here and nowhere
//  in the release root. ST-5…ST-9 are the second half's, in `SettingsTrustScreens+Launcher.swift`,
//  so the two settings builders never edit the same file.
//
#if DEBUG
import SwiftUI

enum SettingsScreens: ScreenGroup {
    static let name = "settings"
    /// Empty until lane 4's first screen PR adds one.
    static let screens: [LaunchableScreen] = []
}
#endif
