import Foundation
import AuthenticationServices
import AppKit

/// Sign in with Apple for macOS, reusing the same backend account as the iOS app.
///
/// SIWA requires the `com.apple.developer.applesignin` entitlement + an App ID with the
/// capability enabled (see RetrospectMac.entitlements.template). Until that's provisioned,
/// `signInWithDevAppleId` lets you exercise sync against the backend with a known id.
@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var lastError: String?
    @Published var isWorking = false

    private let api = RetrospectAPI.shared

    // MARK: Sign in with Apple

    func signInWithApple() {
        isWorking = true
        lastError = nil
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// Dev path: sign in to the backend with a raw Apple user id (no SIWA capability needed).
    func signInWithDevAppleId(_ appleUserId: String, email: String?) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            _ = try await api.signIn(appleUserId: appleUserId, email: email, identityToken: nil)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() { api.signOut() }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            isWorking = false
            lastError = "Unexpected credential type"
            return
        }
        let appleUserId = credential.user
        let email = credential.email
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            defer { isWorking = false }
            do {
                _ = try await api.signIn(appleUserId: appleUserId, email: email, identityToken: identityToken)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isWorking = false
        // User cancelling is not an error worth surfacing loudly.
        if (error as? ASAuthorizationError)?.code == .canceled { return }
        lastError = error.localizedDescription
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
