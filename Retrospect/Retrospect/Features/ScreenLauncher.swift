//
//  ScreenLauncher.swift
//  T02: `-Screen <id> [-State <name>]` opens one screen on sample data for stills, recordings and
//  UI tests. The app root asks `ScreenLauncher.view(for:)`; each feature adds its screen as one
//  entry in `entries`, in id order. Debug builds only: a release build has no launcher and
//  `Platform.LaunchOptions.current` already ignores the flags there.
//
#if DEBUG
import SwiftUI

enum ScreenLauncher {
    struct Entry {
        let ids: Set<String>
        let make: @MainActor (Platform.LaunchOptions) -> AnyView
    }

    /// Every launchable screen. Add an entry in id order.
    @MainActor static let entries: [Entry] = []

    /// The screen this launch asked for, nil when it asked for none or an id nothing handles.
    @MainActor
    static func view(for options: Platform.LaunchOptions = .current) -> AnyView? {
        guard let id = options.screen else { return nil }
        return entries.first { $0.ids.contains(id) }?.make(options)
    }
}
#endif
