//
//  SignInCoordinating.swift
//  PI0: what the sign-in screen needs from the app, as one seam. Lane A's sign-in coordinator
//  (PL1.4b: it runs Sign in with Apple and calls `Session.appleSignIn`, the only thing that gives
//  `Session.Manager` a credential) will conform; until it lands the screen runs on
//  `SampleSignIn` through the launcher. The screen never touches the network, a token or the old
//  client: new backend only.
//
import AuthenticationServices
import Foundation

/// What Sign in with Apple came to, as the screen needs it. No token ever reaches the screen.
enum SignInResult: Equatable {
    /// The session is installed. The access state says where the person goes next.
    case signedIn(firstName: String?, access: Session.AccessState)
    /// The person dismissed Apple's sheet: nothing changes, nothing is shown.
    case cancelled
    /// Anything else, offline included: the words say nothing was lost.
    case failed
}

@MainActor
protocol SignInCoordinating: AnyObject {
    /// Before Apple's sheet: the request gets its scopes and a new nonce.
    func prepare(_ request: ASAuthorizationAppleIDRequest)
    /// After Apple's sheet: the credential goes to the server and the answer is installed.
    func complete(_ result: Result<ASAuthorization, any Error>) async -> SignInResult
}
