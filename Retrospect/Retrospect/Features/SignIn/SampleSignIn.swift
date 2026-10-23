//
//  SampleSignIn.swift
//  PI0 on invented data: the screen in every state, with no network and no Apple sheet. The
//  launcher plays a tap on the button as the sign-in (Apple's sheet can't run on invented data).
//  `-Screen PI0 -State splash`.
//
import AuthenticationServices
import Foundation

enum SignInScenario: String, CaseIterable, Sendable {
    case splash, signingIn, signInFailed, offline
    case returning, restoring, restoreFailed

    var look: SignInModel.Look {
        switch self {
        case .splash, .signingIn, .signInFailed, .offline: .splash
        case .returning, .restoring, .restoreFailed: .returning
        }
    }

    var phase: SignInModel.Phase {
        switch self {
        case .signingIn, .restoring: .signingIn
        case .signInFailed, .restoreFailed: .failed
        case .splash, .offline, .returning: .rest
        }
    }
}

@MainActor
final class SampleSignIn: SignInCoordinating {
    private let result: SignInResult
    private let sleep: @Sendable (Duration) async -> Void

    init(
        result: SignInResult = .signedIn(firstName: "sam", access: .waitlisted),
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.result = result
        self.sleep = sleep
    }

    func prepare(_: ASAuthorizationAppleIDRequest) {}

    func complete(_: Result<ASAuthorization, any Error>) async -> SignInResult {
        await sleep(.milliseconds(800))
        return result
    }
}

extension SignInModel {
    static func sample(_ scenario: SignInScenario) -> SignInModel {
        SignInModel(look: scenario.look, coordinator: SampleSignIn(), phase: scenario.phase, isOnline: scenario != .offline)
    }
}
