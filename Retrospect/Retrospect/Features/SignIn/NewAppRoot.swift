//
//  NewAppRoot.swift
//  PL1.4b / PL5.2: the app's root on the new backend. What shows comes from the new session's state
//  and nothing else: a blank page while it is still being read (or the phone is locked), the sign-in
//  screen when nobody is signed in, the app when someone is (a plain canvas until APP-ROOT mounts the
//  journal behind it).
//
import SwiftUI

struct NewAppRoot: View {
    /// What the root shows for a session state.
    enum Screen: Equatable {
        /// Still being read, or the phone is locked: nothing to show yet.
        case blank
        /// Nobody is signed in; `endedByServer` says "please sign in again".
        case signIn(endedByServer: Bool)
        case app
    }

    static func screen(for state: Session.State?) -> Screen {
        switch state {
        case .signedIn: .app
        case let .signedOut(_, reason): .signIn(endedByServer: reason == .revoked)
        case .locked, nil: .blank
        }
    }

    @Environment(Platform.AppEnvironment.self) private var platform

    var body: some View {
        Group {
            switch Self.screen(for: platform.sessionState) {
            case .app:
                // the app behind the sign-in is mounted by APP-ROOT; until then a plain canvas
                RColor.backgroundCanvas.ignoresSafeArea().accessibilityIdentifier("newapp.signedin")
            case let .signIn(endedByServer):
                SignInGateView(endedByServer: endedByServer)
            case .blank:
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .animation(RMotion.snappy, value: platform.sessionState)
    }
}
