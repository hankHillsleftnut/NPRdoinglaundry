import AuthenticationServices
import Foundation
import Observation

extension Session {
    /// What the coordinator needs from Sign in with Apple's two callbacks (`AppleSignIn` is the real one).
    @MainActor
    protocol AppleSigningIn: AnyObject {
        func prepare(_ request: ASAuthorizationAppleIDRequest)
        func complete(_ result: Result<ASAuthorization, any Error>) async throws -> SignInOutcome
    }

    /// The one way a person signs in on the new backend (PL1.4b): Sign in with Apple through
    /// `/v2/auth/apple`, handing `Session.Manager` its credential. Nothing else installs one.
    ///
    /// A screen puts `SignInWithAppleButton(onRequest: coordinator.prepare, onCompletion: { coordinator.finish($0) })`
    /// on itself and reads `phase`. The coordinator never shows anything: a cancelled sheet is quiet
    /// (`.idle`), every other failure is `.failed` with words the screen may show as they are. On success
    /// the session publishes `.signedIn`, which is what moves the app on; `outcome` says who signed in
    /// and where they stand (waitlisted, approved) for a screen that wants to react at once.
    @MainActor @Observable
    final class SignInCoordinator {
        enum Phase: Equatable {
            case idle
            /// Apple answered; the server and the Keychain are being asked.
            case signingIn
            case failed(Flows.Failure)
        }

        private(set) var phase: Phase = .idle
        private(set) var outcome: SignInOutcome?

        @ObservationIgnored private let apple: any AppleSigningIn
        @ObservationIgnored private let log: any Platform.LogSink

        init(apple: any AppleSigningIn, log: any Platform.LogSink) {
            self.apple = apple
            self.log = log
        }

        /// The button's `onRequest`: asks for the name and email and binds a new nonce.
        func prepare(_ request: ASAuthorizationAppleIDRequest) {
            guard phase != .signingIn else { return }
            apple.prepare(request)
        }

        /// The button's `onCompletion`. Starts the sign-in; read `phase` for the result.
        func finish(_ result: Result<ASAuthorization, any Error>) {
            Task { await complete(result) }
        }

        /// The sign-in itself, awaitable (tests, and screens that want to wait).
        func complete(_ result: Result<ASAuthorization, any Error>) async {
            guard phase != .signingIn else { return }
            phase = .signingIn
            do {
                outcome = try await apple.complete(result)
                phase = .idle
            } catch {
                phase = Self.phase(after: error)
            }
        }

        /// The person saw the failure and moved on.
        func dismissFailure() {
            if case .failed = phase {
                phase = .idle
            }
        }

        /// What a failure means for the screen: a dismissed sheet is nothing; the server's own words pass
        /// through; a refused save is "unlock and try again"; everything else is a plain "try again".
        nonisolated static func phase(after error: any Error) -> Phase {
            switch error {
            case let signIn as SignInError:
                if signIn == .cancelled {
                    return .idle
                }
                return .failed(Flows.Failure(.unknown))
            case let failure as Backend.Failure:
                return .failed(failure.flowFailure)
            case is KeychainError:
                return .failed(Flows.Failure(.unknown, message: "couldn't save your sign-in on this phone. unlock it and try again."))
            default:
                return .failed(Flows.Failure(.unknown))
            }
        }
    }
}

extension Session.AppleSignIn: Session.AppleSigningIn {}
