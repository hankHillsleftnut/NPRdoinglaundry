//
//  NewAppRoot.swift
//  PL1.4b: the app's root on the new backend, chosen from the new session's state and nothing else
//  (never the old client's `isAuthenticated` or the old onboarding flags). A plain canvas while the
//  session is still being read or the phone is locked, the sign-in gate when nobody is signed in,
//  and a placeholder when someone is. Debug builds show it with `-NewApp`; APP-ROOT puts the journal
//  in the signed-in slot and makes it the release root.
//
import SwiftUI

struct NewAppRoot: View {
    /// What the root shows for one session state.
    enum Screen: Equatable {
        /// Not read yet, or the phone is locked: nothing is wiped and nothing reads as signed out.
        case canvas
        /// Nobody is signed in. `endedByServer` when the server ended the session ("please sign in again").
        case gate(endedByServer: Bool)
        case signedIn
    }

    @Environment(Platform.AppEnvironment.self) private var platform

    static func screen(for state: Session.State?) -> Screen {
        switch state {
        case .signedIn:
            .signedIn
        case let .signedOut(_, reason):
            .gate(endedByServer: reason == .revoked)
        case .locked, nil:
            .canvas
        }
    }

    var body: some View {
        let screen = Self.screen(for: platform.sessionState)
        Group {
            switch screen {
            case .canvas:
                RColor.backgroundCanvas.ignoresSafeArea()
            case let .gate(endedByServer):
                SignInGateView(coordinator: platform.signIn, endedByServer: endedByServer)
            case .signedIn:
                SignedInPlaceholder()
            }
        }
        .animation(RMotion.snappy, value: screen)
    }
}

/// The signed-in slot until APP-ROOT mounts the journal there: proof that the session holds a credential.
private struct SignedInPlaceholder: View {
    var body: some View {
        Text("you're signed in.")
            .rText(.bodyReading)
            .foregroundStyle(RColor.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RColor.backgroundCanvas.ignoresSafeArea())
            .accessibilityIdentifier("root.signedIn")
    }
}
