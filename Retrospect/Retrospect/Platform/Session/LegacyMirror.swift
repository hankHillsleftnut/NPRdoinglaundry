import Foundation

extension Session {
    /// Keeps the old screens signed in while they exist: after every sign-in
    /// and refresh the current access token and ids are written where the old
    /// client and ElevenLabs read them; on sign-out they're removed.
    protocol LegacyMirroring: Sendable {
        func write(accessToken: String, userID: String, appleUserID: String?) throws
        func clear() throws
    }

    /// The old client's items (`com.retrospect.api`): `jwt_token` holds the
    /// v2 **access** token (the old routes accept it), `user_id` ours,
    /// `apple_user_id` Apple's. Never the refresh token. Written
    /// `AfterFirstUnlockThisDeviceOnly` through the system Keychain, which
    /// moves an item the old app wrote `WhenUnlocked`. After each write or
    /// clear, the old client's published state is set on the main actor
    /// (`Platform.Bridges.legacyStateChanged`), so its root ladder follows.
    struct LegacyMirror: LegacyMirroring {
        enum Account: String, CaseIterable {
            case token = "jwt_token"
            case userID = "user_id"
            case appleUserID = "apple_user_id"
        }

        private let keychain: any KeychainBackend
        private let stateChanged: @MainActor @Sendable (String?) -> Void

        init(keychain: any KeychainBackend, stateChanged: @escaping @MainActor @Sendable (String?) -> Void) {
            self.keychain = keychain
            self.stateChanged = stateChanged
        }

        func write(accessToken: String, userID: String, appleUserID: String?) throws {
            try keychain.write(Data(accessToken.utf8), account: Account.token.rawValue)
            try keychain.write(Data(userID.utf8), account: Account.userID.rawValue)
            if let appleUserID {
                try keychain.write(Data(appleUserID.utf8), account: Account.appleUserID.rawValue)
            } else {
                try keychain.delete(Account.appleUserID.rawValue)
            }
            publish(userID)
        }

        /// Removes every item it can, tells the old client, then reports the
        /// first failure: one stuck item never leaves the others or the old
        /// client's state signed in.
        func clear() throws {
            var firstError: (any Error)?
            for account in Account.allCases {
                do {
                    try keychain.delete(account.rawValue)
                } catch {
                    firstError = firstError ?? error
                }
            }
            publish(nil)
            if let firstError {
                throw firstError
            }
        }

        private func publish(_ userID: String?) {
            let stateChanged = stateChanged
            Task { @MainActor in stateChanged(userID) }
        }
    }
}
