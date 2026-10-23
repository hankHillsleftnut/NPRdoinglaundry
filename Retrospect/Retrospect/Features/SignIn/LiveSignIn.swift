//
//  LiveSignIn.swift
//  APP-ROOT: the sign-in screens' seam (`SignInCoordinating`) on the real thing: the platform's Sign in
//  with Apple coordinator (`/v2/auth/apple`), the only way a person gets a session. It answers the screens
//  in their words and never lets a token, a nonce or Apple's credential through.
//
import AuthenticationServices
import Foundation

@MainActor
final class LiveSignIn: SignInCoordinating {
    private let coordinator: Session.SignInCoordinator

    init(_ coordinator: Session.SignInCoordinator) {
        self.coordinator = coordinator
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        coordinator.prepare(request)
    }

    func complete(_ result: Result<ASAuthorization, any Error>) async -> SignInResult {
        await Self.result(of: coordinator.complete(result))
    }

    /// A dismissed sheet and a second tap while one sign-in runs both show nothing; every real failure is `failed`.
    static func result(of completion: Session.SignInCoordinator.Completion) -> SignInResult {
        switch completion {
        case let .signedIn(outcome): .signedIn(firstName: outcome.firstName, access: outcome.access)
        case .cancelled, .alreadyRunning: .cancelled
        case .failed: .failed
        }
    }
}
