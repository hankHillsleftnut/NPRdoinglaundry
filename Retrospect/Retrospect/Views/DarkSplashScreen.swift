//
//  DarkSplashScreen.swift
//  Retrospect
//
//  Default in-app splash screen with Face ID authentication.
//

import LocalAuthentication
import SwiftUI
import UIKit

struct DarkSplashScreen: View {
    @Binding var isAuthenticated: Bool
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true

    @State private var authenticationError: String?
    @State private var showRetryButton = false
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            RetrospectLoadingScreen()
                .opacity(contentOpacity)

            if showRetryButton {
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        if let authenticationError {
                            Text(authenticationError)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.42))
                                .multilineTextAlignment(.center)
                        }

                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            authenticate()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Try Again")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(Color.black.opacity(0.58))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.52))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 58)
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            animateIn()
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.2)) {
            contentOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            authenticate()
        }
    }

    private func authenticate() {
        authenticationError = nil
        showRetryButton = false

        guard faceIDEnabled else {
            HapticManager.shared.playSuccessNotification()
            finishAuthentication(success: true)
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            HapticManager.shared.playSuccessNotification()
            finishAuthentication(success: true)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access your reflections") { success, _ in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.playSuccessNotification()
                    finishAuthentication(success: true)
                } else {
                    HapticManager.shared.playErrorNotification()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        authenticationError = "Authentication failed"
                        showRetryButton = true
                    }
                }
            }
        }
    }

    private func finishAuthentication(success: Bool) {
        guard success else { return }

        HeadlineAnimationTracker.shared.hasPlayedThisSession = false

        withAnimation(.easeInOut(duration: 0.2)) {
            contentOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            isAuthenticated = true
        }
    }
}

#Preview {
    DarkSplashScreen(isAuthenticated: .constant(false))
}
