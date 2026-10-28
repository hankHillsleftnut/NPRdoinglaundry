import Foundation
@testable import Retrospect
import SwiftUI
import Testing

/// G0 (plan-glue.md §1c): the app route table. Every page or sheet one group opens in another has ONE
/// owner that builds it; a route nobody builds is listed by its owner as not built (its control stays
/// plain), never silently missing; no group builds another's page; and the release app names none of it
/// until the founder's wiring go (DECISIONS 27 Oct: the demo is debug, the release guard is unchanged).
@MainActor
struct AppRouteTableTests {
    /// One route per kind. Exhaustive: a new kind doesn't compile until it has a sample here.
    static func sample(_ kind: AppRoute.Kind) -> AppRoute {
        switch kind {
        case .entry: .entry(id: "entry-1")
        case .goal: .goal(id: "goal-1")
        case .youSource: .youSource(id: "source-1")
        case .whatIKnow: .whatIKnow
        case .whyThisIsHere: .whyThisIsHere(episodeID: "episode-1", lineID: "line-1")
        case .settingsHub: .settings(.hub)
        case .settingsDailyBrief: .settings(.dailyBrief)
        case .settingsSources: .settings(.sources)
        case .settingsSource: .settings(.source(id: "calendar"))
        case .settingsPrivacy: .settings(.privacy)
        case .settingsHowStraight: .settings(.howStraight)
        case .settingsVoice: .settings(.voice)
        case .settingsLearned: .settings(.learned)
        case .settingsAccount: .settings(.account)
        }
    }

    static func sample(_ kind: AppSheet.Kind) -> AppSheet {
        switch kind {
        case .brief: .brief(id: nil)
        case .episode: .episode(id: "episode-1")
        case .node: .node(id: "node-1")
        case .share: .share
        case .signOut: .signOut
        }
    }

    @Test("every group has exactly one destinations file in the table")
    func oneTablePerGroup() {
        // a loop, not `map(\.group)`: a key path on the existential metatype crashes the 6.2 compiler
        var groups: [AppRouteGroup] = []
        for destinations in AppRoutes.groups {
            groups.append(destinations.group)
        }
        #expect(groups.count == Set(groups).count, "a group is listed twice: \(groups.map(\.rawValue))")
        #expect(Set(groups) == Set(AppRouteGroup.allCases), "groups without a destinations file: \(Set(AppRouteGroup.allCases).subtracting(groups))")
    }

    @Test("every route kind maps back to itself and has an owner in the table")
    func kindsRoundTrip() {
        for kind in AppRoute.Kind.allCases {
            #expect(Self.sample(kind).kind == kind)
            #expect(AppRoutes.destinations(kind.owner) != nil)
        }
        for kind in AppSheet.Kind.allCases {
            #expect(Self.sample(kind).kind == kind)
            #expect(AppRoutes.destinations(kind.owner) != nil)
        }
    }

    @Test("a route is built by its owner or listed as not built by it: never missing, never both")
    func noMissingRoutes() {
        let context = AppRouteContext()
        for kind in AppRoute.Kind.allCases {
            guard let owner = AppRoutes.destinations(kind.owner) else { continue }
            let built = owner.page(for: Self.sample(kind), in: context) != nil
            let listed = owner.notBuilt.contains(kind)
            #expect(built != listed, "\(kind.rawValue): \(built ? "built and still listed as not built" : "not built and not listed (missing)")")
            #expect(AppRoutes.isBuilt(Self.sample(kind)) == built)
        }
        for kind in AppSheet.Kind.allCases {
            guard let owner = AppRoutes.destinations(kind.owner) else { continue }
            let built = owner.sheet(for: Self.sample(kind), in: context) != nil
            let listed = owner.sheetsNotBuilt.contains(kind)
            #expect(built != listed, "sheet \(kind.rawValue): \(built ? "built and still listed as not built" : "not built and not listed (missing)")")
            #expect(AppRoutes.isBuilt(Self.sample(kind)) == built)
        }
    }

