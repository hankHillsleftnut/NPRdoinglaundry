import AuthenticationServices
import Foundation

extension Session {
    /// What a sign-in hands the screen: who signed in and where they stand.
    /// Never the tokens; those went straight to the store.
    struct SignInOutcome: Sendable, Equatable {
        let userID: String
        let firstName: String?
        let isNew: Bool
        let access: AccessState
    }

    /// Why a sign-in stopped before the server answered. Server answers are
    /// `Backend.Failure`; a save that failed is `KeychainError`.
    enum SignInError: Error, Equatable {
        /// The person dismissed Apple's sheet. The screen shows nothing.
        case cancelled
        /// `complete` without a matching `prepare`, or the nonce was already
        /// used: nothing is sent without a fresh nonce.
        case notPrepared
        /// Apple's credential had no identity token or no authorization code.
        case unreadableCredential
        /// Apple's sheet failed for another reason; the code, never its text.
        case appleFailed(code: Int)
    }

    /// What `complete` reads from Apple's credential: all the door needs.
    struct AppleCredential: Sendable, Equatable {
        /// Apple's stable id for this person and this app (`credential.user`).
        let user: String
        let identityToken: String
        let authorizationCode: String
        let givenName: String?
        let familyName: String?
        let email: String?

        /// Apple hands the name and email over once, the first time the person
        /// authorizes the app. Any of them present means this is that time.
        var isFirstAuthorization: Bool {
            givenName != nil || familyName != nil || email != nil
        }
    }

    /// The name and email Apple sends ONCE, with the Apple id they belong to, kept (in the Keychain, on this phone) from the
    /// moment Apple hands them over until a sign-in succeeds, so a failed first call does not lose them for good.
    struct KeptFirstAuthorization: Codable, Sendable, Equatable {
        let appleUser: String
        let givenName: String?
        let familyName: String?
        let email: String?
    }

    protocol FirstAuthorizationKeeping: Sendable {
        func kept() async -> KeptFirstAuthorization?
        func keep(_ value: KeptFirstAuthorization) async
        func clear() async
    }

    /// For previews and tests: kept in memory only.
    final class MemoryFirstAuthorization: FirstAuthorizationKeeping, @unchecked Sendable {
        private let lock = NSLock()
        private var value: KeptFirstAuthorization?

        init() {}

        func kept() async -> KeptFirstAuthorization? { lock.withLock { value } }
        func keep(_ value: KeptFirstAuthorization) async { lock.withLock { self.value = value } }
        func clear() async { lock.withLock { value = nil } }
    }

    /// Where a new session goes once the server has answered: saved whole,
    /// mirrored for the old screens, marked as signed in before. The session
    /// manager (PL1.5) is the app's; until it lands the store itself is.
    protocol Installing: Sendable {
        func install(_ credentials: Credentials) async throws
    }

    /// Sign in with Apple, from the button's two callbacks to a saved session.
    ///
    /// `prepare` makes a nonce for one request and puts its hash on the
    /// request; `complete` sends Apple's credential with that nonce's raw value
    /// and installs the answer. Every `prepare` makes a new nonce and every
    /// `complete` uses it up, so a token can never be sent with a stale or a
    /// missing nonce: the server would refuse it, and the next tap starts clean.
    @MainActor
    final class AppleSignIn {
        private let client: Backend.Client
        private let installer: any Installing
        private let log: any Platform.LogSink
        private let makeNonce: @Sendable () throws -> Nonce
        private let keeper: (any FirstAuthorizationKeeping)?
        private var pending: Nonce?
        /// The same value in memory, for when the Keychain write or read fails: a retry in this run still carries it.
        private var remembered: KeptFirstAuthorization?

        init(
            client: Backend.Client,
            installer: any Installing,
            log: any Platform.LogSink,
            keeper: (any FirstAuthorizationKeeping)? = nil,
            makeNonce: @escaping @Sendable () throws -> Nonce = { try Nonce.make() }
        ) {
            self.keeper = keeper
            self.client = client
            self.installer = installer
            self.log = log
            self.makeNonce = makeNonce
        }

        /// Before Apple's sheet: asks for the name and email (given once) and
        /// binds the request to a new nonce. If no nonce can be made, the
        /// request goes out unbound and `complete` refuses to send its token.
        func prepare(_ request: ASAuthorizationAppleIDRequest) {
            request.requestedScopes = [.fullName, .email]
            do {
                let nonce = try makeNonce()
                request.nonce = nonce.hashed
                pending = nonce
            } catch let error as Nonce.RandomUnavailable {
                pending = nil
                log.record(.nonceUnavailable(status: error.status))
            } catch {
                pending = nil
                log.record(.nonceUnavailable(status: errSecInternalError))
            }
        }

