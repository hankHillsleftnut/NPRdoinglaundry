import SwiftUI
import AuthenticationServices

// MARK: - Backend Auth Gate
// Shown when the user completed onboarding but has no valid backend JWT.
// Uses the SAME design as the onboarding `WelcomeSignInPage` so the "true" sign-in matches it,
// just wired to `onAuthenticated` instead of advancing the onboarding flow.

struct BackendAuthGateView: View {
    let onAuthenticated: () -> Void

    @StateObject private var coordinator = AppleSignInCoordinator()
    @State private var isSigningIn = false
    @State private var signInError: String?
    #if DEBUG
    @State private var isSigningInDevUser = false
    #endif

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var buttonOpacity: Double = 0

    var body: some View {
        OnboardingScaffold(
            title: "Retrospect",
            subtitle: "Your life, turned into a weekly podcast. Journal entries, voice notes, health data, and the thoughts you almost forgot become something you can actually hear.",
            topSpacing: 116,
            header: {
                Image("retrospect-loading-mark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 82, height: 62)
                    .opacity(0.26)
                    .padding(.bottom, 16)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
            }
        ) {
            EmptyView()
        } bottom: {
            OnboardingPrimaryButton(
                title: isSigningIn ? "Authenticating..." : "Sign in with Apple",
                systemImage: "apple.logo",
                isLoading: isSigningIn,
                isDisabled: isSigningIn,
                action: triggerSignIn
            )
            .opacity(buttonOpacity)

            #if DEBUG
            Button(isSigningInDevUser ? "DEV: Creating test account..." : "DEV: Sign in as new test user") {
                triggerDevTestUserSignIn()
            }
            .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
            .foregroundColor(OnboardingStyle.tertiaryText)
            .buttonStyle(.plain)
            .disabled(isSigningInDevUser)
            .opacity(buttonOpacity)
            #endif

            if let error = signInError {
                Text(error)
                    .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
                    .foregroundColor(OnboardingStyle.danger)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                logoOpacity = 1
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                buttonOpacity = 1
            }
        }
    }

    // MARK: - Apple Sign-in (same coordinator-based flow as WelcomeSignInPage)
    private func triggerSignIn() {
        guard !isSigningIn else { return }
        signInError = nil

        Task { @MainActor in
            isSigningIn = true

            let authorization: ASAuthorization
            do {
                authorization = try await coordinator.signIn()
            } catch {
                isSigningIn = false
                let nsError = error as NSError
                if nsError.domain == ASAuthorizationError.errorDomain,
                   nsError.code == ASAuthorizationError.canceled.rawValue {
                    return
                }
                signInError = error.localizedDescription
                return
            }

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                isSigningIn = false
                signInError = "Invalid credential type"
                return
            }

            do {
                _ = try await RetrospectAPIClient.shared.signIn(
                    appleUserId: credential.user,
                    email: credential.email,
                    identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                )
                isSigningIn = false
                HapticManager.shared.playSuccessNotification()
                onAuthenticated()
            } catch {
                isSigningIn = false
                signInError = error.localizedDescription
            }
        }
    }

    #if DEBUG
    /// Signs in as a brand new throwaway account holding a real JWT. Needs an API
    /// running with NODE_ENV != production, where the endpoint exists.
    private func triggerDevTestUserSignIn() {
        guard !isSigningIn, !isSigningInDevUser else { return }
        signInError = nil

        Task { @MainActor in
            isSigningInDevUser = true
            defer { isSigningInDevUser = false }

            do {
                _ = try await RetrospectAPIClient.shared.signInAsDevTestUser()
            } catch {
                signInError = "\(error.localizedDescription)\n\nThe dev test user needs an API running with NODE_ENV != production."
                return
            }

            // The account just signed out of is gone; without this the throwaway
            // user's first sync would resend the previous account's goals/answers.
            OnboardingContextManager.shared.resetForFreshOnboarding()
            HapticManager.shared.playSuccessNotification()
            onAuthenticated()
        }
    }
    #endif
}

#Preview {
    BackendAuthGateView(onAuthenticated: {
        print("Authenticated!")
    })
}
