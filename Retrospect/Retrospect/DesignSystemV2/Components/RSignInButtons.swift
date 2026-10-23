//
//  RSignInButtons.swift
//  C43: one calm way in, the same on every screen that asks you to sign in. Beta 1 is Apple only
//  (Google waits for BE2.4), so the legal line moves up and leaves no gap. The button is Apple's
//  own `SignInWithAppleButton` (so Apple's sheet and style are used, as Apple requires), black in
//  light and white in dark, 60 high, a pill, with Paper's soft shadow under it (T1 `2I01-0`). It
//  never talks to the network: its two callbacks go to whoever hosts it.
//
import AuthenticationServices
import SwiftUI

struct RSignInButtons: View {
    enum State: Equatable {
        case rest
        /// Sign-in is under way: the button rests disabled at `opacity.disabled` (Paper AC-1
        /// restoring) so it plainly can't be pressed twice; the wait is said under the title.
        case pending
        /// Can't be used now; the reason shows under it ("connect to sign in").
        case disabled(reason: String)
    }

    var state: State = .rest
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, any Error>) -> Void
    @Environment(\.colorScheme) private var scheme

    private var isRest: Bool {
        state == .rest
    }

    var body: some View {
        VStack(spacing: RDimension.space2) {
            SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black) // literal-ok: Apple's own button styles
                .id(scheme) // the system button is UIKit: a new look needs a new button
                .frame(height: RDimension.sizeControlHero)
                .frame(maxWidth: .infinity)
                .clipShape(RShape.pill)
                // Paper: contact 0 1 2, cast 0 8 16 −8 (the −8 spread is carried by the smaller radius)
                .shadow(color: RColor.depthShadowContact, radius: 1, y: 1) // literal-ok: Paper T1 contact 0 1 2
                .shadow(color: RColor.depthShadowCast, radius: 6, y: 8) // literal-ok: Paper T1 cast 0 8 16 -8
                .opacity(opacity)
                .disabled(!isRest)
            if case let .disabled(reason) = state {
                HStack(spacing: RDimension.space1) {
                    RSymbol(name: "wifi.slash", size: .small, tint: RColor.textLabel)
                    Text(reason).rText(.metaLine).foregroundStyle(RColor.textLabel)
                }
                .rBlurReplace()
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationFast), value: state)
    }

    /// Anything but rest is disabled, and looks it: Paper dims the restoring buttons to
    /// `opacity.disabled`, not the lighter `opacity.pending`, which left the black pill looking live.
    static func opacity(_ state: State) -> Double {
        state == .rest ? 1 : RNumber.opacityDisabled
    }

    private var opacity: Double {
        Self.opacity(state)
    }
}
