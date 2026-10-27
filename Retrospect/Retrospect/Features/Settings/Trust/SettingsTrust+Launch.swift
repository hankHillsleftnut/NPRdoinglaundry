//
//  SettingsTrust+Launch.swift
//  V2.settings, second half, debug builds only (founder's sandbox rule: no test or state affordance in
//  release): the launcher can open ST-5 / ST-9 with their danger dialog already up, for stills
//  (`-State delete`). The request is spent the first time the page appears, so a later push doesn't
//  open it again.
//
#if DEBUG
import SwiftUI

/// The launcher asks for the page's danger dialog, once.
@MainActor
final class SettingsLaunchDialog {
    var pending: Bool

    init(_ pending: Bool) {
        self.pending = pending
    }
}

extension EnvironmentValues {
    /// Set only by the trust launcher (`-Screen ST-5|ST-9 -State delete`).
    @Entry var settingsLaunchDialog: SettingsLaunchDialog?
}

/// Opens the dialog when the page first appears if the launcher asked, then forgets the request.
struct SettingsLaunchDialogOpen: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.settingsLaunchDialog) private var request

    func body(content: Content) -> some View {
        content.onAppear {
            guard request?.pending == true else { return }
            isPresented = true
            request?.pending = false
        }
    }
}
#endif
