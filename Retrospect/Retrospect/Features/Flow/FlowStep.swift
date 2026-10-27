//
//  FlowStep.swift
//  FLOW.host (PR 0 of the screens loop): the sample flow's steps and the one table that says where each
//  hand-off goes (pipeline/screens/SCREEN-MAP.md §3.1). Only merged screens are steps; a step with no row
//  for an event stays where it is, so the flow simply ends at the last merged screen. Each later screen PR
//  adds its case here and its rows to `FlowEdge.table`, exactly as `FlowPlan.edges` (FLOW.edges) lists them;
//  the flow tests fail a merged screen whose planned edges are missing. Debug builds only.
//
#if DEBUG
import Foundation

/// The sample flow's steps, in the order of the app.
enum FlowStep: String, CaseIterable, Codable, Sendable {
    /// ON-1/2: the splash and Sign in with Apple (PI0).
    case splash
    /// PI1 + PI2 up to the tear: the typed ticket, the print and the tear.
    case inviteGate
    /// PI2 "you're in", until "begin". The same page as the gate (the ticket is one instance).
    case youreIn
    /// ON-3–9: the questions (#190).
    case questions
    /// ON-5: privacy (#196). Moves on when Retro finishes reading (decision 3); its row to connect (ON-6)
    /// lands with connect, so until then the flow ends here.
    case privacy
    /// ON-10: getting ready (GR.ready). Reached from connect (ON-6) once connect is a step; until
    /// then `-FlowStart gettingReady` opens it.
    case gettingReady
}

/// A screen's hand-off to the host. Moves inside a screen (a failed sign-in, a wrong code, back between
/// questions) stay in that screen's model and never reach the host.
enum FlowEvent: String, CaseIterable, Sendable {
    /// PI0: the sample sign-in succeeded.
    case signedIn
    /// PI2: the stub came away; the ticket is spent.
    case ticketTorn
    /// PI2: "begin".
    case begin
    /// ON-3–9: every question answered.
    case questionsDone
    /// ON-5: Retro finished reading, or a tap moved on early (decision 3).
    case privacyDone
    /// A page's own back chevron that leaves the page (ON-5 back to the last question). Back between
    /// questions stays inside ON-3–9.
    case back
    /// ON-10: the first episode is made. Its edge to the tease (ON-11, SCREEN-MAP §3.1 row 34) lands
    /// with the tease; until then the flow ends at getting ready.
    case episodeReady
}

/// One edge of the flow: `from` hears `event` and moves to `to`.
struct FlowEdge: Equatable, Sendable {
    let from: FlowStep
    let event: FlowEvent
    let to: FlowStep

    init(_ from: FlowStep, _ event: FlowEvent, _ to: FlowStep) {
        self.from = from
        self.event = event
        self.to = to
    }

    /// Every edge between merged screens, with its SCREEN-MAP §3.1 row (`FlowPlan.edges` is the whole
    /// first run). `privacy` has no forward row yet: the flow ends there (connect adds the next one).
    static let table: [Self] = [
        Self(.splash, .signedIn, .inviteGate), // 7
        Self(.inviteGate, .ticketTorn, .youreIn), // 12
        Self(.youreIn, .begin, .questions), // 13
        Self(.questions, .questionsDone, .privacy), // 19
        Self(.privacy, .back, .questions), // 23
    ]
}

extension FlowStep {
    /// Where `event` moves the flow from `step`; nil when the table has no such edge (the step stays).
    static func next(from step: Self, event: FlowEvent, table: [FlowEdge] = FlowEdge.table) -> Self? {
        table.first { $0.from == step && $0.event == event }?.to
    }
}
#endif
