//
//  SignInGateView.swift
//  PL1.4b: the sign-in screen's plain form. One Sign in with Apple button on the canvas, wired to the
//  platform's coordinator (the only way in), with the failure shown in words under it, spoken to
//  VoiceOver and felt as a haptic. PI0 (#163) replaces the look; it calls the same coordinator.
//
import AuthenticationServices
import SwiftUI

struct SignInGateView: View {
    let coordinator: Session.SignInCoordinator
    /// The server ended the session: "please sign in again" instead of the welcome.
    var endedByServer = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let failure = Self.message(coordinator.phase)
        VStack(spacing: RDimension.space6) {
            Spacer()
            Text(endedByServer ? "please sign in again." : "retrospect")
                .rText(.displayTitle)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: RDimension.space3) {
                SignInWithAppleButton(.continue, onRequest: { coordinator.prepare($0) }, onCompletion: { coordinator.finish($0) })
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    // the button is UIKit and keeps its first style: rebuild it when the scheme changes
                    .id(scheme)
                    .frame(height: RDimension.sizeControlLarge)
                    .disabled(coordinator.phase == .signingIn)
                    .accessibilityIdentifier("signin.apple")
                if let failure {
                    Text(failure)
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
            .rErrorHaptic(isFailing: failure != nil)
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, RDimension.space8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }

    /// The line under the button: the failure's words, or nothing.
    static func message(_ phase: Session.SignInCoordinator.Phase) -> String? {
        guard case let .failed(failure) = phase else { return nil }
        return failure.message ?? Session.SignInCoordinator.tryAgain
    }
}
