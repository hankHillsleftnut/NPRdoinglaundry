//
//  SettingsStack.swift
//  V2.settings: the settings pages as one push stack (journey map 06: ST-1 pushes ST-2 … ST-9, each
//  page's back returns). Typed routes only. Dark: the launcher is the only way in (the YO-1 picture
//  and the drawer foot are the wiring PR's). The first half (ST-1 … ST-4) is built here; the second
//  half's pages come from `SettingsDestinations.trust` in `SettingsDestinations+Trust.swift`.
//
import SwiftUI

/// Every page the settings stack can push.
enum SettingsRoute: Hashable {
    case dailyBrief
    case sources
    case source(Flows.Settings.Source.ID)
    case privacy
    case howStraight
    case voice
    case learned
    case account
}

/// The page each route shows, or nil while it isn't built (its row does nothing yet).
@MainActor
enum SettingsDestinations {
    struct Context {
        let data: any Flows.SettingsData
        let open: (SettingsRoute) -> Void
        let back: () -> Void
        /// Closes this route only if it is still the top page (an awaited action ending after the
        /// person already went back must not pop the page under it).
        var close: (SettingsRoute) -> Void = { _ in }
        /// Launcher stills only: ST-4 opens with this question already asked.
        var asking: SourcePage.Asking?
        /// ST-9's sign-out flow, when the host owns one (the demo hears it end); nil: the page's own sample.
        var signOut: (any SignOutFlowing)?
    }

    static func view(for page: SettingsRoute, in context: Context) -> AnyView? {
        switch page {
        case .dailyBrief, .sources, .source:
            first(page, in: context)
        case .privacy, .howStraight, .voice, .learned, .account:
            trust(page, in: context)
        }
    }

    static func isBuilt(_ page: SettingsRoute, data: any Flows.SettingsData) -> Bool {
        view(for: page, in: Context(data: data, open: { _ in }, back: {})) != nil
    }

    /// ST-2 … ST-4 (this half).
    private static func first(_ page: SettingsRoute, in context: Context) -> AnyView? {
        switch page {
        case .dailyBrief:
            AnyView(DailyBriefPage(data: context.data, back: context.back))
        case .sources:
            AnyView(SourcesPage(data: context.data, open: context.open, back: context.back))
        case let .source(id):
            context.data.source(id)?.hasPage == true
                ? AnyView(SourcePage(data: context.data, id: id, asking: context.asking, back: context.back) { context.close(.source(id)) })
                : nil
        default:
            nil
        }
    }
}

struct SettingsStack: View {
    let data: any Flows.SettingsData
    /// ST-1's back: where settings was opened from.
    var leave: () -> Void = {}
    /// Launcher stills only: ST-4 opens with this question already asked, once. Any move in the
    /// stack spends it, so pushing ST-4 again doesn't ask again.
    @State private var asking: SourcePage.Asking?
    @State private var path: [SettingsRoute]

    init(
        data: any Flows.SettingsData,
        path: [SettingsRoute] = [],
        asking: SourcePage.Asking? = nil,
        leave: @escaping () -> Void = {}
    ) {
        self.data = data
        self.leave = leave
        _asking = State(initialValue: asking)
        _path = State(initialValue: path)
    }

    var body: some View {
        NavigationStack(path: $path) {
            SettingsHubPage(data: data, open: open, back: leave)
                .navigationDestination(for: SettingsRoute.self) { page in
                    SettingsDestinations.view(for: page, in: context)
                }
        }
        .onChange(of: path) { asking = nil }
    }

    private var context: SettingsDestinations.Context {
        SettingsDestinations.Context(data: data, open: open, back: back, close: close, asking: asking)
    }

    private func open(_ page: SettingsRoute) {
        guard SettingsDestinations.isBuilt(page, data: data) else { return }
        path.append(page)
    }

    private func close(_ route: SettingsRoute) {
        guard path.last == route else { return }
        path.removeLast()
    }

    private func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
