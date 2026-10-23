import Foundation

extension Session {
    /// Who's signed in: the tokens from contract 00 §3, the user's id, and
    /// what the gate and the old screens need offline at launch (their access
    /// state, first name, which provider signed them in, and Apple's id for
    /// the revocation check).
    struct Credentials: Sendable, Equatable {
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
        let userID: String
        let access: AccessState
        let firstName: String?
        let provider: Provider
        /// `ASAuthorizationAppleIDCredential.user`; nil for other providers.
        let appleUserID: String?

        init(
            accessToken: String,
            accessTokenExpiresAt: Date,
            refreshToken: String,
            userID: String,
            access: AccessState = .unknown,
            firstName: String? = nil,
            provider: Provider = .unknown,
            appleUserID: String? = nil
        ) {
            self.accessToken = accessToken
            self.accessTokenExpiresAt = accessTokenExpiresAt
            self.refreshToken = refreshToken
            self.userID = userID
            self.access = access
            self.firstName = firstName
            self.provider = provider
            self.appleUserID = appleUserID
        }
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
        /// Set in UserDefaults the moment a sign-out begins and removed once the
        /// session item is gone, so a Keychain delete that fails can't bring a
        /// signed-out session back at the next launch.
        static let sessionEndedKey = "platform.sessionEnded"
        /// The old app's UserDefaults: any of them means this is an update, not a new install.
        static let legacyDefaultsKeys = ["hasCompletedOnboarding", "onboardingSignedIn", "onboardingCurrentStep"]

        enum Account: String, CaseIterable {
            /// The whole session as one JSON object.
            case session
            case hasSignedInBefore = "has_signed_in_before"
            case pendingInviteCode = "pending_invite_code"
            /// The name and email Apple hands over once, kept until a sign-in succeeds (PL1.4b).
            case pendingFirstAuthorization = "pending_first_authorization"
            /// Set before `DELETE /v2/account` is sent, cleared once the phone is erased or the server is known
            /// not to have heard it (PL3.7g.min). No content: its presence is the whole value.
            case pendingDeletion = "pending_deletion"
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

        /// Whether a sign-out began and its delete hasn't succeeded yet.
        var isSessionEnded: Bool {
            defaults.object(forKey: Self.sessionEndedKey) != nil
        }

        /// Sign-out begins: whatever the Keychain does next, the session is over.
        func markSessionEnded() {
            defaults.set(true, forKey: Self.sessionEndedKey)
        }

