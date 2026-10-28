//
//  FlowPlan.swift
//  FLOW.edges: the whole first run as the map draws it (pipeline/screens/SCREEN-MAP.md §3.1, founder
//  decisions 3, 5, 7, 9, 10, 11), splash to first home, including the screens that aren't built yet. The
//  host never moves on this plan: it moves only on `FlowEdge.table`, whose steps are merged screens. The
//  flow tests hold the two together: every live row is planned, and every planned edge between two merged
//  screens is live, so a screen that merges without its edges fails, and an edge into a screen that isn't
//  built simply isn't there (the flow ends at the last merged screen; no placeholder pages). Debug only.
//
#if DEBUG
import Foundation

/// Every first-run screen, in the order of the app. A screen is a flow step once it merges (same name).
enum FirstRunScreen: String, CaseIterable, Sendable {
    /// ON-1/2 splash + sign-in.
    case splash
    /// PI1 + PI2 up to the tear.
    case inviteGate
    /// PI2 "you're in".
    case youreIn
    /// ON-3–9 the questions.
    case questions
    /// ON-5 privacy.
    case privacy
    /// ON-6 connect.
    case connect
    /// ON-10 getting ready.
    case gettingReady
    /// ON-11 the tease (the player sheet).
    case tease
    /// ON-12 the paywall.
    case paywall
    /// ON-13 first home: the end of the first run.
    case firstHome

    /// The flow step, once the screen is merged and mounted in the host.
    var step: FlowStep? {
        FlowStep(rawValue: rawValue)
    }
}

/// One planned hand-off. `event` names the `FlowEvent` case the screen's PR uses (a string, so a screen
/// that isn't built needs no case yet).
struct PlannedEdge: Equatable, Sendable {
    let from: FirstRunScreen
    let event: String
    let to: FirstRunScreen
    /// The SCREEN-MAP §3.1 row (or the decision) it comes from.
    let source: String

    init(_ from: FirstRunScreen, _ event: String, _ to: FirstRunScreen, _ source: String) {
        self.from = from
        self.event = event
        self.to = to
        self.source = source
    }
}

enum FlowPlan {
    /// Splash to first home. Back edges only where a page draws a back that leaves it; getting ready has
    /// no back (decision 10), the paywall draws none, first home is the end. The tease's collapse (row 39)
    /// rides on `teaseEnded` (the provisional default in DECISIONS). Not planned: the splash's
    /// terms/privacy and the paywall's restore (inert).
    static let edges: [PlannedEdge] = [
        PlannedEdge(.splash, "signedIn", .inviteGate, "row 7; decisions 6, 12"),
        PlannedEdge(.inviteGate, "ticketTorn", .youreIn, "row 12"),
        PlannedEdge(.youreIn, "begin", .questions, "row 13"),
        PlannedEdge(.questions, "questionsDone", .privacy, "row 19"),
        PlannedEdge(.privacy, "privacyDone", .connect, "row 20; decision 3"),
        PlannedEdge(.privacy, "back", .questions, "row 23"),
        PlannedEdge(.connect, "connectDone", .gettingReady, "rows 29, 30; decision 5 (continue or later)"),
        PlannedEdge(.connect, "connectBack", .privacy, "row 32"),
        PlannedEdge(.gettingReady, "episodeReady", .tease, "row 34; decision 11"),
        PlannedEdge(.tease, "teaseEnded", .paywall, "row 38; decision 11 (the 10 s mark)"),
        PlannedEdge(.paywall, "subscribed", .firstHome, "row 41; decisions 7 + 26 Oct night (either price, no 'not now')"),
    ]

    /// Screens with no way back through the host (no back drawn, or none by decision).
    static let noBack: [FirstRunScreen] = [.splash, .inviteGate, .youreIn, .gettingReady, .tease, .paywall, .firstHome]

    /// Planned edges between two merged screens that `table` lacks (or whose event has no `FlowEvent` case):
    /// a merged screen with a way out that goes nowhere. Empty when the host is whole.
    static func missing(from table: [FlowEdge] = FlowEdge.table, steps: [FlowStep] = FlowStep.allCases) -> [PlannedEdge] {
        edges.filter { edge in
            guard let from = edge.from.step, let to = edge.to.step, steps.contains(from), steps.contains(to) else { return false }
            guard let event = FlowEvent(rawValue: edge.event) else { return true }
            return !table.contains(FlowEdge(from, event, to))
        }
    }

    /// Rows of `table` the plan doesn't draw: a move the map doesn't have. Empty when the host is honest.
    static func unplanned(in table: [FlowEdge] = FlowEdge.table) -> [FlowEdge] {
        table.filter { row in
            !edges.contains { $0.from.rawValue == row.from.rawValue && $0.event == row.event.rawValue && $0.to.rawValue == row.to.rawValue }
        }
    }
}
#endif