    @Test("no group builds, or lists, a page another group owns (no duplicates)")
    func noDuplicateRoutes() {
        let context = AppRouteContext()
        for group in AppRoutes.groups {
            for kind in AppRoute.Kind.allCases where kind.owner != group.group {
                #expect(
                    group.page(for: Self.sample(kind), in: context) == nil,
                    "\(group.group.rawValue) builds \(kind.rawValue), owned by \(kind.owner.rawValue)"
                )
                #expect(!group.notBuilt.contains(kind), "\(group.group.rawValue) lists \(kind.rawValue), owned by \(kind.owner.rawValue)")
            }
            for kind in AppSheet.Kind.allCases where kind.owner != group.group {
                #expect(group.sheet(for: Self.sample(kind), in: context) == nil, "\(group.group.rawValue) builds sheet \(kind.rawValue)")
                #expect(!group.sheetsNotBuilt.contains(kind), "\(group.group.rawValue) lists sheet \(kind.rawValue)")
            }
        }
    }

    @Test("a control is a button only when its page is built and something above can open it")
    func openers() {
        var pushed: [AppRoute] = []
        var presented: [AppSheet] = []
        let outside = AppRouter()
        let hosted = AppRouter(push: { pushed.append($0) }, present: { presented.append($0) })
        for kind in AppRoute.Kind.allCases {
            let route = Self.sample(kind)
            // outside any stack: always plain (YO-D14)
            #expect(outside.opener(route) == nil)
            #expect((hosted.opener(route) != nil) == AppRoutes.isBuilt(route))
            hosted.opener(route)?()
        }
        for kind in AppSheet.Kind.allCases {
            let sheet = Self.sample(kind)
            #expect(outside.presenter(sheet) == nil)
            #expect((hosted.presenter(sheet) != nil) == AppRoutes.isBuilt(sheet))
            hosted.presenter(sheet)?()
        }
        #expect(pushed.allSatisfy { AppRoutes.isBuilt($0) })
        #expect(presented.allSatisfy { AppRoutes.isBuilt($0) })
        let builtRoutes = AppRoute.Kind.allCases.map(Self.sample).filter { AppRoutes.isBuilt($0) }
        #expect(pushed == builtRoutes)
    }

    @Test("a page's own open / present act only on built pages, the same rule as the router")
    func contextIsGated() {
        var pushed: [AppRoute] = []
        var presented: [AppSheet] = []
        let context = AppRouteContext(open: { pushed.append($0) }, present: { presented.append($0) })
        for kind in AppRoute.Kind.allCases {
            let route = Self.sample(kind)
            context.open?(route)
            #expect((context.opener(route) != nil) == AppRoutes.isBuilt(route))
            #expect(AppRouteContext().opener(route) == nil)
        }
        for kind in AppSheet.Kind.allCases {
            let sheet = Self.sample(kind)
            context.present?(sheet)
            #expect((context.presenter(sheet) != nil) == AppRoutes.isBuilt(sheet))
            #expect(AppRouteContext().presenter(sheet) == nil)
        }
        // an unbuilt page is never pushed (it would show a blank page with no back)
        #expect(pushed.allSatisfy { AppRoutes.isBuilt($0) })
        #expect(presented.allSatisfy { AppRoutes.isBuilt($0) })
    }

    // MARK: the release fence (pinned: only a founder-approved wiring PR changes this)

    /// The names the table adds. The release app must name none of them.
    static let tableNames = [
        "AppRoute", "AppSheet", "AppRoutes", "AppRouter", "AppRouteContext", "AppRouteGroup", "AppRouteStack",
        "AppDestinations", "AppDestinationGroup", "appRouter", "appRoutePush", "appSheetPresent",
    ]

    /// Where the table may be named before the wiring go: the dark V2 folders (ReleaseRouteTableTests,
    /// #205), the debug launcher and the debug demo host (`-Flow demo`, Sandbox/Demo: every Sandbox file is DEBUG-only, ReleaseRouteTableTests). The release root
    /// (RetrospectApp, NewAppRoot, FirstRunRoute, LiveJournalRoot) is outside all of them. Features/Player
    /// and Features/Account are core (the release app's tease and sign-out), so they stay outside too:
    /// their controls get openers as plain closures from the dark wrappers in the destinations files.
    static let mayName = [
        "Features/Shell/", "Features/Entries/", "Features/Podcasts/", "Features/You/", "Features/Settings/",
        "Features/Goals/", "Features/Outside/", "Features/Launcher/", "Sandbox/",
    ]

    @Test("the release app never names the route table (it is debug-demo only until the wiring go)")
    func releaseNeverSeesTheTable() throws {
        let app = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Retrospect", isDirectory: true)
        let base = app.standardizedFileURL.path + "/"
        let walker = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)
        var files: [(path: String, text: String)] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            files.append((url.standardizedFileURL.path.replacingOccurrences(of: base, with: ""), text))
        }
        // the walk really read the app, release root included (a wrong root would pass on nothing)
        #expect(files.count > 100, "only \(files.count) Swift files under \(app.path)")
        for root in ["RetrospectApp.swift", "Features/SignIn/NewAppRoot.swift", "Features/Journal/LiveJournalRoot.swift"] {
            #expect(files.contains { $0.path.hasSuffix(root) }, "\(root) not found")
        }
        // the release root never moves into a folder allowed to name the table
        for file in files where ["RetrospectApp.swift", "NewAppRoot.swift", "FirstRunRoute.swift", "LiveJournalRoot.swift"]
            .contains(where: { file.path.hasSuffix($0) }) {
            #expect(!Self.mayName.contains { file.path.hasPrefix($0) }, "\(file.path) sits in a folder that may name the table")
        }
        let pattern = try NSRegularExpression(pattern: #"\b("# + Self.tableNames.joined(separator: "|") + #")\b"#)
        var leaks: [String] = []
        for file in files where !Self.mayName.contains(where: { file.path.hasPrefix($0) }) {
            // code only: comments don't mount anything
            let code = file.text.split(separator: "\n", omittingEmptySubsequences: false)
                // a `//` at the line's start or after a space only (not the one inside "https://…")
                .map { line in
                    line.range(of: #"(^|\s)//"#, options: .regularExpression).map { String(line[..<$0.lowerBound]) } ?? String(line)
                }
                .joined(separator: "\n")
            let range = NSRange(code.startIndex..., in: code)
            if let match = pattern.firstMatch(in: code, range: range), let name = Range(match.range(at: 1), in: code) {
                leaks.append("\(file.path) names \(code[name])")
            }
        }
        #expect(leaks.isEmpty, "the route table is reachable outside the dark folders (wiring PR only):\n\(leaks.joined(separator: "\n"))")
    }
}
