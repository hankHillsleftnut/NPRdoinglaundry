//
//  ScreenGroup.swift
//  V2.registry: the launcher's screens come from groups. A group is one type, in its own file,
//  that lists its screens; `ScreenRegistry.groups` is the one list of group types. Every group the
//  app will have (the core flow's and V2's: journal, podcasts, goals, you, settings, outside, the
//  shell) already has its line, so a screen PR edits only its own group's file and never
//  `ScreenLauncher.swift` or this list. A group with no screens yet adds nothing to the launcher.
//  Debug and UI-test builds only.
//
#if DEBUG
import SwiftUI

/// One group of launchable screens, registered from the group's own file.
protocol ScreenGroup {
    /// A short name for the group, used by tests and the unknown-screen page.
    static var name: String { get }
    /// The group's screens, in the order the group lists them.
    static var screens: [LaunchableScreen] { get }
}

extension ScreenRegistry {
    /// Every group, core flow first, then V2 in the plan's lane order. A NEW group (rare: every
    /// planned group is here) is one line; screens never go here.
    static let groups: [any ScreenGroup.Type] = [
        // the core flow (splash → first home) and the screens built before V2
        SignInScreenGroup.self,
        InviteScreenGroup.self,
        FirstRunScreenGroup.self,
        JournalScreenGroup.self,
        AccountScreenGroup.self,
        ForceUpdateScreenGroup.self,
        // V2 (plan-v2.md §3): dark, reachable only from here and the lab
        JournalV2Screens.self,
        PodcastsScreens.self,
        YouScreens.self,
        SettingsScreens.self,
        SettingsTrustScreens.self,
        GoalsScreens.self,
        OutsideScreens.self,
        ShellScreens.self,
    ]

    /// Every group's screens, in group order (duplicates included; a test asserts there are none).
    static var groupScreens: [LaunchableScreen] {
        groups.reduce(into: []) { screens, group in screens += group.screens }
    }
}
#endif