        /// The session item is gone: the mark has done its job.
        func clearSessionEnded() {
            defaults.removeObject(forKey: Self.sessionEndedKey)
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

        // MARK: The first authorization Apple sends once

        func kept() -> KeptFirstAuthorization? {
            guard let text = try? string(.pendingFirstAuthorization), let data = text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(KeptFirstAuthorization.self, from: data)
        }

        func keep(_ value: KeptFirstAuthorization) {
            guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else { return }
            try? write(text, .pendingFirstAuthorization)
        }

        func clear() {
            try? keychain.delete(Account.pendingFirstAuthorization.rawValue)
        }

        // MARK: Deleting the account (PL3.7g.min)

        /// Whether a deletion was sent and the phone isn't erased yet. Unreadable (a locked phone) reads as not
        /// known: the caller asks again on the next launch rather than erase on a guess.
        func isDeletionPending() throws -> Bool {
            try string(.pendingDeletion) == "1"
        }

        /// Kept BEFORE the request is sent, so a kill after the 202 still finishes the erase on the next launch.
        func markDeletionPending() throws {
            try write("1", .pendingDeletion)
        }

        /// The server never heard the request (the next launch found a working session): nothing is erased.
        func clearDeletionPending() throws {
            try keychain.delete(Account.pendingDeletion.rawValue)
        }

        /// The account is deleted: every item goes, deeper than sign-out (which keeps `hasSignedInBefore`, the
        /// pending invite and Apple's kept first authorization), so the phone opens on the first-time splash.
        /// The pending flag goes last, and only when everything before it went, so a failed delete is tried
        /// again on the next launch. The old client's service is not touched here (PL3.7i, the old app's leftovers).
        func eraseEverything() throws {
            for account in [Account.session, .hasSignedInBefore, .pendingInviteCode, .pendingFirstAuthorization] {
                try keychain.delete(account.rawValue)
            }
            clearSessionEnded()
            try keychain.delete(Account.pendingDeletion.rawValue)
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

        /// The launch check, called from `AppEntry` before the old app starts,
        /// so it runs before the old client restores its sign-in or anything
        /// reads the session. The sentinel is read first: an ordinary launch
        /// touches the Keychain not at all. Only when it's missing is the phone
        /// probed, because before its first unlock after a restart (iOS can
        /// prewarm the app then) UserDefaults read as empty, which would look
        /// like a fresh install and wipe a real session; then the check waits
        /// and the session manager runs it again on the first active scene.
        /// Logs what it did, or the status when it failed; never throws. A
        /// probe that fails for another reason is logged as such and the
        /// check counts as not run.
        @discardableResult
        static func checkInstallAtLaunch(
            probe: () -> UnlockProbe,
            log: any Platform.LogSink,
            keychain: any KeychainBackend = SystemKeychain(service: service),
            legacyKeychain: any KeychainBackend = SystemKeychain(service: legacyService),
            defaults: UserDefaults = .standard
        ) -> InstallCheck? {
            guard defaults.object(forKey: installSentinelKey) == nil else {
                log.record(.installChecked(.alreadyDone))
                return .alreadyDone
            }
            switch probe() {
            case .locked:
                log.record(.installChecked(.deferredUntilUnlock))
                return .deferredUntilUnlock
            case let .failed(status):
                log.record(.installCheckFailed(status: status))
                return nil
            case .unlocked:
                break
            }
            do {
                let check = try applyInstallSentinel(keychain: keychain, legacyKeychain: legacyKeychain, defaults: defaults)
                log.record(.installChecked(check))
                return check
            } catch let error as KeychainError {
                log.record(.installCheckFailed(status: error.status))
                return nil
            } catch {
                log.record(.installCheckErrored)
                return nil
            }
        }

        /// The launch check again, on this store's items (the session manager
        /// runs it on the first active scene when launch deferred it or it
        /// didn't run).
        func checkInstall(probe: () -> UnlockProbe, log: any Platform.LogSink) -> InstallCheck? {
            Self.checkInstallAtLaunch(probe: probe, log: log, keychain: keychain, legacyKeychain: legacyKeychain, defaults: defaults)
        }

        // MARK: The session item

        /// The session as stored. Only the tokens and the user id are required;
        /// the expiry and the fields added after PL1.3 are read leniently, so a
        /// bad value never costs the tokens beside it and an item written by an
        /// earlier build still reads (as `unknown` and nil).
        private struct Saved: Codable {
            let accessToken: String
            let accessTokenExpiresAt: String?
            let refreshToken: String
            let userID: String
            let access: String?
            let firstName: String?
            let provider: String?
            let appleUserID: String?

            init(_ credentials: Credentials) {
                accessToken = credentials.accessToken
                accessTokenExpiresAt = Backend.Coding.timestamp(credentials.accessTokenExpiresAt)
                refreshToken = credentials.refreshToken
                userID = credentials.userID
                access = credentials.access.rawValue
                firstName = credentials.firstName
                provider = credentials.provider.rawValue
                appleUserID = credentials.appleUserID
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                accessToken = try container.decode(String.self, forKey: .accessToken)
                accessTokenExpiresAt = try? container.decodeIfPresent(String.self, forKey: .accessTokenExpiresAt)
                refreshToken = try container.decode(String.self, forKey: .refreshToken)
                userID = try container.decode(String.self, forKey: .userID)
                access = try? container.decodeIfPresent(String.self, forKey: .access)
                firstName = try? container.decodeIfPresent(String.self, forKey: .firstName)
                provider = try? container.decodeIfPresent(String.self, forKey: .provider)
                appleUserID = try? container.decodeIfPresent(String.self, forKey: .appleUserID)
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
                userID: saved.userID,
                access: saved.access.flatMap(AccessState.init(rawValue:)) ?? .unknown,
                firstName: saved.firstName,
                provider: saved.provider.flatMap(Provider.init(rawValue:)) ?? .unknown,
                appleUserID: saved.appleUserID
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

extension Session.Store: Session.FirstAuthorizationKeeping {}
