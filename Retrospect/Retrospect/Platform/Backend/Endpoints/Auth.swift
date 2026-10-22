import Foundation

extension Backend {
    /// What sign-in and refresh answer (contract 00 §3): the token pair, who
    /// signed in and where their account stands.
    struct AuthResponse: Decodable, Sendable, Equatable {
        struct User: Decodable, Sendable, Equatable {
            let id: String
            let firstName: String?
            let isNew: Bool
        }

        struct Access: Decodable, Sendable, Equatable {
            let state: Session.AccessState
        }

        let accessToken: String
        let refreshToken: String
        let accessTokenExpiresAt: Date
        let user: User
        let access: Access
    }

    /// `POST /v2/auth/apple`'s body: Apple's credential and the raw nonce the
    /// app hashed into it. The door is strict: exactly the contract's keys and
    /// nothing else.
    struct AppleSignInBody: Codable, Sendable, Equatable {
        /// The name and email Apple hands over once, on the first authorization.
        /// Sent as `fullName { givenName, familyName }` and `email`, each part
        /// `null` when Apple left it out; absent entirely on later sign-ins.
        struct FirstAuthorization: Sendable, Equatable {
            let givenName: String?
            let familyName: String?
            let email: String?
        }

        let identityToken: String
        let authorizationCode: String
        let rawNonce: String
        let firstAuthorization: FirstAuthorization?

        init(identityToken: String, authorizationCode: String, rawNonce: String, firstAuthorization: FirstAuthorization?) {
            self.identityToken = identityToken
            self.authorizationCode = authorizationCode
            self.rawNonce = rawNonce
            self.firstAuthorization = firstAuthorization
        }

        private enum CodingKeys: String, CodingKey {
            case identityToken, authorizationCode, rawNonce, fullName, email
        }

        private enum NameKeys: String, CodingKey {
            case givenName, familyName
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identityToken, forKey: .identityToken)
            try container.encode(authorizationCode, forKey: .authorizationCode)
            try container.encode(rawNonce, forKey: .rawNonce)
            guard let firstAuthorization else { return }
            var name = container.nestedContainer(keyedBy: NameKeys.self, forKey: .fullName)
            try name.encode(firstAuthorization.givenName, forKey: .givenName)
            try name.encode(firstAuthorization.familyName, forKey: .familyName)
            try container.encode(firstAuthorization.email, forKey: .email)
        }

        /// Reads the contract's fixture shape back (the fixture tests).
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            identityToken = try container.decode(String.self, forKey: .identityToken)
            authorizationCode = try container.decode(String.self, forKey: .authorizationCode)
            rawNonce = try container.decode(String.self, forKey: .rawNonce)
            guard container.contains(.fullName) || container.contains(.email) else {
                firstAuthorization = nil
                return
            }
            let name = try? container.nestedContainer(keyedBy: NameKeys.self, forKey: .fullName)
            firstAuthorization = try FirstAuthorization(
                givenName: name?.decodeIfPresent(String.self, forKey: .givenName),
                familyName: name?.decodeIfPresent(String.self, forKey: .familyName),
                email: container.decodeIfPresent(String.self, forKey: .email)
            )
        }
    }

    /// The body of refresh and signout: the device's refresh token.
    struct RefreshTokenBody: Codable, Sendable, Equatable {
        let refreshToken: String
    }

    /// `POST /v2/auth/signout`'s answer.
    struct SignedOut: Decodable, Sendable, Equatable {
        let signedOut: Bool
    }
}

extension Backend.Endpoints {
    /// `POST /v2/auth/apple` (public): Apple's credential with the raw nonce.
    struct AppleSignIn: Backend.Endpoint {
        typealias Body = Backend.AppleSignInBody
        typealias Response = Backend.AuthResponse

        let body: Body?

        init(_ body: Body) {
            self.body = body
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .authApple
        }

        var requiresAuth: Bool {
            false
        }
    }

    /// `POST /v2/auth/refresh` (public): trades the refresh token for a new
    /// pair. Ten seconds, so the session's one retry of a dropped answer lands
    /// inside the server's 30-second grace window.
    struct Refresh: Backend.Endpoint {
        typealias Response = Backend.AuthResponse

        let body: Backend.RefreshTokenBody?

        init(refreshToken: String) {
            body = Backend.RefreshTokenBody(refreshToken: refreshToken)
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .authRefresh
        }

        var requiresAuth: Bool {
            false
        }

        var timeout: Duration {
            .seconds(10)
        }
    }

    /// `POST /v2/auth/signout` (signed in): ends this device's session family.
    struct SignOut: Backend.Endpoint {
        typealias Response = Backend.SignedOut

        let body: Backend.RefreshTokenBody?

        init(refreshToken: String) {
            body = Backend.RefreshTokenBody(refreshToken: refreshToken)
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .authSignout
        }

        var timeout: Duration {
            .seconds(10)
        }
    }
}
