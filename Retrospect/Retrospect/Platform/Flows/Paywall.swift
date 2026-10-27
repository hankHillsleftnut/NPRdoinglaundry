//
//  Paywall.swift
//  PW.paywall (ON-12): the seam the paywall reads. The page shows the plans this returns and reports
//  which one was chosen. In this phase only the sample answers (Features/FirstRun/Sample/SamplePaywall):
//  the plan buttons are dummies (founder, 26 Oct night: no purchase, no charge, no StoreKit), and a
//  choice comes back `.subscribed` at once. The live provider (StoreKit 2 with an appAccountToken and
//  a server check before anything unlocks) plugs in behind the same protocol later, separately approved.
//  Prices are display strings from the provider (StoreKit's `displayPrice` later): never literals in a view.
//
import Foundation
import Observation

extension Flows {
    /// One plan as the paywall shows it.
    struct Plan: Hashable, Sendable, Identifiable {
        enum Period: String, Hashable, Sendable {
            case month
            case year
        }

        let id: String
        /// The price as the store words it ("$24.99").
        let displayPrice: String
        let period: Period
    }

    /// What the paywall offers: the two plans and the yearly saving as worded ("save 20%").
    struct Offer: Hashable, Sendable {
        let monthly: Plan
        let yearly: Plan
        let saving: String
    }

    /// The answer to a chosen plan.
    enum Purchase: Hashable, Sendable {
        case subscribed
        case cancelled
        case failed(Failure)
    }

    /// The paywall's plans and what happens when one is chosen.
    @MainActor
    protocol Paywall: AnyObject {
        /// The plans to show.
        func offer() async -> Result<Offer, Failure>
        /// The person chose `plan`. The sample answers `.subscribed` and charges nothing.
        func choose(_ plan: Plan) async -> Purchase
    }
}
