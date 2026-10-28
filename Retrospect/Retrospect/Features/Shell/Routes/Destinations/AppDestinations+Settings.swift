//
//  AppDestinations+Settings.swift
//  G0: the settings group's pages in the app route table (ST-1 … ST-9 (lane 4: #224 → #232; ST-9 extends
//  the AccountPage)). Only this group builds them, and only this file lists them: build a page in
//  `page(for:in:)` / `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind
//  from `notBuilt` in the same change. AppRouteTableTests fails a kind that is built and still listed, or
//  listed nowhere. The pages themselves live in Features/Settings.
//
//  DEMO.app.b: every settings page is built here from the settings stack's own pages
//  (`SettingsHubPage`, `SettingsDestinations`), on `\.settingsData`, so the YO-1 picture and the drawer
//  foot open ST-1 on the stack they are in, and ST-1's rows push ST-2 … ST-9 onto that same stack. A
//  row whose page isn't built (or has nothing to show yet, as the stack decides) does nothing, as in
//  the stack. ST-9's sign-out runs on `\.signOutFlow` when the host gives one.
//
import SwiftUI

extension EnvironmentValues {
    /// The settings pages' data, for pages opened from another group's stack (the demo's sample).
    @Entry var settingsData: (any Flows.SettingsData)?
}

extension AppDestinations {
    enum Settings: AppDestinationGroup {
        static let group = AppRouteGroup.settings

        static func page(for route: AppRoute, in context: AppRouteContext) -> AnyView? {
            guard case let .settings(page) = route else { return nil }
            return AnyView(SettingsRoutePage(page: page, context: context))
        }

        static func sheet(for _: AppSheet, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static let notBuilt: Set<AppRoute.Kind> = []
        static let sheetsNotBuilt: Set<AppSheet.Kind> = []

        /// The settings stack's route for a page; nil for ST-1, the stack's root.
        static func route(for page: AppRoute.SettingsPage) -> SettingsRoute? {
            switch page {
            case .hub: nil
            case .dailyBrief: .dailyBrief
            case .sources: .sources
            case let .source(id): .source(id)
            case .privacy: .privacy
            case .howStraight: .howStraight
            case .voice: .voice
            case .learned: .learned
            case .account: .account
            }
        }

        /// The app route's page for a settings stack route.
        static func page(for route: SettingsRoute) -> AppRoute.SettingsPage {
            switch route {
            case .dailyBrief: .dailyBrief
            case .sources: .sources
            case let .source(id): .source(id: id)
            case .privacy: .privacy
            case .howStraight: .howStraight
            case .voice: .voice
            case .learned: .learned
            case .account: .account
            }
        }
    }
}

/// One settings page on the stack it was opened from: ST-1, or the page the settings stack shows for
/// the route, on the environment's data. Without the data (nothing injected it) the page is the canvas.
private struct SettingsRoutePage: View {
    let page: AppRoute.SettingsPage
    let context: AppRouteContext
    @Environment(\.settingsData) private var data
    @Environment(\.signOutFlow) private var signOut

    var body: some View {
        Group {
            if let data {
                content(data)
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ data: any Flows.SettingsData) -> some View {
        if let route = AppDestinations.Settings.route(for: page) {
            SettingsDestinations.view(for: route, in: stackContext(data))
        } else {
            SettingsHubPage(data: data, open: { open($0, data: data) }, back: context.back)
        }
    }

    /// The settings stack's context, pushing onto the stack this page is in.
    private func stackContext(_ data: any Flows.SettingsData) -> SettingsDestinations.Context {
        SettingsDestinations.Context(
            data: data,
            open: { open($0, data: data) },
            back: context.back,
            close: { _ in context.back() },
            signOut: signOut
        )
    }

    /// A settings row: its page, when the stack would open it (built, with something to show).
    private func open(_ route: SettingsRoute, data: any Flows.SettingsData) {
        guard SettingsDestinations.isBuilt(route, data: data) else { return }
        context.open?(.settings(AppDestinations.Settings.page(for: route)))
    }
}
