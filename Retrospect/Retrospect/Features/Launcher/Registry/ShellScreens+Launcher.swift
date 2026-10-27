//
//  ShellScreens+Launcher.swift
//  V2 lane 0 (plan-v2.md §3): the app shell (tab bar: journal, podcasts, goals, you; the drawer),
//  opened with `-Screen shell -State <state> -Data sample`. Dark: listed here and nowhere in the
//  release root; mounting the shell in the app is a founder-approved wiring PR.
//
#if DEBUG
import SwiftUI

enum ShellScreens: ScreenGroup {
    static let name = "shell"
    /// Empty until lane 0's shell PR adds it.
    static let screens: [LaunchableScreen] = []
}
#endif
