@testable import Retrospect
import Testing

/// FLOW.edges: the live table against the whole first-run plan (SCREEN-MAP §3.1). A merged screen with a
/// missing edge, an edge the map doesn't draw, a step out of the app's order, or a way back the founder
/// ruled out all fail here; an edge into a screen that isn't built is simply absent (the flow ends).
struct FlowPlanTests {
    @Test("every step is a first-run screen, in the plan's order (a step slotted in the wrong place fails)")
    func stepsFollowThePlan() {
        let screens = FlowStep.allCases.map { FirstRunScreen(rawValue: $0.rawValue) }
        #expect(screens.allSatisfy { $0 != nil })
        let order = screens.compactMap { $0.flatMap { FirstRunScreen.allCases.firstIndex(of: $0) } }
        #expect(order == order.sorted())
    }

    @Test("every live row is a planned edge: nothing moves where the map doesn't draw a move")
    func liveRowsArePlanned() {
        #expect(FlowPlan.unplanned().isEmpty, "\(FlowPlan.unplanned())")
        // guard on: a row the map doesn't draw is caught
        #expect(FlowPlan.unplanned(in: FlowEdge.table + [FlowEdge(.privacy, .back, .splash)]).count == 1)
    }

    @Test("every planned edge between two merged screens is live, with a real event")
    func mergedEdgesAreLive() {
        #expect(FlowPlan.missing().isEmpty, "\(FlowPlan.missing().map { "\($0.from) \($0.event) (\($0.source))" })")
        // guard on: drop privacy's back and the plan asks for it
        let withoutBack = FlowEdge.table.filter { $0 != FlowEdge(.privacy, .back, .questions) }
        #expect(FlowPlan.missing(from: withoutBack).map(\.event) == ["back"])
        // and a merged screen with no edges at all is caught (as if privacy were mounted without its rows)
        let withoutPrivacy = FlowEdge.table.filter { $0.from != .privacy && $0.to != .privacy }
        #expect(FlowPlan.missing(from: withoutPrivacy).count == 2)
    }

    @Test("a step whose next screen isn't built has no forward row: the flow ends there, nothing is drawn")
    func unbuiltNextEnds() {
        let built = Set(FlowStep.allCases.map(\.rawValue))
        for edge in FlowPlan.edges where edge.from.step != nil && !built.contains(edge.to.rawValue) {
            let event = FlowEvent(rawValue: edge.event)
            if let event, let from = edge.from.step {
                #expect(FlowStep.next(from: from, event: event) == nil, "\(edge.from) \(edge.event)")
            }
        }
        // today: privacy's 'done' waits for connect (ON-6, #199)
        #expect(FlowStep.next(from: .privacy, event: .privacyDone) == nil)
    }

    @Test("no way back through the host where none is drawn or decided (getting ready: decision 10)")
    func noBackWhereRuledOut() {
        for screen in FlowPlan.noBack {
            #expect(FlowPlan.edges.contains { $0.from == screen && $0.event == "back" } == false, "\(screen)")
            if let step = screen.step {
                #expect(FlowStep.next(from: step, event: .back) == nil, "\(screen)")
            }
        }
    }

    @Test("the plan runs splash to first home: every screen reached, first home is the end")
    func planIsWhole() {
        var reached: [FirstRunScreen] = [.splash]
        var current = FirstRunScreen.splash
        while let edge = FlowPlan.edges.first(where: { $0.from == current && $0.event != "back" }) {
            reached.append(edge.to)
            current = edge.to
        }
        #expect(reached == FirstRunScreen.allCases)
        #expect(FlowPlan.edges.contains { $0.from == .firstHome } == false)
        // one place to go per screen and event
        let pairs = FlowPlan.edges.map { "\($0.from.rawValue).\($0.event)" }
        #expect(Set(pairs).count == pairs.count)
    }
}
