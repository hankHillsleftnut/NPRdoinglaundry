//
//  ConnectModel.swift
//  CN.connect, ON-6 (Paper p-J-0 2190-0, "approved · from approvals · ON-6"): the connect page's
//  decisions, apart from the view so they can be tested. Retro asks to get to know you; each source
//  you connect fills the knows-you meter a step (founder decision 5: the meter reflects what is
//  connected). "continue" and "later" both go on to getting ready (decision 5); back returns to
//  privacy. The host hears `onDone` or `onBack` once, never both. Nothing here logs.
//
import Foundation
import Observation

@MainActor @Observable
final class ConnectModel {
    /// ON-6's place in the flow: 55% in Paper (21CF-0), arriving from privacy's 48%.
    static let progress = FlowProgress(from: PrivacyModel.progress.to, to: 0.55)

    /// How the page was left. Both exits go to getting ready (founder decision 5); the host may
    /// still want to know which was pressed.
    enum Exit: Equatable {
        case continued
        case later
    }

    /// Where the page is in its one life. `left` is terminal: a host that shows ON-6 again builds a
    /// fresh model.
    enum Phase: Equatable {
        /// On screen; any source can be connected.
        case ready
        /// One source's connect is on its way: a second connect waits for it (continue, later and
        /// back still work; a connect that lands after the page was left changes nothing here).
        case connecting(Flows.ConnectSource.ID)
        /// Moved on or backed out: nothing else fires.
        case left
    }

    private(set) var phase: Phase = .ready
    /// The last source that landed connected, for the announcement and the haptic.
    private(set) var lastConnected: Flows.ConnectSource?
    /// Counts each source that lands connected: the page's haptic and announcement follow it.
    private(set) var connections = 0

    @ObservationIgnored private let data: any Flows.Connect
    @ObservationIgnored private let onDone: (Exit) -> Void
    @ObservationIgnored private let onBack: () -> Void

    init(
        data: any Flows.Connect,
        onDone: @escaping (Exit) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.data = data
        self.onDone = onDone
        self.onBack = onBack
    }

    // MARK: Reads

    /// "on this iPhone", in the seam's order.
    var onThisIphone: [Flows.ConnectSource] {
        data.sources.filter { $0.group == .onThisIphone }
    }

    /// "your other apps", in the seam's order.
    var yourOtherApps: [Flows.ConnectSource] {
        data.sources.filter { $0.group == .yourOtherApps }
    }

    var knowsYou: Flows.KnowsYou {
        data.knowsYou
    }

    /// The meter's one line, as VoiceOver reads it when a source lands.
    var announcement: String? {
        lastConnected.map { "\($0.name) connected. \(Self.meterLabel)." }
    }

    // MARK: Page events

    /// "+ connect" on a row. One connect at a time, only for a source that isn't connected yet,
    /// never after the page was left.
    func connect(_ id: Flows.ConnectSource.ID) async {
        guard phase == .ready,
              let source = data.sources.first(where: { $0.id == id }),
              source.state == .available
        else { return }
        phase = .connecting(id)
        let outcome = await data.connect(id)
        // the page may have been left while the connect was out: nothing lands on a page that's gone
        guard phase == .connecting(id) else { return }
        phase = .ready
        if outcome == .connected {
            lastConnected = data.sources.first { $0.id == id } ?? source
            connections += 1
        }
    }

    /// "continue": on to getting ready.
    func continueOn() {
        leave(.continued)
    }

    /// "later": on to getting ready too (founder decision 5).
    func later() {
        leave(.later)
    }

    /// The back chevron: the host returns to privacy.
    func back() {
        guard phase != .left else { return }
        phase = .left
        onBack()
    }

    // MARK: Private

    private func leave(_ exit: Exit) {
        guard phase != .left else { return }
        phase = .left
        onDone(exit)
    }

    // MARK: Words (Paper 2190-0, verbatim; lowercase is the design system's)

    static let title = "i'd love to get to know you."
    static let body = "each one sharpens your episodes. i read, never post."
    /// The meter's label (21C2-0), the only one Paper draws (QUESTION Q2).
    static let meterLabel = "knows you a little"
    static let onThisIphoneLabel = "on this iPhone"
    static let yourOtherAppsLabel = "your other apps"
    static let continueTitle = "continue"
    static let laterTitle = "later"
    /// Read when the page arrives: where you are, then the title.
    static let arrival = "connect. \(title)"
}
