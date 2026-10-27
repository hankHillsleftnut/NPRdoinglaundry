//
//  JournalV2Screens+Launcher.swift
//  V2 lane 1 (plan-v2.md §3): the journal's other pages, JR-2 today's brief, JR-3 all entries,
//  JR-4 one entry, opened with `-Screen JR-<n> -State <state> -Data sample`. Dark: listed here and
//  nowhere in the release root. JR-1 stays in `Features/Journal/JournalScreens+Launcher.swift`.
//
#if DEBUG
import SwiftUI

enum JournalV2Screens: ScreenGroup {
    static let name = "journal · v2"
    /// JR-2 (today's brief) lists itself in `Features/Entries/Brief/BriefLaunch.swift`.
    static let screens: [LaunchableScreen] = briefScreens
}
#endif
