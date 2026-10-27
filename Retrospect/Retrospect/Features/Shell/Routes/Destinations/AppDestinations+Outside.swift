//
//  AppDestinations+Outside.swift
//  G0: the outside group's pages in the app route table (EX-1 share, as the app shows it (lane 5: #220)).
//  Only this group builds them, and only this file lists them: build a page in `page(for:in:)` /
//  `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind from `notBuilt` in
//  the same change. AppRouteTableTests fails a kind that is built and still listed, or listed nowhere. The
//  pages themselves live in Features/Outside.
//
import SwiftUI

extension AppDestinations {
    enum Outside: AppDestinationGroup {
        static let group = AppRouteGroup.outside

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = []
        static let sheetsNotBuilt: Set<AppSheet.Kind> = [.share]
    }
}
