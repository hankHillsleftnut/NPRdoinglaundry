@testable import Retrospect
import Testing

/// FLOW.host: the sample flow's edge table (SCREEN-MAP §3.1). Every step is reachable from the splash by
/// the table alone, every edge leads to a step that exists, nothing moves without a row, and the flow ends
/// at the last merged screen (privacy has no forward row until connect adds one).
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

    @Test("from the splash the table walks every step, in the app's order")
    func everyStepReachable() {
        #expect(walk(from: .splash) == FlowStep.allCases)
    }

    @Test("each edge of the table is the move next(from:event:) makes")
    func eachEdgeMoves() {
        #expect(FlowEdge.table.count == 5)
        for edge in FlowEdge.table {
            #expect(FlowStep.next(from: edge.from, event: edge.event) == edge.to, "\(edge.from) \(edge.event)")
        }
        #expect(FlowStep.next(from: .splash, event: .signedIn) == .inviteGate)
        #expect(FlowStep.next(from: .inviteGate, event: .ticketTorn) == .youreIn)
        #expect(FlowStep.next(from: .youreIn, event: .begin) == .questions)
        #expect(FlowStep.next(from: .questions, event: .questionsDone) == .privacy)
        #expect(FlowStep.next(from: .privacy, event: .back) == .questions)
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

    @Test("the flow ends at the last merged screen: privacy has no forward edge yet")
    func endsAtPrivacy() {
        #expect(FlowEdge.table.contains { $0.from == .privacy && $0.event != .back } == false)
        #expect(FlowStep.next(from: .privacy, event: .privacyDone) == nil)
        // connect's PR adds one row, and the walk takes it
        let withConnect = FlowEdge.table + [FlowEdge(.privacy, .privacyDone, .splash)]
        #expect(FlowStep.next(from: .privacy, event: .privacyDone, table: withConnect) == .splash)
    }

    @Test("back leaves a page only where one is drawn: privacy to the questions; nothing else goes back")
    func backOnlyFromPrivacy() {
        for step in FlowStep.allCases where step != .privacy {
            #expect(FlowStep.next(from: step, event: .back) == nil, "\(step)")
        }
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
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "privacy"]).start == .privacy)
        // the Core Flow scheme's reset
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "splash"]) == FlowLaunch(isRequested: true, start: .splash))
        #expect(FlowLaunch.parse(["-Flow", "sample", "-FlowStart", "paywall"]).start == nil)
        #expect(FlowLaunch.parse(["-Screen", "PI0", "-State", "splash"]).isRequested == false)
    }
}
