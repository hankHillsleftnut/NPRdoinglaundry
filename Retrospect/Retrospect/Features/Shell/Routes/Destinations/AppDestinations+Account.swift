//
//  AppDestinations+Account.swift
//  G0: the account group's pages in the app route table (AC-2 signing out (the sheet exists in
//  Features/Account; it needs its sign-out flow from the host)). Only this group builds them, and only this
//  file lists them: build a page in `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in
//  the launcher) and remove its kind from `notBuilt` in the same change. AppRouteTableTests fails a kind
//  that is built and still listed, or listed nowhere. The pages themselves live in Features/Account.
//
import SwiftUI

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
