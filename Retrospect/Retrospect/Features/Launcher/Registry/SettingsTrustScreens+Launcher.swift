//
//  SettingsTrustScreens+Launcher.swift
//  V2 lane 4, second half (plan-v2.md §3): ST-5 privacy, ST-6 how straight i am with you, ST-7
//  voice and listening, ST-8 what i've learned, ST-9 account, opened with
//  `-Screen ST-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//  The built account page keeps its own `-Screen account` in `Features/Account`.
//
#if DEBUG
import SwiftUI

enum SettingsTrustScreens: ScreenGroup {
    static let name = "settings · trust"
    /// Empty until lane 4's second-half PR adds one.
    static let screens: [LaunchableScreen] = []
}
#endif
