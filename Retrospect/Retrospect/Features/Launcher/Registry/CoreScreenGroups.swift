//
//  CoreScreenGroups.swift
//  V2.registry: the groups built before the registry split. Each one still lists its screens in
//  its own feature folder (`Features/<Flow>/<Flow>Screens+Launcher.swift`, unchanged, so open PRs
//  that add a scenario there keep applying); these types only name them as groups.
//
#if DEBUG
import SwiftUI

enum SignInScreenGroup: ScreenGroup {
    static let name = "sign in"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.signInScreens
    }
}

enum InviteScreenGroup: ScreenGroup {
    static let name = "invite"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.inviteScreens
    }
}

enum FirstRunScreenGroup: ScreenGroup {
    static let name = "first run"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.firstRunScreens
    }
}

enum JournalScreenGroup: ScreenGroup {
    static let name = "journal"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.journalScreens
    }
}

enum AccountScreenGroup: ScreenGroup {
    static let name = "account"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.accountScreens
    }
}

enum ForceUpdateScreenGroup: ScreenGroup {
    static let name = "force update"
    static var screens: [LaunchableScreen] {
        ScreenRegistry.forceUpdateScreens
    }
}
#endif
