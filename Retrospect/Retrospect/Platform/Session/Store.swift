import Foundation

extension Session {
    /// Who's signed in: the tokens from contract 00 §3 and the user's id.
    struct Credentials: Sendable, Equatable {
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
        let userID: String
    }

    /// The one place the session lives on the phone, and the only code that
    /// knows its Keychain identifiers. (The old client and ElevenLabs keep their
    /// own copies of the old identifiers until PL1.4's mirror byte.)
    actor Store {
        /// The new session's Keychain service.
        static let service = "com.retrospect.session"
        /// The old client's service, wiped with ours on a fresh install.
        static let legacyService = "com.retrospect.api"
        /// Set in UserDefaults once launch hygiene has run. UserDefaults don't
        /// survive deleting the app; Keychain items do.
        static let installSentinelKey = "platform.installSentinel"
        /// The old app's UserDefaults: any of them means this is an update, not a new install.
        static let legacyDefaultsKeys = ["hasCompletedOnboarding", "onboardingSignedIn", "onboardingCurrentStep"]

        private enum Account: String, CaseIterable {
            case accessToken = "access_token"
            case accessExpiresAt = "access_expires_at"
            case refreshToken = "refresh_token"
            case userID = "user_id"
            case hasSignedInBefore = "has_signed_in_before"
            case pendingInviteCode = "pending_invite_code"
        }

        private let keychain: any KeychainBackend
        private let legacyKeychain: any KeychainBackend
        private let defaults: UserDefaults

        init(
            keychain: any KeychainBackend = SystemKeychain(service: Store.service),
            legacyKeychain: any KeychainBackend = SystemKeychain(service: Store.legacyService),
            defaults: UserDefaults = .standard
        ) {
            self.keychain = keychain
            self.legacyKeychain = legacyKeychain
            self.defaults = defaults
        }

        // MARK: Credentials

        /// The saved session, or nil when signed out. A half-written session
        /// (one item missing or unreadable as text) reads as signed out.
        func credentials() throws -> Credentials? {
            guard let accessToken = try string(.accessToken),
                  let expiry = try string(.accessExpiresAt),
                  let expiresAt = try? Date(expiry, strategy: Self.dateFormat),
                  let refreshToken = try string(.refreshToken),
                  let userID = try string(.userID)
            else {
                return nil
            }
            return Credentials(accessToken: accessToken, accessTokenExpiresAt: expiresAt, refreshToken: refreshToken, userID: userID)
        }

        /// Saves a new session. The refresh token goes first, so a save that
        /// fails partway leaves a session that reads as signed out, never one
        /// with a new access token and a stale refresh token.
        func save(_ credentials: Credentials) throws {
            try write(credentials.refreshToken, .refreshToken)
            try write(credentials.userID, .userID)
            try write(credentials.accessTokenExpiresAt.formatted(Self.dateFormat), .accessExpiresAt)
            try write(credentials.accessToken, .accessToken)
        }

        /// Sign-out: the session goes; `hasSignedInBefore` and a pending invite stay.
        func clearCredentials() throws {
            for account in [Account.accessToken, .accessExpiresAt, .refreshToken, .userID] {
                try keychain.delete(account.rawValue)
            }
        }

        // MARK: Flags

        /// Whether anyone has signed in on this install. Survives sign-out
        /// (AC-1 shows "welcome back"); only the reinstall wipe clears it.
        var hasSignedInBefore: Bool {
            get throws { try string(.hasSignedInBefore) == "1" }
        }

        func markSignedInBefore() throws {
            try write("1", .hasSignedInBefore)
        }

        /// An invite code waiting to be redeemed after sign-in (PL1.7).
        func pendingInviteCode() throws -> String? {
            try string(.pendingInviteCode)
        }

        func setPendingInviteCode(_ code: String?) throws {
            if let code {
                try write(code, .pendingInviteCode)
            } else {
                try keychain.delete(Account.pendingInviteCode.rawValue)
            }
        }

        // MARK: Launch hygiene

        /// Call once at launch, before anything reads the session. On a fresh
        /// install or a reinstall, Keychain items left by an earlier install are
        /// wiped (ours and the old client's). An update from the old app keeps
        /// everything, so nobody is signed out by updating.
        func applyInstallSentinel() throws {
            guard defaults.object(forKey: Self.installSentinelKey) == nil else { return }
            let isUpdate = Self.legacyDefaultsKeys.contains { defaults.object(forKey: $0) != nil }
            if !isUpdate {
                try keychain.deleteAll()
                try legacyKeychain.deleteAll()
            }
            defaults.set(true, forKey: Self.installSentinelKey)
        }

        // MARK: Items

        private static let dateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt)

        private func string(_ account: Account) throws -> String? {
            try keychain.read(account.rawValue).flatMap { String(bytes: $0, encoding: .utf8) }
        }

        private func write(_ value: String, _ account: Account) throws {
            try keychain.write(Data(value.utf8), account: account.rawValue)
        }
    }
}
