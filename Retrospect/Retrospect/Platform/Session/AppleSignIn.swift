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
        private var pending: Nonce?

        init(
            client: Backend.Client,
            installer: any Installing,
            log: any Platform.LogSink,
            makeNonce: @escaping @Sendable () throws -> Nonce = { try Nonce.make() }
        ) {
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
                return try await signIn(with: Self.credential(from: authorization.credential))
            case let .failure(error):
                pending = nil
                throw Self.signInError(for: error)
            }
        }

        /// The sign-in itself, from a credential already read out of Apple's
        /// authorization. Uses up the pending nonce whatever happens next.
        func signIn(with credential: AppleCredential) async throws -> SignInOutcome {
            guard let nonce = pending else { throw SignInError.notPrepared }
            pending = nil
            let body = Backend.AppleSignInBody(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                rawNonce: nonce.raw,
                firstAuthorization: credential.isFirstAuthorization
                    ? .init(givenName: credential.givenName, familyName: credential.familyName, email: credential.email)
                    : nil
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
            log.record(.signedIn(provider: .apple, isNew: response.user.isNew))
            return SignInOutcome(
                userID: response.user.id, firstName: response.user.firstName, isNew: response.user.isNew, access: response.access.state
            )
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
