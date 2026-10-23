//
//  SignInGateView.swift
//  PL1.4b: the sign-in screen's plain form. One Sign in with Apple button on the canvas, wired to
//  `Platform.AppEnvironment.signIn` (the only way in), with the failure shown in words under it. The
//  invite screens (PI0) replace the look; they call the same coordinator.
//
import AuthenticationServices
import SwiftUI

struct SignInGateView: View {
    /// The server ended the session: "please sign in again" instead of the welcome.
    var endedByServer = false
    @Environment(Platform.AppEnvironment.self) private var platform
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let coordinator = platform.signIn
        VStack(spacing: RDimension.space6) {
            Spacer()
            Text(endedByServer ? "please sign in again." : "retrospect")
                .rText(.displayTitle)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: RDimension.space3) {
                SignInWithAppleButton(.continue, onRequest: { coordinator.prepare($0) }, onCompletion: { coordinator.finish($0) })
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black) // literal-ok: Apple's own button styles
                    .frame(height: RDimension.sizeControlLarge)
                    .disabled(coordinator.phase == .signingIn)
                    .accessibilityIdentifier("signin.apple")
                if case let .failed(failure) = coordinator.phase {
                    Text(failure.message ?? "couldn't sign you in. try again.")
                        .rText(.bodyReading)
                        .foregroundStyle(RColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("signin.error")
                }
            }
            .onChange(of: coordinator.phase) {
                // a failure is spoken as well as shown
                if let line = Self.message(coordinator.phase) {
                    AccessibilityNotification.Announcement(line).post()
                }
            }
            .rErrorHaptic(isFailing: Self.message(coordinator.phase) != nil)
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, RDimension.space8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }

    private static func message(_ phase: Session.SignInCoordinator.Phase) -> String? {
        guard case let .failed(failure) = phase else { return nil }
        return failure.message ?? "couldn't sign you in. try again."
    }
}
