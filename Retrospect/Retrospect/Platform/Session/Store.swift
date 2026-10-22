import Foundation

extension Session {
    /// Who's signed in: the tokens from contract 00 §3 and the user's id.
    struct Credentials: Sendable, Equatable {
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
        let userID: String
    }

    /// What the launch check found. Carries no values, so it can be logged.
    enum InstallCheck: Sendable, Equatable {
        /// The sentinel was already there: an ordinary launch.
        case alreadyDone
        /// A fresh install or a reinstall: earlier items were wiped.
        case wipedLeftovers
        /// An update from the old app: nothing was touched.
        case keptUpdate
        /// The phone hasn't been unlocked since it started, so the check waits
        /// for a later launch.
        case deferredUntilUnlock
    }

    /// The one place the session lives on the phone, and the only code that
    /// knows its Keychain identifiers. (The old client and ElevenLabs keep their
    /// own copies of the old identifiers until PL1.4's mirror byte.)
    ///
    /// The session is one JSON item, written in one Keychain call, so a save
    /// either lands whole or leaves the previous session exactly as it was.
    /// "Signed in before" and a pending invite are items of their own: they
    /// outlive the session.
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

        enum Account: String, CaseIterable {
            /// The whole session as one JSON object.
            case session
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

        /// The saved session, or nil when signed out. An item that isn't a
        /// session (unreadable JSON, a token missing) reads as signed out. An
        /// unreadable expiry reads as long past, so the caller refreshes with the
        /// refresh token instead of losing it.
        func credentials() throws -> Credentials? {
            try keychain.read(Account.session.rawValue).flatMap(Self.decode)
        }

        /// Saves a new session in one Keychain write: it replaces the previous
        /// session whole, or fails and leaves it untouched.
        func save(_ credentials: Credentials) throws {
            try keychain.write(Self.encode(credentials), account: Account.session.rawValue)
        }

        /// Sign-out: the session goes; `hasSignedInBefore` and a pending invite stay.
        func clearCredentials() throws {
            try keychain.delete(Account.session.rawValue)
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

        /// See the static version, which launch calls before any store exists.
        @discardableResult
        func applyInstallSentinel() throws -> InstallCheck {
            try Self.applyInstallSentinel(keychain: keychain, legacyKeychain: legacyKeychain, defaults: defaults)
        }

        /// Call once at launch, before anything reads the session. On a fresh
        /// install or a reinstall, Keychain items left by an earlier install are
        /// wiped (ours and the old client's). An update from the old app keeps
        /// everything, so nobody is signed out by updating. If a wipe fails, the
        /// sentinel isn't written and the next launch tries again.
        @discardableResult
        static func applyInstallSentinel(
            keychain: any KeychainBackend,
            legacyKeychain: any KeychainBackend,
            defaults: UserDefaults
        ) throws -> InstallCheck {
            guard defaults.object(forKey: installSentinelKey) == nil else { return .alreadyDone }
            let isUpdate = legacyDefaultsKeys.contains { defaults.object(forKey: $0) != nil }
            if !isUpdate {
                try keychain.deleteAll()
                try legacyKeychain.deleteAll()
            }
            defaults.set(true, forKey: installSentinelKey)
            return isUpdate ? .keptUpdate : .wipedLeftovers
        }

        /// The launch bridge, called from `AppEntry` before the old app starts,
        /// so it runs before the old client restores its sign-in or anything
        /// reads the session. Before the phone's first unlock after a restart
        /// (iOS can prewarm the app then), UserDefaults read as empty, which
        /// would look like a fresh install and wipe a real session, so the check
        /// waits for a later launch. Logs what it did, or the Keychain status
        /// when it failed; never throws.
        @discardableResult
        static func checkInstallAtLaunch(
            isUnlockedSinceBoot: Bool,
            log: any Platform.LogSink,
            keychain: any KeychainBackend = SystemKeychain(service: service),
            legacyKeychain: any KeychainBackend = SystemKeychain(service: legacyService),
            defaults: UserDefaults = .standard
        ) -> InstallCheck? {
            guard isUnlockedSinceBoot else {
                log.record(.installChecked(.deferredUntilUnlock))
                return .deferredUntilUnlock
            }
            do {
                let check = try applyInstallSentinel(keychain: keychain, legacyKeychain: legacyKeychain, defaults: defaults)
                log.record(.installChecked(check))
                return check
            } catch let error as KeychainError {
                log.record(.installCheckFailed(status: error.status))
                return nil
            } catch {
                log.record(.installCheckFailed(status: 0))
                return nil
            }
        }

        // MARK: The session item

        /// The session as stored. The expiry is kept as text and read leniently,
        /// so a bad expiry never costs the tokens beside it.
        private struct Saved: Codable {
            let accessToken: String
            let accessTokenExpiresAt: String?
            let refreshToken: String
            let userID: String

            init(_ credentials: Credentials) {
                accessToken = credentials.accessToken
                accessTokenExpiresAt = Backend.Coding.timestamp(credentials.accessTokenExpiresAt)
                refreshToken = credentials.refreshToken
                userID = credentials.userID
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                accessToken = try container.decode(String.self, forKey: .accessToken)
                accessTokenExpiresAt = try? container.decodeIfPresent(String.self, forKey: .accessTokenExpiresAt)
                refreshToken = try container.decode(String.self, forKey: .refreshToken)
                userID = try container.decode(String.self, forKey: .userID)
            }
        }

        static func encode(_ credentials: Credentials) throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(Saved(credentials))
        }

        static func decode(_ data: Data) -> Credentials? {
            guard let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return nil }
            return Credentials(
                accessToken: saved.accessToken,
                accessTokenExpiresAt: expiry(saved.accessTokenExpiresAt),
                refreshToken: saved.refreshToken,
                userID: saved.userID
            )
        }

        /// The stored expiry, or `.distantPast` when it's missing or unreadable.
        private static func expiry(_ text: String?) -> Date {
            guard let text else { return .distantPast }
            if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt)) {
                return date
            }
            return (try? Date(text, strategy: Date.ISO8601FormatStyle(timeZone: .gmt))) ?? .distantPast
        }

        // MARK: Flag items

        private func string(_ account: Account) throws -> String? {
            try keychain.read(account.rawValue).flatMap { String(bytes: $0, encoding: .utf8) }
        }

        private func write(_ value: String, _ account: Account) throws {
            try keychain.write(Data(value.utf8), account: account.rawValue)
        }
    }
}
