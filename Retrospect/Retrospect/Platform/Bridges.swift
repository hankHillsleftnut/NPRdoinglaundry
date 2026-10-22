import Foundation

extension Platform {
    /// The named seams between the old app and the new session (PL1.5): the
    /// only place new code touches `RetrospectAPIClient` or `OnboardingState`,
    /// and the only way the old client reaches the new session. Old code
    /// calls the optional closures, which `AppEnvironment.live()` sets; the
    /// static functions are what new code may call on the old app.
    @MainActor
    enum Bridges {
        /// What the old client's 401 gets back from the new session.
        enum LegacyRefresh: Sendable, Equatable {
            /// The session refreshed and the mirror holds a new token: retry once.
            case refreshed
            /// The refresh couldn't be done now (offline, a server failure):
            /// fail the request, sign nothing out.
            case unavailable
            /// The server ended the session: the old client signs out as before.
            case signedOut
        }

        /// `RetrospectAPIClient.request` on a 401, before its old sign-out.
        static var refreshLegacy: (@Sendable () async -> LegacyRefresh)?

        /// `RetrospectAPIClient.signOut()`: the old Settings "Log Out" and the
        /// old 401 path sign the new session out too.
        static var legacySignedOut: (@Sendable () async -> Void)?

        /// The old client's published state, after the mirror changed its
        /// items: its root ladder (`hasUsableBackendAuth`) follows the new session.
        static func legacyStateChanged(userID: String?) {
            let client = RetrospectAPIClient.shared
            client.isAuthenticated = userID != nil
            client.currentUserId = userID
        }

        /// Sign-out reopens the old onboarding's sign-in gate, as the old
        /// 401 path always did.
        static func clearSignInGate() {
            OnboardingState.clearSignInGate()
        }
    }
}
