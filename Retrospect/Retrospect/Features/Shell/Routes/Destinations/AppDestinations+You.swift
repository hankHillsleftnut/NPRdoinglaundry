//
//  AppDestinations+You.swift
//  G0: the you group's pages in the app route table (YO-3 a source, YO-5 what i know about you, YO-4 a node
//  (lane 3: #231 / #228 / #241)). Only this group builds them, and only this file lists them: build a page
//  in `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in the launcher) and remove its
//  kind from `notBuilt` in the same change. AppRouteTableTests fails a kind that is built and still listed,
//  or listed nowhere. The pages themselves live in Features/You.
//
import SwiftUI

extension AppDestinations {
    enum You: AppDestinationGroup {
        static let group = AppRouteGroup.you

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = [.youSource, .whatIKnow]
        static let sheetsNotBuilt: Set<AppSheet.Kind> = [.node]
    }
}
