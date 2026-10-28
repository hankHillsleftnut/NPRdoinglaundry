//
//  AppDestinations+Account.swift
//  G0: the account group's pages in the app route table (AC-2 signing out (the sheet exists in
//  Features/Account; it needs its sign-out flow from the host)). Only this group builds them, and only this
//  file lists them: build a page in `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in
//  the launcher) and remove its kind from `notBuilt` in the same change. AppRouteTableTests fails a kind
//  that is built and still listed, or listed nowhere. The pages themselves live in Features/Account.
//  Features/Account is core (the release app's sign-out), so it may not name the table: the sheet is
//  built here and gets its actions as plain closures.
//
//  DEMO.app.b: `\.signOutFlow` is the host's sign-out flow for ST-9 (the demo hears it end and shows
//  AC-1 welcome back); the AC-2 sheet itself is still presented by the account page.
//
import SwiftUI

extension EnvironmentValues {
    /// The sign-out flow ST-9 runs on, when the host owns one; nil: the page's own sample.
    @Entry var signOutFlow: (any SignOutFlowing)?
}

extension AppDestinations {
    enum Account: AppDestinationGroup {
        static let group = AppRouteGroup.account

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = []
        static let sheetsNotBuilt: Set<AppSheet.Kind> = [.signOut]
    }
}
