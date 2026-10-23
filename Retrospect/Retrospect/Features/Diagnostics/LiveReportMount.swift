//
//  LiveReportMount.swift
//  DG.6.mount: the live "send a report" for a page, built from the app's environment: the
//  recorder, the signed-in person's outbox, reachability, and what a report says of the phone
//  and the account. No outbox (signed out, the store not open) means no sender, so the page
//  shows no row (decision 4: no dead control). The device is read only when the person sends.
//
import Foundation

@MainActor
enum LiveReportMount {
    typealias Diagnostics = Platform.Diagnostics

    /// The sender for `platform`'s open outbox, or nil when none is open or nobody is signed in.
    /// `device` reads the phone; it runs only inside a send (tests pass a spy).
    static func sender(
        for platform: Platform.AppEnvironment,
        origin: Diagnostics.Screen = .settings,
        device: @escaping @MainActor (_ isOnline: Bool) -> Diagnostics.Environment.Sources = { .device(isOnline: $0) }
    ) -> Diagnostics.LiveReportSender? {
        guard let outbox = platform.outbox, let account = account(in: platform.sessionState) else { return nil }
        return Diagnostics.LiveReportSender(
            recorder: platform.diagnostics, outbox: outbox, reachability: platform.reachability, origin: origin,
            context: { [weak platform] isOnline in
                Diagnostics.ReportContext(
                    environment: Diagnostics.Environment(sources: device(isOnline)),
                    account: Self.account(in: platform?.sessionState) ?? account
                )
            }
        )
    }

    /// The account as a report names it: the provider (Beta 1 signs in with Apple only), the access
    /// the session last saw, no entitlement yet. Never an email, a name or the user id: the server
    /// files the report under the token's user. Nil when nobody is signed in.
    static func account(in state: Session.State?) -> Diagnostics.Account? {
        guard case let .signedIn(_, access)? = state else { return nil }
        // The door has no "unknown"; an access this build can't name is a person using the app.
        let named = Diagnostics.Account.Access(rawValue: access.rawValue) ?? .member
        return Diagnostics.Account(provider: .apple, access: named, entitlement: .none)
    }
}
