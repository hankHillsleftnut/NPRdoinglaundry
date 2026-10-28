//
//  PaywallModel.swift
//  PW.paywall, ON-12 "the plans are the buttons" (Paper p-J-0 22M4-0): the paywall's decisions, apart
//  from the view so they can be tested. Founder, 26 Oct night (screens/DECISIONS.md): both price buttons
//  are dummies that go on to first home as if subscribed; there is no "not now"; restore, privacy and
//  terms do nothing yet; the mini-player's play never replays the tease: it nudges the lit yearly plan
//  (scopes/PW.paywall.md §6a). The host hears `onDone` once with the plan chosen. Nothing here logs.
//
import Foundation
import Observation

@MainActor @Observable
final class PaywallModel {
    /// Which plan the person chose. There is no third way out (no "not now").
    enum Choice: Equatable {
        case monthly
        case yearly
    }

    /// The page's one life. `left` is terminal: nothing else fires.
    enum Phase: Equatable {
        /// Asking the seam for the plans (the sample answers at once; nothing is drawn meanwhile).
        case loading
        /// The plans are on screen.
        case offer(Flows.Offer)
        /// A plan was tapped; the seam is answering.
        case choosing(Choice, Flows.Offer)
        /// Moved on to first home.
        case left(Choice)
    }

    /// The collapsed tease in the mini-player at the top (Paper 22TR-0: paused).
    struct Tease: Equatable {
        let title: String
        let subline: String
        /// 0…1 of the episode played.
        let progress: Double

        /// Paper's words and line, verbatim (22TY-0, 22TX-0, 22TS-0 at 60%; DECISIONS 26 Oct night keeps them).
        static let paper = Tease(title: "the week you started", subline: "your first episode · 4:24 left", progress: 0.6)
    }

    private(set) var phase: Phase = .loading
    /// Counts the mini-player's play taps; the yearly plan nudges on each change.
    private(set) var nudges = 0
    let tease: Tease

    @ObservationIgnored private let paywall: any Flows.Paywall
    @ObservationIgnored private let onDone: (Choice) -> Void

    init(paywall: any Flows.Paywall, tease: Tease = .paper, onDone: @escaping (Choice) -> Void) {
        self.paywall = paywall
        self.tease = tease
        self.onDone = onDone
    }

    /// The plans, once loaded (also while one is being chosen, so the page keeps them on screen).
    var offer: Flows.Offer? {
        switch phase {
        case let .offer(offer), let .choosing(_, offer): offer
        case .loading, .left: nil
        }
    }

    /// Loads the plans once. A failure leaves the page empty: no failure state is drawn, and the sample
    /// never fails (the live billing PR brings a drawn state with it).
    func load() async {
        guard case .loading = phase else { return }
        if case let .success(offer) = await paywall.offer(), case .loading = phase {
            phase = .offer(offer)
        }
    }

    /// A plan button. The first tap counts; a second while the seam answers, or after leaving, does nothing.
    func choose(_ choice: Choice) async {
        guard case let .offer(offer) = phase else { return }
        phase = .choosing(choice, offer)
        let plan = choice == .yearly ? offer.yearly : offer.monthly
        switch await paywall.choose(plan) {
        case .subscribed:
            phase = .left(choice)
            onDone(choice)
        case .cancelled, .failed:
            // not reachable on the sample (dummy buttons); the plans stay and nothing is lost
            phase = .offer(offer)
        }
    }

    /// The mini-player's play: no replay (founder, 26 Oct night); the lit yearly plan nudges.
    func nudge() {
        guard offer != nil else { return }
        nudges += 1
    }
}
