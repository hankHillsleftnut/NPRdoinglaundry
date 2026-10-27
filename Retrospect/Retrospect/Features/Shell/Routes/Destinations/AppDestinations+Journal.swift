//
//  AppDestinations+Journal.swift
//  G0: the journal group's pages in the app route table (JR-2 today's brief, JR-4 one entry (lane 1: #233 /
//  #235)). Only this group builds them, and only this file lists them: build a page in `page(for:in:)` /
//  `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind from `notBuilt` in
//  the same change. AppRouteTableTests fails a kind that is built and still listed, or listed nowhere. The
//  pages themselves live in JournalV2 (Features/Entries).
//
import SwiftUI

extension AppDestinations {
    enum Journal: AppDestinationGroup {
        static let group = AppRouteGroup.journal

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = [.entry]
        static let sheetsNotBuilt: Set<AppSheet.Kind> = [.brief]
    }
}
