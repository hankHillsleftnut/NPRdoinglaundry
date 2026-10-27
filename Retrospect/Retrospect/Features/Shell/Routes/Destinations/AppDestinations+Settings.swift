//
//  AppDestinations+Settings.swift
//  G0: the settings group's pages in the app route table (ST-1 … ST-9 (lane 4: #224 → #232; ST-9 extends
//  the AccountPage)). Only this group builds them, and only this file lists them: build a page in
//  `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind
//  from `notBuilt` in the same change. AppRouteTableTests fails a kind that is built and still listed, or
//  listed nowhere. The pages themselves live in Features/Settings.
//
import SwiftUI

extension AppDestinations {
    enum Settings: AppDestinationGroup {
        static let group = AppRouteGroup.settings

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = [
            .settingsHub, .settingsDailyBrief, .settingsSources, .settingsSource, .settingsPrivacy,
            .settingsHowStraight, .settingsVoice, .settingsLearned, .settingsAccount,
        ]
        static let sheetsNotBuilt: Set<AppSheet.Kind> = []
    }
}