        /// After Apple's sheet: the credential goes to the server with the
        /// nonce from `prepare`, and the answer is installed.
        func complete(_ result: Result<ASAuthorization, any Error>) async throws -> SignInOutcome {
            switch result {
            case let .success(authorization):
                return try await complete(credential: authorization.credential)
            case let .failure(error):
                pending = nil
                throw Self.signInError(for: error)
            }
        }

        /// The success half of `complete`, from the credential Apple returned.
        /// An unreadable credential uses the nonce up like every other exit.
        func complete(credential: any ASAuthorizationCredential) async throws -> SignInOutcome {
            let read: AppleCredential
            do {
                read = try Self.credential(from: credential)
            } catch {
                pending = nil
                throw error
            }
            return try await signIn(with: read)
        }

        /// The sign-in itself, from a credential already read out of Apple's
        /// authorization. Uses up the pending nonce whatever happens next.
        func signIn(with credential: AppleCredential) async throws -> SignInOutcome {
            guard let nonce = pending else { throw SignInError.notPrepared }
            pending = nil
            let first = await firstAuthorization(for: credential)
            let body = Backend.AppleSignInBody(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                rawNonce: nonce.raw,
                firstAuthorization: first.map { .init(givenName: $0.givenName, familyName: $0.familyName, email: $0.email) }
            )
            let response = try await client.send(Backend.Endpoints.AppleSignIn(body))
            try await installer.install(Credentials(
                accessToken: response.accessToken,
                accessTokenExpiresAt: response.accessTokenExpiresAt,
                refreshToken: response.refreshToken,
                userID: response.user.id,
                access: response.access.state,
                firstName: response.user.firstName,
                provider: .apple,
                appleUserID: credential.user
            ))
            remembered = nil
            await keeper?.clear()
            log.record(.signedIn(provider: .apple, isNew: response.user.isNew))
            return SignInOutcome(
                userID: response.user.id, firstName: response.user.firstName, isNew: response.user.isNew, access: response.access.state
            )
        }

        /// What goes in the body's first-authorization part: what Apple just sent (kept first, in case this call fails),
        /// else what an earlier failed call kept for this same Apple id.
        private func firstAuthorization(for credential: AppleCredential) async -> KeptFirstAuthorization? {
            if credential.isFirstAuthorization {
                let value = KeptFirstAuthorization(
                    appleUser: credential.user, givenName: credential.givenName, familyName: credential.familyName, email: credential.email
                )
                remembered = value
                await keeper?.keep(value)
                return value
            }
            let stored = await keeper?.kept()
            guard let kept = stored ?? remembered, kept.appleUser == credential.user else { return nil }
            return kept
        }

        /// Reads what the door needs out of Apple's credential. Both tokens must
        /// be there and be UTF-8, or there is nothing to send.
        static func credential(from credential: any ASAuthorizationCredential) throws -> AppleCredential {
            guard let apple = credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = apple.identityToken, let identityToken = String(data: tokenData, encoding: .utf8),
                  let codeData = apple.authorizationCode, let authorizationCode = String(data: codeData, encoding: .utf8),
                  !identityToken.isEmpty, !authorizationCode.isEmpty
            else {
                throw SignInError.unreadableCredential
            }
            return AppleCredential(
                user: apple.user,
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                givenName: apple.fullName?.givenName,
                familyName: apple.fullName?.familyName,
                email: apple.email
            )
        }

        /// What Apple's error means: a dismissed sheet, or a failure by code.
        static func signInError(for error: any Error) -> SignInError {
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain, nsError.code == ASAuthorizationError.canceled.rawValue {
                return .cancelled
            }
            return .appleFailed(code: nsError.code)
        }
    }
}

extension Session {
    /// Whether the person has removed the app from their Apple ID: asked on
    /// every active scene for Apple sessions (the server learns nothing until
    /// BE0.13). Three seconds, and every failure reads as unknown.
    enum AppleRevocationCheck {
        static let timeout: Duration = .seconds(3)

        static let live: @Sendable (String) async -> AppleCredentialState = { appleUserID in
            await first(timeout: timeout) { answer in
                ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, error in
                    guard error == nil else { return answer(.unknown) }
                    switch state {
                    case .authorized, .transferred: answer(.authorized)
                    case .revoked, .notFound: answer(.revoked)
                    @unknown default: answer(.unknown)
                    }
                }
            }
        }

        /// Whichever comes first: `ask`'s answer or the timer (`.unknown`).
        /// One continuation, resumed exactly once; a late answer is dropped.
        static func first(
            timeout: Duration,
            ask: @escaping @Sendable (@escaping @Sendable (AppleCredentialState) -> Void) -> Void
        ) async -> AppleCredentialState {
            await withCheckedContinuation { continuation in
                let resumed = Platform.Box(false)
                let answer: @Sendable (AppleCredentialState) -> Void = { state in
                    let first = resumed.exchange(true) == false
                    if first {
                        continuation.resume(returning: state)
                    }
                }
                Task {
                    try? await Task.sleep(for: timeout)
                    answer(.unknown)
                }
                ask(answer)
            }
        }
    }
}
