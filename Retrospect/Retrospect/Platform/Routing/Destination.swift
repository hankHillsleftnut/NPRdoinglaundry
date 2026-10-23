import Foundation

extension Routing {
    /// Where a link, a widget, a shortcut or (later) a notification asks the app to go.
    /// A closed list: anything that is not one of these is not a destination.
    enum Destination: Sendable, Equatable {
        case invite(code: String)
        case startRecording
        case stopRecording
        /// The OAuth return (`retrospect://integration-connected?provider=…&status=…`).
        case integrationConnected(provider: String, status: String)
        /// `nil` is today's.
        case brief(id: String?)
        case entry(id: String)
        case episode(id: String)
        case guess(id: String)
        case settings(SettingsPage)

        enum SettingsPage: String, Sendable, CaseIterable {
            case root, brief, account, subscription, privacy
        }

        /// The three routes the old screens already act on, in `RetrospectApp.onOpenURL`
        /// (flag, notification and sync). The router recognises them and leaves the doing to
        /// those branches, so they never act twice.
        var isHandledByOldScreens: Bool {
            switch self {
            case .startRecording, .stopRecording, .integrationConnected: true
            default: false
            }
        }
    }

    /// What kind of address an unrecognised link was. Logged instead of the address itself.
    enum UnknownKind: String, Sendable, CaseIterable {
        /// A `retrospect://` address that is not a route.
        case appLink
        /// An `https` address on the invite host that is not an invite.
        case inviteHostLink
        /// Anything else.
        case other
    }
}
