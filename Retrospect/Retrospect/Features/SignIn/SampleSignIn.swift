//
//  SampleSignIn.swift
//  PI0 on invented data: the screen in every state, with no network and no Apple sheet. The
//  launcher plays a tap on the button as the sign-in (Apple's sheet can't run on invented data).
//  `-Screen PI0 -State splash`. From rest the first tap fails and the next one signs in, so the
//  whole sequence (tap, signing in, failed, try again, signed in) can be filmed; `offline` comes
//  back online after a few seconds.
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

    /// What the sample answers, tap by tap (the last answer repeats): a page at rest fails once
    /// first, so trying again is reachable; a page already failed signs in on the next try.
    var script: [SignInResult] {
        let arrived = SignInResult.signedIn(firstName: "sam", access: .waitlisted)
        return phase == .rest ? [.failed, arrived] : [arrived]
    }
}

@MainActor
final class SampleSignIn: SignInCoordinating {
    private var script: [SignInResult]
    private let sleep: @Sendable (Duration) async -> Void

    init(
        script: [SignInResult] = [.signedIn(firstName: "sam", access: .waitlisted)],
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.script = script
        self.sleep = sleep
    }

    func prepare(_: ASAuthorizationAppleIDRequest) {}

    func complete(_: Result<ASAuthorization, any Error>) async -> SignInResult {
        await sleep(.milliseconds(800))
        return script.count > 1 ? script.removeFirst() : script.first ?? .failed
    }
}

extension SignInModel {
    static func sample(_ scenario: SignInScenario) -> SignInModel {
        SignInModel(look: scenario.look, coordinator: SampleSignIn(script: scenario.script), phase: scenario.phase, isOnline: scenario != .offline)
    }
}
