//
//  SampleConnect.swift
//  CN.connect: ON-6 on sample data. The rows are the founder's list (decision 5: google, health,
//  calendar, contacts) as far as Paper draws them (2190-0): calendar (already connected), health and
//  google, with Paper's words and symbols. Contacts waits for its drawing (QUESTION Q1). A connect
//  lands at once: Paper draws a row at rest and a row connected, nothing in between (Q3). Nothing
//  leaves the phone and nothing is asked of iOS. Debug builds only (sandbox fence, #205): the live
//  source plugs in behind `Flows.Connect`.
//
#if DEBUG
import Foundation
import Observation

/// The launcher's ON-6 state (`-Screen first-run -State connect`).
enum ConnectScenario: String, CaseIterable {
    /// Calendar connected, health and google to connect (Paper 2190-0).
    case connect
    /// Every sample source connected: the meter at 3 of 6 and continue showing (QA: the state past
    /// 50% without tapping). 4–6 of 6 need sources Paper doesn't draw yet (founder Q1).
    case connectAll = "connect-3of6"
}

@MainActor
@Observable
final class SampleConnect: Flows.Connect {
    /// Paper's meter is `c:knows-you-meter/1-of-6`: six steps, one per source it was drawn for.
    static let meterSteps = 6

    /// Paper 2190-0's rows in the founder's list, in Paper's order.
    static let rows: [Flows.ConnectSource] = [
        Flows.ConnectSource(
            id: "apple_calendar",
            name: "calendar",
            purpose: "your days, and who's in them",
            symbol: "calendar",
            group: .onThisIphone,
            kind: .onDevice,
            state: .connected
        ),
        Flows.ConnectSource(
            id: "apple_health",
            name: "health",
            purpose: "sleep, steps and workouts",
            symbol: "heart",
            group: .onThisIphone,
            kind: .onDevice,
            state: .available
        ),
        Flows.ConnectSource(
            id: "google",
            name: "google",
            purpose: "calendar, gmail and drive",
            symbol: "envelope",
            group: .yourOtherApps,
            kind: .account,
            state: .available
        ),
    ]

    private(set) var sources: [Flows.ConnectSource]
    /// Ids `connect` refuses, so a test can walk the not-connected path. Empty in the app.
    @ObservationIgnored private let refuses: Set<String>
    /// How many connects were asked for (tests).
    @ObservationIgnored private(set) var connectCalls = 0

    init(scenario: ConnectScenario = .connect, refuses: Set<String> = []) {
        sources = scenario == .connectAll ? Self.rows.map { row in
            var row = row
            row.state = .connected
            return row
        } : Self.rows
        self.refuses = refuses
    }

    var knowsYou: Flows.KnowsYou {
        Flows.KnowsYou(filled: sources.count(where: { $0.state == .connected }), steps: Self.meterSteps)
    }

    func connect(_ id: Flows.ConnectSource.ID) async -> Flows.ConnectOutcome {
        connectCalls += 1
        guard !refuses.contains(id), let index = sources.firstIndex(where: { $0.id == id }) else {
            return .notConnected
        }
        sources[index].state = .connected
        return .connected
    }
}
#endif
