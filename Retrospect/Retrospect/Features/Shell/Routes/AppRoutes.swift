//
//  AppRoutes.swift
//  G0 (plan-glue.md §1c, §4): the one table that turns an `AppRoute`/`AppSheet` into a page, and the
//  environment a control asks before it becomes a button. It replaces YO-D14's registry lookup: the
//  launcher registry (#204) holds each group's LAUNCHER (its own stack and tab bar), which nests stacks
//  and drops ids when pushed; this table holds PAGES, built by their owning group, pushed onto the stack
//  the control is in. The launcher registry is unchanged.
//
//  How a group plugs in (its own file only, `Routes/Destinations/AppDestinations+<Group>.swift`):
//  build each page it owns in `page(for:in:)` / `sheet(for:in:)`, and drop its kind from `notBuilt`.
//  How a control uses it: `@Environment(\.appRouter) var router`, then `router.opener(.goal(id: id))`:
//  nil (a plain control, "not a button": consistency rule a) until the page is built AND something
//  above can push or present it. How a stack hosts it: a stack whose path is `[AppRoute]` is
//  `AppRouteStack`; a group's typed stack adds `case app(AppRoute)` to its own route, builds it with
//  `AppRoutes.page(for:in:)`, and installs `.appRoutePush { path.append(.app($0)) }` on its root.
//  Page data comes from the environment (each group's seam: `\.journalData` …), as in the launcher, so
//  the table never names sample data; the demo host (`-Flow demo`) injects the samples.
//
import SwiftUI

/// What a page or sheet built from the table is given.
/// `open` and `present` only act on built pages, the same rule as `AppRouter`, so a page wired straight
/// to them never pushes a blank page; a control asks `opener` / `presenter` to know if it is a button.
@MainActor
struct AppRouteContext {
    /// Leave this page (pop it and anything above it) or this sheet (dismiss it).
    let back: () -> Void
    /// Push another page onto the same stack (an unbuilt one is ignored); nil when nothing above can push.
    let open: ((AppRoute) -> Void)?
    /// Present a sheet over the shell (an unbuilt one is ignored); nil when nothing above can present.
    let present: ((AppSheet) -> Void)?

    init(back: @escaping () -> Void = {}, open: ((AppRoute) -> Void)? = nil, present: ((AppSheet) -> Void)? = nil) {
        self.back = back
        self.open = open.map(Self.builtOnly)
        self.present = present.map(Self.builtOnly)
    }

    private static func builtOnly(_ push: @escaping (AppRoute) -> Void) -> (AppRoute) -> Void {
        { route in
            if AppRoutes.isBuilt(route) {
                push(route)
            }
        }
    }

    private static func builtOnly(_ show: @escaping (AppSheet) -> Void) -> (AppSheet) -> Void {
        { sheet in
            if AppRoutes.isBuilt(sheet) {
                show(sheet)
            }
        }
    }

    /// The action for a control on this page that opens `route`, or nil (not built, or nothing can push).
    func opener(_ route: AppRoute) -> (() -> Void)? {
        guard let open, AppRoutes.isBuilt(route) else { return nil }
        return { open(route) }
    }

    /// The action for a control on this page that presents `sheet`, or nil.
    func presenter(_ sheet: AppSheet) -> (() -> Void)? {
        guard let present, AppRoutes.isBuilt(sheet) else { return nil }
        return { present(sheet) }
    }
}

/// One group's pages: built only by the owning group, in its own file.
@MainActor
protocol AppDestinationGroup {
    static var group: AppRouteGroup { get }
    /// The page for a route this group owns, or nil (a route it doesn't own, or one it hasn't built).
    static func page(for route: AppRoute, in context: AppRouteContext) -> AnyView?
    /// The sheet for a sheet this group owns, or nil.
    static func sheet(for sheet: AppSheet, in context: AppRouteContext) -> AnyView?
    /// The routes this group owns and hasn't built yet: their controls stay plain.
    static var notBuilt: Set<AppRoute.Kind> { get }
    /// The sheets this group owns and hasn't built yet.
    static var sheetsNotBuilt: Set<AppSheet.Kind> { get }
}

/// Namespace for the groups' destinations (one file each), so no name meets a group's own types
/// (settings already has a `SettingsDestinations` for its stack, #224).
enum AppDestinations {}

