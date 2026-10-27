import AuthenticationServices
import SwiftUI

// === AUTHENTICATION SCREEN ===
// Apple Sign-In — required step in onboarding (no skip)

struct AuthenticationScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?

    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    @State private var isSigningIn = false
    @State private var signInError: String?
    @ObservedObject private var apiClient = RetrospectAPIClient.shared

    init(currentStep: Int, totalSteps: Int, onNext: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topSection

                Spacer()

                mainContent

                Spacer()
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bodyTextAnimating = true
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        VStack(spacing: 24) {
            if onExit != nil {
                draggableBar
            }
            progressIndicator
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
    }

    // MARK: - Draggable Dismiss Bar

    private var draggableBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(LinearColors.textTertiary.opacity(0.3))
            .frame(width: 36, height: 5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onExit?()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.textTertiary.opacity(0.2))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.accent)
                    .frame(width: geometry.size.width * calculateFrontLoadedProgress(), height: 3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 40)
    }

    private func calculateFrontLoadedProgress() -> CGFloat {
        let progress = CGFloat(currentStep) / CGFloat(totalSteps)
        let frontLoaded = 1 - pow(1 - progress, 2.5)
        return min(frontLoaded, 1.0)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(LinearColors.accent)
                .padding(.bottom, 8)

            // Title
            Text("Sign In to Continue")
                .font(.custom("HedvigLettersSerif-24ptRegular", size: 32))
                .foregroundColor(LinearColors.textDisplay)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("Your account keeps your data synced and your podcasts personalized.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .offset(y: bodyTextAnimating ? 0 : 20)
                .blur(radius: bodyTextAnimating ? 0 : 8)
                .opacity(bodyTextAnimating ? 1.0 : 0.3)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)

            // Apple Sign In Button
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .cornerRadius(16)

                if isSigningIn {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.accent))
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LinearColors.textSecondary)
                    }
                    .padding(.top, 4)
                }

                if let error = signInError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            // Privacy note
            Text("We only use your Apple ID to create your account. Your data stays private.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(LinearColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Invalid credential type"
                return
            }

            let appleUserId = credential.user
            let email = credential.email
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }

            isSigningIn = true
            signInError = nil

            Task {
                do {
                    _ = try await apiClient.signIn(
                        appleUserId: appleUserId,
                        email: email,
                        identityToken: identityToken
                    )

                    await MainActor.run {
                        isSigningIn = false
                        playButtonTapHaptic()
                        onNext()
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        signInError = error.localizedDescription
                    }
                }
            }

        case let .failure(error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            signInError = error.localizedDescription
        }
    }

    // MARK: - Haptic

    private func playButtonTapHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Preview

#Preview {
    AuthenticationScreen(
        currentStep: 8,
        totalSteps: 12,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
}
