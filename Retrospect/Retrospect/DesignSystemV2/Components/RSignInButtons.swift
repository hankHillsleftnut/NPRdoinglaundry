//
//  RSignInButtons.swift
//  C43: one calm way in, the same on every screen that asks you to sign in. The button is Apple's
//  own `SignInWithAppleButton` (so Apple's sheet and style are used, as Apple requires), black in
//  light and white in dark, 60 high, a pill, with Paper's soft shadow under it (T1 `2I01-0`).
//  "Continue with Google" (ON-1/2 `1F54-0`) sits 12 under it only when its host hands it an action:
//  the sample flow does (decision 12); no real Google sign-in exists yet (BE2.4), so a live screen
//  passes none and the button is not there at all. It never talks to the network: its callbacks
//  go to whoever hosts it.
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
    /// "Continue with Google". Nil (every live screen today): the button doesn't exist.
    var onGoogle: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    private var isRest: Bool {
        state == .rest
    }

    var body: some View {
        VStack(spacing: RDimension.space2) {
            VStack(spacing: RDimension.space3) {
                SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black) // literal-ok: Apple's own button styles
                    .id(scheme) // the system button is UIKit: a new look needs a new button
                    .frame(height: RDimension.sizeControlHero)
                    .frame(maxWidth: .infinity)
                    .clipShape(RShape.pill)
                    // Paper: contact 0 1 2, cast 0 8 16 −8 (the −8 spread is carried by the smaller radius)
                    .shadow(color: RColor.depthShadowContact, radius: 1, y: 1) // literal-ok: Paper T1 contact 0 1 2
                    .shadow(color: RColor.depthShadowCast, radius: 6, y: 8) // literal-ok: Paper T1 cast 0 8 16 -8
                if let onGoogle {
                    RGoogleButton(action: onGoogle)
                }
            }
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

/// "Continue with Google" as Paper draws it (ON-1/2 `1F54-0`): 60 high, a pill, `signInGoogleFill`
/// (white; `#131314` in dark) with Google's four-colour G at 18 and the label 12 after it, text-body
/// medium in `signInGoogleLabel`; raised without a dark border (inner-top 1, outer 0.5, contact
/// 0 1 1.5, cast 0 6 14 −6). The G is Google's brand mark, kept in its own colours.
struct RGoogleButton: View {
    let action: () -> Void

    /// The G, as Paper sizes it (`1F56-0`); it doesn't grow with type, like Apple's glyph.
    private static let mark: CGFloat = 18 // literal-ok: Paper 1F56-0

    var body: some View {
        Button(action: action) {
            HStack(spacing: RDimension.space3) {
                Image("google-g")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.mark, height: Self.mark)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .rText(.bodyMedium)
                    .foregroundStyle(RColor.signInGoogleLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // literal-ok: AX sizes keep the label on the 60 pill
            }
            .padding(.horizontal, RDimension.space4)
            .frame(maxWidth: .infinity, minHeight: RDimension.sizeControlHero)
            .background(RColor.signInGoogleFill, in: RShape.pill)
            .overlay(alignment: .top) {
                RShape.pill.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .overlay(RShape.pill.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1) // literal-ok: Paper 1F54-0 contact 0 1 1.5
            .shadow(color: RColor.depthShadowCast, radius: 4, y: 6) // literal-ok: Paper 1F54-0 cast 0 6 14 -6
            .contentShape(RShape.pill)
        }
        .rPress()
        .accessibilityIdentifier("signin.google")
    }
}
