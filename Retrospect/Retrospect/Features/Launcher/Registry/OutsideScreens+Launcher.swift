//
//  OutsideScreens+Launcher.swift
//  V2 lane 5 (plan-v2.md §3): the views of EX-1 share, EX-2 lock screen, EX-3 notifications, EX-4
//  widgets (the views only; the extension targets wait on the founder's entitlements), opened with
//  `-Screen EX-<n> -State <state> -Data sample`. Dark: listed here and nowhere in the release root.
//
#if DEBUG
import SwiftUI

enum OutsideScreens: ScreenGroup {
    static let name = "outside the app"
    /// Empty until lane 5's first outside-the-app PR adds one.
    static let screens: [LaunchableScreen] = []
}
#endif
