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
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    SquircleLogo(size: 120, shadowEnabled: true)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)

                    Text("Retrospect")
                        .font(.custom("EBGaramond12-Italic", size: 48))
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))
                        .opacity(titleOpacity)

                    Text("Your life, turned into a weekly podcast.\nJournal entries, voice notes, health data —\nRetrospect weaves it all together\nso nothing gets lost.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(descriptionOpacity)
                }

                Spacer()
                Spacer()

                VStack(spacing: 16) {
                    Button {
                        triggerSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .medium))
                            Text("Sign in with Apple")
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.white)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 40)
                    .opacity(buttonOpacity)
                    .allowsHitTesting(!state.signInInProgress && !isAwaitingApple)

                    if state.signInInProgress || isAwaitingApple {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                                .scaleEffect(0.8)
                            Text(state.signInInProgress ? "Connecting..." : "Authenticating...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                    }

                    if let error = signInError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Text("Your data stays on your device. Private and encrypted.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(buttonOpacity)
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
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
