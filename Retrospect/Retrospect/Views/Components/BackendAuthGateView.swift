import SwiftUI
import AuthenticationServices

// MARK: - Backend Auth Gate
// Shown when user completed onboarding but has no valid backend JWT.
// This is a full-screen sign-in requirement — no way to skip.

struct BackendAuthGateView: View {
    let onAuthenticated: () -> Void
    
    @State private var isSigningIn = false
    @State private var signInError: String?
    @ObservedObject private var apiClient = RetrospectAPIClient.shared
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(LinearColors.accent)
                
                // Title
                Text("Sign In Required")
                    .font(.custom("HedvigLettersSerif-24ptRegular", size: 30))
                    .foregroundColor(LinearColors.textDisplay)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Please sign in with Apple to access your data and podcasts.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
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
                    .padding(.horizontal, 40)
                    
                    if isSigningIn {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.accent))
                                .scaleEffect(0.8)
                            Text("Connecting...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(LinearColors.textSecondary)
                        }
                    }
                    
                    if let error = signInError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Privacy footnote
                Text("Your data stays private. We only use your Apple ID to verify your account.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(LinearColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
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
                    let _ = try await apiClient.signIn(
                        appleUserId: appleUserId,
                        email: email,
                        identityToken: identityToken
                    )
                    
                    await MainActor.run {
                        isSigningIn = false
                        onAuthenticated()
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        signInError = error.localizedDescription
                    }
                }
            }
            
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            signInError = error.localizedDescription
        }
    }
}

#Preview {
    BackendAuthGateView(onAuthenticated: {
        print("Authenticated!")
    })
}