@MainActor
enum AppRoutes {
    /// One line per group, in `AppRouteGroup` order. A group's pages are added in its own file, never here.
    static let groups: [any AppDestinationGroup.Type] = [
        AppDestinations.Journal.self,
        AppDestinations.Podcasts.self,
        AppDestinations.Goals.self,
        AppDestinations.You.self,
        AppDestinations.Settings.self,
        AppDestinations.Outside.self,
        AppDestinations.Account.self,
    ]

    /// The group that owns `group`'s pages.
    static func destinations(_ group: AppRouteGroup) -> (any AppDestinationGroup.Type)? {
        groups.first { $0.group == group }
    }

    /// The page for `route`, from its owner only (another group building it is ignored, and fails the tests).
    static func page(for route: AppRoute, in context: AppRouteContext) -> AnyView? {
        guard isBuilt(route) else { return nil }
        return destinations(route.owner)?.page(for: route, in: context)
    }

    static func sheet(for sheet: AppSheet, in context: AppRouteContext) -> AnyView? {
        guard isBuilt(sheet) else { return nil }
        return destinations(sheet.owner)?.sheet(for: sheet, in: context)
    }

    /// Whether the owner has built the page (cheap: nothing is built to ask).
    static func isBuilt(_ route: AppRoute) -> Bool {
        guard let owner = destinations(route.owner) else { return false }
        return !owner.notBuilt.contains(route.kind)
    }

    static func isBuilt(_ sheet: AppSheet) -> Bool {
        guard let owner = destinations(sheet.owner) else { return false }
        return !owner.sheetsNotBuilt.contains(sheet.kind)
    }
}

// MARK: - What a control asks

/// What a control may do, from the nearest stack (push) and the shell (present). Outside any host both
/// are nil, so every opener is nil and the control stays plain (YO-D14, consistency rule a).
struct AppRouter {
    var push: ((AppRoute) -> Void)?
    var present: ((AppSheet) -> Void)?

    /// The action for a control that opens `route`, or nil: not built yet, or nothing above can push.
    @MainActor
    func opener(_ route: AppRoute) -> (() -> Void)? {
        guard let push, AppRoutes.isBuilt(route) else { return nil }
        return { push(route) }
    }

    /// The action for a control that presents `sheet`, or nil.
    @MainActor
    func presenter(_ sheet: AppSheet) -> (() -> Void)? {
        guard let present, AppRoutes.isBuilt(sheet) else { return nil }
        return { present(sheet) }
    }
}

extension EnvironmentValues {
    @Entry var appRouter = AppRouter()
}

extension View {
    /// Pages under this view push `AppRoute`s with `push` (a group's typed stack: `path.append(.app($0))`).
    func appRoutePush(_ push: @escaping (AppRoute) -> Void) -> some View {
        transformEnvironment(\.appRouter) { $0.push = push }
    }

    /// Sheets under this view are presented with `present` (the shell, G0b).
    func appSheetPresent(_ present: @escaping (AppSheet) -> Void) -> some View {
        transformEnvironment(\.appRouter) { $0.present = present }
    }
}

// MARK: - A stack of app routes

/// A stack for a page that has none of its own (JR-1 in the shell): `root`, then any `AppRoute` pushed
/// from inside it. Every page draws its own RTopBar, so the system bar is hidden; the edge swipe goes back.
struct AppRouteStack<Root: View>: View {
    @State private var path: [AppRoute]
    @ViewBuilder let root: () -> Root
    @Environment(\.appRouter) private var router

    init(path: [AppRoute] = [], @ViewBuilder root: @escaping () -> Root) {
        _path = State(initialValue: path)
        self.root = root
    }

    var body: some View {
        NavigationStack(path: $path) {
            root()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    AppRoutes.page(for: route, in: context(for: route))
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .appRoutePush { path.append($0) }
    }

    private func context(for route: AppRoute) -> AppRouteContext {
        AppRouteContext(back: { pop(to: route) }, open: { path.append($0) }, present: router.present)
    }

    /// Back from `route`: removes it and anything pushed above it (a late back never pops another page).
    private func pop(to route: AppRoute) {
        if let index = path.lastIndex(of: route) {
            path.removeSubrange(index...)
        }
    }
}
