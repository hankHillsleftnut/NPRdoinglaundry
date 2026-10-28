@testable import Retrospect
import Testing

/// FLOW.host: the sample flow's edge table (SCREEN-MAP §3.1). Every step is reachable from the splash by
/// the table alone, every edge leads to a step that exists, nothing moves without a row, and the flow ends
/// at the last merged screen (getting ready has no forward row until the tease adds one).
struct FlowStepTests {
    /// Every step the table reaches from `start`, in the order it reaches them.
    private func walk(from start: FlowStep, table: [FlowEdge] = FlowEdge.table) -> [FlowStep] {
        var reached = [start]
        var current = start
        while let edge = table.first(where: { $0.from == current }), !reached.contains(edge.to) {
            reached.append(edge.to)
            current = edge.to
        }
        return reached
    }

    /// Steps merged ahead of the screens that lead to them (each starts its own walk until the missing
    /// screens add their rows). Empty since FLOW.edges joined privacy to connect: one walk, splash to
    /// getting ready.
    private static let waitingForAnIncomingRow: [FlowStep] = []

    @Test("from the splash the table walks every step, in the app's order (islands waiting for a row aside)")
    func everyStepReachable() {
        let walks = [walk(from: .splash)] + Self.waitingForAnIncomingRow.map { walk(from: $0) }
        #expect(walks.flatMap(\.self) == FlowStep.allCases)
        // an island really has no row into it yet: when connect adds one, it leaves the list
        for island in Self.waitingForAnIncomingRow {
            #expect(FlowEdge.table.contains { $0.to == island } == false, "\(island)")
        }
    }

    @Test("the tease ends the flow: its end has no row until the paywall (ON-12) adds one")
    func endsAtTease() {
        #expect(FlowStep.next(from: .gettingReady, event: .episodeReady) == .tease)
        #expect(FlowEdge.table.contains { $0.from == .tease } == false)
        #expect(FlowStep.next(from: .tease, event: .teaseEnded) == nil)
        let withPaywall = FlowEdge.table + [FlowEdge(.tease, .teaseEnded, .splash)]
        #expect(FlowStep.next(from: .tease, event: .teaseEnded, table: withPaywall) == .splash)
    }

    @Test("each edge of the table is the move next(from:event:) makes")
    func eachEdgeMoves() {
        #expect(FlowEdge.table.count == 9)
        for edge in FlowEdge.table {
            #expect(FlowStep.next(from: edge.from, event: edge.event) == edge.to, "\(edge.from) \(edge.event)")
        }
        #expect(FlowStep.next(from: .splash, event: .signedIn) == .inviteGate)
        #expect(FlowStep.next(from: .inviteGate, event: .ticketTorn) == .youreIn)
        #expect(FlowStep.next(from: .youreIn, event: .begin) == .questions)
        #expect(FlowStep.next(from: .questions, event: .questionsDone) == .privacy)
        #expect(FlowStep.next(from: .privacy, event: .privacyDone) == .connect)
        #expect(FlowStep.next(from: .privacy, event: .back) == .questions)
        #expect(FlowStep.next(from: .connect, event: .connectDone) == .gettingReady)
        #expect(FlowStep.next(from: .connect, event: .connectBack) == .privacy)
        #expect(FlowStep.next(from: .gettingReady, event: .episodeReady) == .tease)
    }

    @Test("connect (ON-6): continue and later both go on to getting ready; back returns to privacy")
    func connectEdges() {
        #expect(FlowStep.next(from: .connect, event: .connectDone) == .gettingReady)
        #expect(FlowStep.next(from: .connect, event: .connectBack) == .privacy)
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "connect"]).start == .connect)
    }

    @Test("an event with no row moves nothing: no skipping ahead, no going back through the host")
    func noRowNoMove() {
        let rows = Set(FlowEdge.table.map { "\($0.from.rawValue).\($0.event.rawValue)" })
        for step in FlowStep.allCases {
            for event in FlowEvent.allCases where !rows.contains("\(step.rawValue).\(event.rawValue)") {
                #expect(FlowStep.next(from: step, event: event) == nil, "\(step) \(event)")
            }
        }
    }

    @Test("back leaves a page only where one is drawn: privacy to the questions, connect to privacy")
    func backOnlyWhereDrawn() {
        for step in FlowStep.allCases where step != .privacy {
            #expect(FlowStep.next(from: step, event: .back) == nil, "\(step)")
        }
        for step in FlowStep.allCases where step != .connect {
            #expect(FlowStep.next(from: step, event: .connectBack) == nil, "\(step)")
        }
    }

    @Test("one edge per step and event, so every hand-off has exactly one place to go")
    func deterministic() {
        let rows = FlowEdge.table.map { "\($0.from.rawValue).\($0.event.rawValue)" }
        #expect(Set(rows).count == rows.count)
    }

    @Test("debug: a launch with no arguments (the home-screen icon) opens the sample flow; any explicit flag wins")
    func iconLaunchOpensTheSampleFlow() {
        let app = "/private/var/containers/Bundle/Application/X/Retrospect.app/Retrospect"
        // the icon: no arguments, not a test run
        #expect(FlowLaunch.resolve([app], environment: [:]) == FlowLaunch(isRequested: true, start: nil))
        // explicit arguments win
        #expect(FlowLaunch.resolve([app, "-Flow", "live"], environment: [:]).isRequested == false)
        #expect(FlowLaunch.resolve([app, "-Flow", "sample", "-FlowStart", "questions"], environment: [:]) == FlowLaunch(isRequested: true, start: .questions))
        #expect(FlowLaunch.resolve([app, "-Screen", "PI0", "-State", "splash"], environment: [:]).isRequested == false)
        #expect(FlowLaunch.resolve([app, "-DesignLab"], environment: [:]).isRequested == false)
        #expect(FlowLaunch.resolve([app, "-OldHome"], environment: [:]).isRequested == false)
        // Xcode's own run arguments mean the launch came from Xcode's plain scheme: the live root, as before
        #expect(FlowLaunch.resolve([app, "-NSDocumentRevisionsDebugMode", "YES"], environment: [:]).isRequested == false)
        // a test host never opens it by default
        #expect(FlowLaunch.resolve([app], environment: ["XCTestConfigurationFilePath": "/x"]).isRequested == false)
        #expect(FlowLaunch.resolve([app], environment: ["XCTestSessionIdentifier": "x"]).isRequested == false)
        // and this test process itself (a test host) is not in the sample flow
        #expect(FlowLaunch.current.isRequested == false)
    }

    @Test("-Flow sample turns the host on; -FlowStart names a step; anything else is ignored")
    func launchArguments() {
        #expect(FlowLaunch.parse([]) == FlowLaunch())
        #expect(FlowLaunch.parse(["-Flow", "sample"]) == FlowLaunch(isRequested: true, start: nil))
        #expect(FlowLaunch.parse(["-Flow", "live"]).isRequested == false)
        #expect(FlowLaunch.parse(["-Flow"]).isRequested == false)
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "questions"]) == FlowLaunch(isRequested: true, start: .questions))
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "privacy"]).start == .privacy)
        // the Core Flow scheme's reset
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "splash"]) == FlowLaunch(isRequested: true, start: .splash))
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "paywall"]).start == nil)
        #expect(FlowLaunch.parse(["-Screen", "PI0", "-State", "splash"]).isRequested == false)
    }
}
