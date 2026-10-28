import Foundation
@testable import Retrospect
import Testing

/// FLOW.coverage: the full demo's flow-completeness test (DECISIONS 27 Oct: every page connected, every
/// drawn control works on sample or is "not available yet"). `DemoFlowEdges` is the table
/// (`pipeline/flow-coverage.md` §5). On every base it must agree with the app's real navigation model:
/// the first run's `FlowEdge.table` and the launcher registry. Once the demo host lands
/// (`DemoFlowEdges.demoHostLanded`), nothing may be left planned, open or missing, and a walk from a launch
/// over working edges must reach every page.
@MainActor
struct DemoFlowEdgesTests {
    private let edges = DemoFlowEdges.edges
    private let pages = DemoPage.allCases.filter { !$0.isOrigin }

    // MARK: the table itself

    @Test("every row has its own id, and nothing leads into a place a walk starts from")
    func uniqueIDsAndOrigins() {
        let ids = edges.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids: \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
        for edge in edges {
            #expect(edge.to?.isOrigin != true, "\(edge.id) leads into \(String(describing: edge.to))")
            #expect(!edge.control.isEmpty, "\(edge.id) names no control")
        }
    }

    @Test("an edge that lands somewhere is a move, not a change in place; one in place lands nowhere")
    func inPlaceRowsLandNowhere() {
        for edge in edges where edge.via == .inPlace {
            #expect(edge.to == nil, "\(edge.id) is in place but names \(String(describing: edge.to))")
        }
        for edge in edges where edge.to == nil {
            #expect(edge.via == .inPlace, "\(edge.id) lands nowhere but isn't in place")
        }
    }

    @Test("every page has a way in and a way out (built or planned)")
    func noOrphans() {
        for page in pages {
            let ins = edges.filter { $0.to == page && $0.connects }
            let outs = edges.filter { $0.from == page && $0.connects }
            #expect(!ins.isEmpty, "\(page.rawValue) has no way in")
            if !DemoFlowEdges.noWayOut.contains(page) {
                #expect(!outs.isEmpty, "\(page.rawValue) has no way out")
            }
        }
    }

    @Test("every origin leads somewhere, and every page is the start of at least one row")
    func everyPageCounted() {
        for origin in DemoPage.allCases where origin.isOrigin {
            #expect(edges.contains { $0.from == origin && $0.to != nil }, "\(origin) leads nowhere")
        }
        for page in pages {
            #expect(edges.contains { $0.from == page }, "\(page.rawValue) lists no control")
        }
    }

    @Test("a row built only inside its group names the demo's join, and every cross-group route names a G0 case")
    func joinsNamed() {
        for edge in edges {
            if case let .route(kind) = edge.via {
                #expect(Self.g0Kinds.contains(kind), "\(edge.id) names \(kind), not a G0 route or sheet")
            }
        }
    }

    /// G0's `AppRoute.Kind` and `AppSheet.Kind` raw values: the real names, from the table itself.
    static let g0Kinds = Set(AppRoute.Kind.allCases.map(\.rawValue) + AppSheet.Kind.allCases.map(\.rawValue))

    @Test("what nobody plans yet is pinned: adding a missing row (or fixing one) is a visible change")
    func missingPinned() {
        let missing = edges.filter {
            if case .missing = $0.status {
                true
            } else {
                false
            }
        }.map(\.id)
        #expect(missing == ["F04", "S02", "S03", "P08", "T13", "T14", "X05a"], "flow-coverage.md §6 lists these")
    }

    // MARK: against the app's navigation model

    @Test("every first-run edge the flow has is a row here (no edge the table doesn't plan)")
    func flowEdgesAreRows() {
        let planned = Set(edges.compactMap(Self.flowKey))
        for edge in FlowEdge.table {
            let key = "\(edge.from.rawValue) \(edge.event.rawValue) \(edge.to.rawValue)"
            #expect(planned.contains(key), "FlowEdge.table has \(key), which flow-coverage.md doesn't plan")
        }
    }

