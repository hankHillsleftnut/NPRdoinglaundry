import Foundation
import Observation

extension Routing {
    /// Every way into the app, one door. A link is parsed; an invite goes to the invite center at
    /// once (it never waits, it is not a screen); the three routes the old screens act on are left
    /// to them; the rest wait in `pending` until the root is ready to show them (signed in, past
    /// onboarding) and takes them with `consume()`. A pending destination can name an entry or an
    /// episode of one person, so it is dropped when that person signs out.
    @MainActor @Observable
    final class Router {
        /// The one destination waiting for the app to be ready; a newer one replaces it.
        private(set) var pending: Destination?

        @ObservationIgnored private let inviteBase: URL?
        @ObservationIgnored private let receiveInvite: @MainActor (String) async -> Void
        @ObservationIgnored private let log: any Platform.LogSink
        /// The newest invite hand-over; each waits for the one before it, so codes arrive in the order the links did.
        @ObservationIgnored private var lastInvite: Task<Void, Never>?

        init(inviteBase: URL?, log: any Platform.LogSink, receiveInvite: @escaping @MainActor (String) async -> Void) {
            self.inviteBase = inviteBase
            self.log = log
            self.receiveInvite = receiveInvite
        }

        /// A link, a universal link or a widget's address. The Google sign-in return and anything
        /// that is not a destination do nothing (the unknown ones are logged by kind only).
        func open(_ url: URL) {
            if Parser.isGoogleCallback(url) {
                return
            }
            guard let destination = Parser.parse(url, inviteBase: inviteBase) else {
                log.record(.routeUnknown(Parser.unknownKind(of: url, inviteBase: inviteBase)))
                return
            }
            open(destination)
        }

        func open(_ destination: Destination) {
            switch destination {
            case let .invite(code):
                // Never pending: the code is kept by the invite center (Keychain) for after sign-in.
                let previous = lastInvite
                lastInvite = Task { [receiveInvite] in
                    await previous?.value
                    await receiveInvite(code)
                }
            case _ where destination.isHandledByOldScreens:
                return
            default:
                pending = destination
            }
        }

        /// Takes the waiting destination, once.
        func consume() -> Destination? {
            defer { pending = nil }
            return pending
        }

        /// Sign-out: nothing waits for the next person.
        func clear() {
            pending = nil
        }

        /// Waits for every invite handed over so far. For tests.
        func settled() async {
            await lastInvite?.value
        }
    }
}
