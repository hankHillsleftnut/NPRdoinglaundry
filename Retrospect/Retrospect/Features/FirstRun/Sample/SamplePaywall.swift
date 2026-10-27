//
//  SamplePaywall.swift
//  PW.paywall: ON-12 on sample data. Paper's prices (22MO-0 "$24.99", 22ML-0 "$239.99", 22MJ-0
//  "save 20%"; DECISIONS 7). The plan buttons are dummies (founder, 26 Oct night): `choose` answers
//  `.subscribed` at once, charges nothing, asks nothing of Apple, keeps nothing.
//
import Foundation

/// The launcher's ON-12 states (`-Screen first-run -State paywall|paywall-still`).
enum PaywallScenario: String, CaseIterable {
    /// The paywall as the flow shows it after the tease.
    case paywall
    /// The same frame, held for the 1:1 comparison with Paper (nothing leaves the page).
    case paywallStill = "paywall-still"
}

@MainActor
final class SamplePaywall: Flows.Paywall {
    static let offer = Flows.Offer(
        monthly: Flows.Plan(id: "sample.monthly", displayPrice: "$24.99", period: .month),
        yearly: Flows.Plan(id: "sample.yearly", displayPrice: "$239.99", period: .year),
        saving: "save 20%"
    )

    /// How many plans were chosen (tests only read it; nothing is kept between launches).
    private(set) var choices = 0

    func offer() async -> Result<Flows.Offer, Flows.Failure> {
        .success(Self.offer)
    }

    func choose(_: Flows.Plan) async -> Flows.Purchase {
        choices += 1
        return .subscribed
    }
}
