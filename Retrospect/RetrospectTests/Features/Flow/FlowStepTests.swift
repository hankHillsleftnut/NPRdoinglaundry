@testable import Retrospect
import Testing

/// FLOW.host: the sample flow's edge table (SCREEN-MAP §3.1). Every step is reachable from the splash by
/// the table alone, every edge leads to a step that exists, nothing moves without a row, and the flow ends
/// at the last merged screen (questions has no forward row until privacy adds one).
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

    /// Steps merged ahead of the screens that lead to them: getting ready (ON-10) is reached from connect
    /// (ON-6), which isn't a step yet (privacy, #196, isn't either). Each starts its own walk until the
    /// missing screens add their rows; then this list empties.
    private static let waitingForAnIncomingRow: [FlowStep] = [.gettingReady]

    @Test("from the splash the table walks every step, in the app's order (islands waiting for a row aside)")
    func everyStepReachable() {
        let walks = [walk(from: .splash)] + Self.waitingForAnIncomingRow.map { walk(from: $0) }
        #expect(walks.flatMap(\.self) == FlowStep.allCases)
        // an island really has no row into it yet: when connect adds one, it leaves the list
        for island in Self.waitingForAnIncomingRow {
            #expect(FlowEdge.table.contains { $0.to == island } == false, "\(island)")
        }
    }

    @Test("getting ready ends the flow: 'made' has no row until the tease (ON-11) adds one")
    func endsAtGettingReady() {
        #expect(FlowEdge.table.contains { $0.from == .gettingReady } == false)
        #expect(FlowStep.next(from: .gettingReady, event: .episodeReady) == nil)
        let withTease = FlowEdge.table + [FlowEdge(.gettingReady, .episodeReady, .splash)]
        #expect(FlowStep.next(from: .gettingReady, event: .episodeReady, table: withTease) == .splash)
    }

    @Test("each edge of the table is the move next(from:event:) makes")
    func eachEdgeMoves() {
        #expect(FlowEdge.table.count == 3)
        for edge in FlowEdge.table {
            #expect(FlowStep.next(from: edge.from, event: edge.event) == edge.to, "\(edge.from) \(edge.event)")
        }
        #expect(FlowStep.next(from: .splash, event: .signedIn) == .inviteGate)
        #expect(FlowStep.next(from: .inviteGate, event: .ticketTorn) == .youreIn)
        #expect(FlowStep.next(from: .youreIn, event: .begin) == .questions)
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

    @Test("the flow ends at the last merged screen: the questions have no forward edge yet")
    func endsAtQuestions() {
        #expect(FlowEdge.table.contains { $0.from == .questions } == false)
        #expect(FlowStep.next(from: .questions, event: .questionsDone) == nil)
        // a later screen's PR adds one row, and the walk takes it
        let withPrivacy = FlowEdge.table + [FlowEdge(.questions, .questionsDone, .splash)]
        #expect(FlowStep.next(from: .questions, event: .questionsDone, table: withPrivacy) == .splash)
    }

    @Test("one edge per step and event, so every hand-off has exactly one place to go")
    func deterministic() {
        let rows = FlowEdge.table.map { "\($0.from.rawValue).\($0.event.rawValue)" }
        #expect(Set(rows).count == rows.count)
    }

    @Test("-Flow sample turns the host on; -FlowStart names a step; anything else is ignored")
    func launchArguments() {
        #expect(FlowLaunch.parse([]) == FlowLaunch())
        #expect(FlowLaunch.parse(["-Flow", "sample"]) == FlowLaunch(isRequested: true, start: nil))
        #expect(FlowLaunch.parse(["-Flow", "live"]).isRequested == false)
        #expect(FlowLaunch.parse(["-Flow"]).isRequested == false)
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "questions"]) == FlowLaunch(isRequested: true, start: .questions))
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "paywall"]).start == nil)
        #expect(FlowLaunch.parse(["-Screen", "PI0", "-State", "splash"]).isRequested == false)
    }
}
