//
//  ScreenLauncher+Root.swift
//  T02: how the app root decides to show the launcher. `-Screen <id>` on the command line (any
//  id, even one nothing handles) puts the launcher at the root, so a wrong id shows the list of
//  valid screens instead of the normal app. Debug builds only: a release build has no launcher and
//  `Platform.LaunchOptions` already ignores the flags there.
//
#if DEBUG
import SwiftUI

extension ScreenLauncher {
    /// True when this launch asked for a screen by `-Screen`.
    static func isRequested(_ options: Platform.LaunchOptions = .current) -> Bool {
        options.screen != nil
    }
}
#endif
