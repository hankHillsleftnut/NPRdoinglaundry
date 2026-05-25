//
//  WelcomeSignInPage.swift
//  Retrospect
//
//  Full-page welcome screen with Retrospect branding and Sign in with Apple.
//  Uses a continuation-based ASAuthorizationController coordinator so the
//  async result is delivered directly back into the calling Task — no stored
//  closures that can go stale when SwiftUI recreates the view struct.
//

import SwiftUI
import AuthenticationServices

// MARK: - Coordinator (lives as @StateObject, outlives view rebuilds)

private final class AppleSignInCoordinator: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var activeController: ASAuthorizationController?
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    /// Presents the system Apple Sign-in sheet and suspends until it completes.
    func signIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.activeController = controller
            controller.performRequests()
        }
    }

    // MARK: Delegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        activeController = nil
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        activeController = nil
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: Presentation context

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Welcome page

struct WelcomeSignInPage: View {
    @ObservedObject var state: OnboardingState

    @StateObject private var coordinator = AppleSignInCoordinator()
    @State private var signInError: String?
    @State private var isAwaitingApple = false

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var titleOpacity: Double = 0
    @State private var descriptionOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        OnboardingScaffold(
            title: "Retrospect",
            subtitle: "Your life, turned into a weekly podcast. Journal entries, voice notes, health data, and the thoughts you almost forgot become something you can actually hear.",
            topSpacing: 116
        ) {
            Image("retrospect-loading-mark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 82, height: 62)
                .opacity(0.26)
                .padding(.top, 12)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
        } bottom: {
            OnboardingPrimaryButton(
                title: state.signInInProgress || isAwaitingApple ? "Authenticating..." : "Sign in with Apple",
                systemImage: "apple.logo",
                isLoading: state.signInInProgress || isAwaitingApple,
                isDisabled: state.signInInProgress || isAwaitingApple,
                action: triggerSignIn
            )
            .opacity(buttonOpacity)

            if let error = signInError {
                Text(error)
                    .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
                    .foregroundColor(OnboardingStyle.danger)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Text("Sign in creates your private Retrospect account. You choose what to connect next.")
                .font(OnboardingStyle.bodyFont(size: 12))
                .foregroundColor(OnboardingStyle.tertiaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(buttonOpacity)
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Entrance animation

    private func animateIn() {
        guard !state.welcomeAnimationPlayed else {
            logoOpacity = 1; logoScale = 1.0
            titleOpacity = 1; descriptionOpacity = 1; buttonOpacity = 1
            return
        }
        state.welcomeAnimationPlayed = true

        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
            logoOpacity = 1
            logoScale = 1.0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35)) {
            titleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            descriptionOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.85)) {
            buttonOpacity = 1
        }
    }

    // MARK: - Apple Sign-in

    private func triggerSignIn() {
        guard !state.signInInProgress, !isAwaitingApple else { return }
        signInError = nil

        Task { @MainActor in
            isAwaitingApple = true
            defer { isAwaitingApple = false }

            let authorization: ASAuthorization
            do {
                authorization = try await coordinator.signIn()
            } catch {
                let nsError = error as NSError
                if nsError.domain == ASAuthorizationError.errorDomain,
                   nsError.code == ASAuthorizationError.canceled.rawValue {
                    return
                }
                signInError = error.localizedDescription
                return
            }

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Invalid credential type"
                return
            }

            let appleUserId = credential.user
            let email = credential.email
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }

            state.signInInProgress = true
            signInError = nil

            do {
                _ = try await RetrospectAPIClient.shared.signIn(
                    appleUserId: appleUserId,
                    email: email,
                    identityToken: identityToken
                )
                state.signInInProgress = false
                HapticManager.shared.playSuccessNotification()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    state.markSignedIn()
                }
            } catch {
                state.signInInProgress = false
                signInError = error.localizedDescription
            }
        }
    }
}