    @Test("a first-run row whose two screens are merged steps is in the flow (a merged screen without its edge fails)")
    func mergedStepsAreJoined() {
        let live = Set(FlowEdge.table.map { "\($0.from.rawValue) \($0.event.rawValue) \($0.to.rawValue)" })
        for edge in edges {
            guard case let .flow(from, event, to) = edge.via, FlowStep(rawValue: from) != nil, FlowStep(rawValue: to) != nil,
                  FlowEvent(rawValue: event) != nil else { continue }
            #expect(live.contains("\(from) \(event) \(to)"), "\(edge.id): \(from) and \(to) are both steps, but \(event) doesn't move between them")
        }
    }

    @Test("a row marked merged on main really is in the flow's table")
    func mainFlowRowsAreLive() {
        let live = Set(FlowEdge.table.map { "\($0.from.rawValue) \($0.event.rawValue) \($0.to.rawValue)" })
        for edge in edges where edge.status == .main {
            if let key = Self.flowKey(edge) {
                #expect(live.contains(key), "\(edge.id) says main, but FlowEdge.table has no \(key)")
            }
        }
    }

    @Test("every screen in the launcher with a Paper id is a page here (a screen can't merge unjoined)")
    func launcherScreensArePages() {
        let known = Set(DemoPage.allCases.flatMap(\.launcherIDs))
        let paperLike = ScreenRegistry.allIDs.filter { $0.range(of: #"^[A-Z]{2}-\d+$"#, options: .regularExpression) != nil }
        for id in paperLike {
            #expect(known.contains(id), "-Screen \(id) is in the launcher but not in DemoFlowEdges (flow-coverage.md)")
        }
    }

    @Test("from a launch, the working edges reach the first run as far as main has it")
    func walkOnMain() {
        let reached = Self.walk(edges.filter(\.worksOnMain))
        for page in [DemoPage.splash, .inviteGate, .youreIn, .questions] {
            #expect(reached.contains(page), "\(page.rawValue) is not reached from a launch")
        }
    }

    @Test("a .pr row names an open PR: when a PR merges its rows become .main in the same change")
    func prRowsNameOpenPRs() {
        for edge in edges {
            if case let .pr(number) = edge.status {
                #expect(DemoFlowEdges.openPRs.contains(number), "\(edge.id) points at #\(number), which isn't in openPRs (merged? mark it .main)")
            }
        }
    }

    @Test("a cross-group row that works is built in G0's table, and a built one isn't left planned")
    func routeRowsMatchTheTable() {
        for edge in edges {
            guard case let .route(name) = edge.via else { continue }
            let built: Bool
            if let kind = AppRoute.Kind(rawValue: name) {
                built = AppRoutes.isBuilt(AppRouteTableTests.sample(kind))
            } else if let kind = AppSheet.Kind(rawValue: name) {
                built = AppRoutes.isBuilt(AppRouteTableTests.sample(kind))
            } else {
                Issue.record("\(edge.id) names \(name), not a G0 route or sheet")
                continue
            }
            if Self.works(edge) {
                #expect(built, "\(edge.id) works but \(name) isn't built in G0's table")
            }
            if case .planned = edge.status {
                #expect(!built, "\(edge.id) is planned but \(name) is built: mark the row with the PR that joins it")
            }
        }
    }

    @Test("a row joined by an open demo PR names its join")
    func demoRowsNameTheirJoin() {
        for edge in edges {
            if case let .pr(number) = edge.status, DemoFlowEdges.openPRs.contains(number) {
                #expect(edge.join != nil, "\(edge.id) is joined by #\(number) but names no join")
            }
        }
    }

    @Test("a first-run row that is live in the flow's table is marked .main")
    func liveFlowRowsAreMain() {
        let live = Set(FlowEdge.table.map { "\($0.from.rawValue) \($0.event.rawValue) \($0.to.rawValue)" })
        for edge in edges {
            if let key = Self.flowKey(edge), live.contains(key) {
                #expect(edge.status == .main, "\(edge.id) \(key) is live in FlowEdge.table but marked \(edge.status)")
            }
        }
    }

    @Test("every launcher id a page names still opens a screen (a deleted screen fails here)")
    func launcherIDsExist() {
        let registered = Set(ScreenRegistry.allIDs)
        for page in pages {
            for id in page.launcherIDs {
                #expect(registered.contains(id), "\(page.rawValue) names -Screen \(id), which the launcher no longer has")
            }
        }
    }

    @Test("walking the working edges from a launch: no dead end, and every pushed page or sheet has a way back")
    func noDeadEndsOrStrandedPages() {
        let working = edges.filter { Self.works($0) && $0.to != nil && $0.via != .inPlace }
        let reached = Self.walk(working)
        var deadEnds: Set<DemoPage> = []
        for page in reached where !page.isOrigin && !DemoFlowEdges.noWayOut.contains(page) && !DemoFlowEdges.tabRoots.contains(page) {
            if !working.contains(where: { $0.from == page }) {
                deadEnds.insert(page)
            }
        }
        #expect(deadEnds == Set(DemoFlowEdges.knownDeadEnds.keys), "dead ends: \(deadEnds.map(\.rawValue).sorted())")
        var stranded: Set<DemoPage> = []
        for edge in working where reached.contains(edge.from) && [.tap, .swipe].contains(edge.gesture) {
            guard edge.via == .stack || Self.isRoute(edge), let page = edge.to else { continue }
            let back = working.contains { $0.from == page && ($0.to == edge.from || $0.gesture == .back || $0.gesture == .dismiss) }
            if !back {
                stranded.insert(page)
            }
        }
        #expect(stranded == Set(DemoFlowEdges.knownNoWayBack.keys), "no way back: \(stranded.map(\.rawValue).sorted())")
    }

    // MARK: the demo gate (the demo's final PR flips `demoHostLanded`)

    @Test("the gate is flipped exactly when nothing is left to build")
    func gateMatchesTheTable() {
        let left = edges.filter { edge in
            switch edge.status {
            case .main, .notAvailableYet: false
            case .pr, .planned, .open, .missing: true
            }
        }
        if DemoFlowEdges.demoHostLanded {
            #expect(left.isEmpty, "the demo has landed but these rows aren't done: \(left.map(\.id))")
        } else {
            #expect(!left.isEmpty, "every row is done: flip DemoFlowEdges.demoHostLanded")
        }
    }

    @Test("with the demo landed, a walk over working edges reaches every page", .enabled(if: DemoFlowEdges.demoHostLanded))
    func demoReachesEverything() {
        let reached = Self.walk(edges.filter(\.worksOnMain))
        for page in pages where !reached.contains(page) {
            Issue.record("\(page.rawValue) can't be reached in the demo")
        }
    }

    @Test("with the demo landed, every first-run row is live in the flow", .enabled(if: DemoFlowEdges.demoHostLanded))
    func demoFlowComplete() {
        let live = Set(FlowEdge.table.map { "\($0.from.rawValue) \($0.event.rawValue) \($0.to.rawValue)" })
        for edge in edges {
            if let key = Self.flowKey(edge) {
                #expect(live.contains(key), "\(edge.id) \(key) is not in FlowEdge.table")
            }
        }
    }

    // MARK: helpers

    /// Works in the walk: merged on main, or built in an open PR this branch carries (`openPRs`).
    private static func works(_ edge: DemoEdge) -> Bool {
        switch edge.status {
        case .main: true
        case let .pr(number): DemoFlowEdges.openPRs.contains(number)
        case .planned, .notAvailableYet, .open, .missing: false
        }
    }

    private static func isRoute(_ edge: DemoEdge) -> Bool {
        if case .route = edge.via {
            return true
        }
        return false
    }

    private static func flowKey(_ edge: DemoEdge) -> String? {
        guard case let .flow(from, event, to) = edge.via else { return nil }
        return "\(from) \(event) \(to)"
    }

    /// Every page reachable from the origins over `edges`.
    private static func walk(_ edges: [DemoEdge]) -> Set<DemoPage> {
        var reached = Set(DemoPage.allCases.filter(\.isOrigin))
        var frontier = Array(reached)
        while let page = frontier.popLast() {
            for edge in edges where edge.from == page {
                if let next = edge.to, reached.insert(next).inserted {
                    frontier.append(next)
                }
            }
        }
        return reached
    }
}
