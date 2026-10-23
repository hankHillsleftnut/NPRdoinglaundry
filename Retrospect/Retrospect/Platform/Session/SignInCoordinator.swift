import AuthenticationServices
import Foundation
import Observation

extension Session {
    /// What the coordinator needs from Sign in with Apple's two callbacks. `AppleSignIn` is the real one;
    /// tests put a double here so no real Apple sheet is needed.
    @MainActor
    protocol AppleSigningIn: AnyObject {
        func prepare(_ request: ASAuthorizationAppleIDRequest)
        func complete(_ result: Result<ASAuthorization, any Error>) async throws -> SignInOutcome
    }

    /// The one way a person signs in on the new backend (PL1.4b): Sign in with Apple through
    /// `POST /v2/auth/apple`, handing `Session.Manager` its credential. Nothing else in the app installs one.
    ///
    /// A screen puts `SignInWithAppleButton(onRequest: coordinator.prepare, onCompletion: coordinator.finish)`
    /// on itself and reads `phase`, or awaits `complete(_:)` for a `Completion`. The coordinator never shows
    /// anything: a dismissed sheet is quiet (`.idle`), every other failure is `.failed` with words the screen
    /// may show as they are. On success the session publishes `.signedIn`, and that is what moves the app on;
    /// `outcome` says who signed in and where they stand (waitlisted, member) for a screen that reacts at once.
    ///
    /// One sign-in at a time: a second callback while one runs joins it (the same answer, no second request),
    /// and a `prepare` while one runs is ignored, so the pending nonce is never replaced. The sign-in runs in a
    /// task of its own: if the screen that started it goes away, it still finishes (Apple's code is single
    /// use, so dropping it halfway would waste the person's tap) and `phase` still ends terminal.
    @MainActor @Observable
    final class SignInCoordinator {
        enum Phase: Equatable {
            case idle
            /// Apple answered; the server and the Keychain are being asked.
            case signingIn
            case failed(Flows.Failure)
        }

        /// How one sign-in ended, for a screen that awaits it. Never carries a token, a nonce or Apple's code.
        enum Completion: Equatable {
            case signedIn(SignInOutcome)
            /// The person dismissed Apple's sheet: nothing changes, nothing is shown.
            case cancelled
            case failed(Flows.Failure)
        }

        /// What a failure says when the server didn't send words of its own (contract 00 §2's line).
        static let tryAgain = "that didn't work. nothing is lost; try again."
        static let offline = "you're offline. connect and try again."
        static let unlock = "couldn't save your sign-in on this phone. unlock it and try again."

        private(set) var phase: Phase = .idle
        /// The last successful sign-in's who and where; cleared when a new sign-in starts.
        private(set) var outcome: SignInOutcome?

        @ObservationIgnored private let apple: any AppleSigningIn
        @ObservationIgnored private var running: Task<Completion, Never>?

        init(apple: any AppleSigningIn) {
            self.apple = apple
        }

        /// The button's `onRequest`: asks for the name and email and binds a new nonce. Ignored while a
        /// sign-in runs, so its nonce stays the one Apple's credential is checked against.
        func prepare(_ request: ASAuthorizationAppleIDRequest) {
            guard running == nil else { return }
            apple.prepare(request)
        }

        /// The button's `onCompletion`. Starts the sign-in; read `phase` for the result.
        func finish(_ result: Result<ASAuthorization, any Error>) {
            Task { await complete(result) }
        }

        /// The sign-in itself, awaitable. `phase` is `.signingIn` before this first suspends (so a second tap
        /// sees it) and terminal before it returns, whatever happens to the caller's task.
        @discardableResult
        func complete(_ result: Result<ASAuthorization, any Error>) async -> Completion {
            if let running {
                return await running.value
            }
            outcome = nil
            phase = .signingIn
            let apple = apple
            let task = Task { [weak self] in
                let completion = await Self.attempt(apple, result)
                self?.settle(completion)
                return completion
            }
            running = task
            return await task.value
        }

        /// The person saw the failure and moved on.
        func dismissFailure() {
            if case .failed = phase {
                phase = .idle
            }
        }

        private func settle(_ completion: Completion) {
            running = nil
            switch completion {
            case let .signedIn(signedIn):
                outcome = signedIn
                phase = .idle
            case .cancelled:
                phase = .idle
            case let .failed(failure):
                phase = .failed(failure)
            }
        }

        private static func attempt(_ apple: any AppleSigningIn, _ result: Result<ASAuthorization, any Error>) async -> Completion {
            do {
                return try await .signedIn(apple.complete(result))
            } catch {
                return completion(after: error)
            }
        }

        /// What a failure means for the screen: a dismissed sheet is nothing; the server's own words pass
        /// through; offline says so; a refused save is "unlock and try again"; the rest is a plain try again.
        nonisolated static func completion(after error: any Error) -> Completion {
            switch error {
            case SignInError.cancelled, is CancellationError:
                return .cancelled
            case let failure as Backend.Failure:
                return .failed(words(for: failure.flowFailure))
            case is KeychainError:
                return .failed(Flows.Failure(.unknown, message: unlock))
            default:
                // notPrepared, unreadableCredential, appleFailed(code), anything else
                return .failed(Flows.Failure(.unknown, message: tryAgain))
            }
        }

        private nonisolated static func words(for failure: Flows.Failure) -> Flows.Failure {
            if let message = failure.message, !message.isEmpty {
                return failure
            }
            return Flows.Failure(failure.kind, message: failure.kind == .network ? offline : tryAgain)
        }
    }
}

extension Session.AppleSignIn: Session.AppleSigningIn {}
