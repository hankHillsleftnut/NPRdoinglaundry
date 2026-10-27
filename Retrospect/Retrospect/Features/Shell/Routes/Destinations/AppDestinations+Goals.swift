//
//  AppDestinations+Goals.swift
//  G0: the goals group's pages in the app route table (GL-2 one goal (lane 5: #219)). Only this group
//  builds them, and only this file lists them: build a page in `page(for:in:)` / `sheet(for:in:)` (data
//  from the environment, as in the launcher) and remove its kind from `notBuilt` in the same change.
//  AppRouteTableTests fails a kind that is built and still listed, or listed nowhere. The pages themselves
//  live in Features/Goals.
//
import SwiftUI

extension AppDestinations {
    enum Goals: AppDestinationGroup {
        static let group = AppRouteGroup.goals

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = [.goal]
        static let sheetsNotBuilt: Set<AppSheet.Kind> = []
    }
}
