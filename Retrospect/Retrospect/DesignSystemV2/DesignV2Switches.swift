//
//  DesignV2Switches.swift
//  M14 F10: one switch per screen, so new screens ship behind a flag and a flow
//  goes live only after its ship gate (docs/design/swift-implementation-plan.md §5).
//
//  Default: on in Debug and TestFlight, off in the App Store build. A screen moves
//  to `liveForEveryone` when its flow passes its ship gate; its old screen is then
//  deleted and its switch removed.
//
import Foundation

enum DesignV2Screen: String, CaseIterable {
    // first run
    case splashSignIn = "ON-1/2", questions = "ON-3–9", privacy = "ON-5", connect = "ON-6"
    case gettingReady = "ON-10", tease = "ON-11", paywall = "ON-12", firstHome = "ON-13"
    // daily loop
    case journal = "JR-1", todaysBrief = "JR-2", allEntries = "JR-3", oneEntry = "JR-4"
    // podcasts
    case podcasts = "PC-1", player = "PC-2", whyThisIsHere = "PC-3"
    // goals
    case goals = "GL-1", oneGoal = "GL-2"
    // you
    case you = "YO-1", search = "YO-2", aSource = "YO-3", aNode = "YO-4", whatIKnow = "YO-5"
    // settings and account
    case settings = "ST-1", dailyBrief = "ST-2", sources = "ST-3", aSourceSettings = "ST-4"
    case privacySettings = "ST-5", howStraight = "ST-6", voice = "ST-7", whatIveLearned = "ST-8"
    case account = "ST-9", signInReturning = "AC-1", signingOut = "AC-2"
    // outside the app
    case share = "EX-1", lockScreen = "EX-2", notifications = "EX-3", widgets = "EX-4"
}

enum DesignV2 {
    /// Screens whose flow has passed its ship gate: on for everyone, App Store included.
    static let liveForEveryone: Set<DesignV2Screen> = []

    /// Is the new design on for this screen in this build?
    static func isOn(_ screen: DesignV2Screen) -> Bool {
        if liveForEveryone.contains(screen) { return true }
        if let forced = override(for: screen) { return forced }
        return isDebugOrTestFlight
    }

    /// Debug override: launch with `-DesignV2Off` (every screen old) or set
    /// `designV2.<code>` in UserDefaults to true/false for one screen.
    private static func override(for screen: DesignV2Screen) -> Bool? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DesignV2Off") { return false }
        if let value = UserDefaults.standard.object(forKey: "designV2.\(screen.rawValue)") as? Bool { return value }
        #endif
        return nil
    }

    private static var isDebugOrTestFlight: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
