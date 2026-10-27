//
//  AppDestinations+Podcasts.swift
//  G0: the podcasts group's pages in the app route table (PC-2 the player on an episode, PC-3 why this is
//  here (lane 2: #227 / #236)). Only this group builds them, and only this file lists them: build a page in
//  `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind
//  from `notBuilt` in the same change. AppRouteTableTests fails a kind that is built and still listed, or
//  listed nowhere. The pages themselves live in Features/Podcasts and Features/Player.
//
import SwiftUI

extension AppDestinations {
    enum Podcasts: AppDestinationGroup {
        static let group = AppRouteGroup.podcasts

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = [.whyThisIsHere]
        static let sheetsNotBuilt: Set<AppSheet.Kind> = [.episode]
    }
}
