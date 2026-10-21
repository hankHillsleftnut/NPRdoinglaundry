import Foundation
import SwiftUI

// SubscriptionPlan (.monthly / .yearly) is defined in PaywallView.swift.

/// Subscription entitlement.
///
/// INVARIANT: `isSubscribed` may only become true from a StoreKit transaction that
/// the backend has validated. No purchase path exists yet, so `purchase` and
/// `restore` fail closed with a visible error rather than granting Pro. The only
/// other writer is a `#if DEBUG` launch-argument override, which cannot compile
/// into Release.
///
/// A previous version wrapped a RevenueCat implementation in `#if canImport(RevenueCat)`
/// with a mock `#else` branch. The SDK was never added to the package graph, so the
/// mock was the branch that compiled in every configuration — including Release —
/// and it granted the entitlement unconditionally. Do not reintroduce a
/// compile-time guard that can silently select an entitlement-granting branch.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isSubscribed = false
    @Published var monthlyPriceString = "$19.99/m"
    @Published var yearlyPriceString = "$239.99/y"
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    private static let unavailableMessage =
        "Subscriptions aren't available in this build yet. You have not been charged."

    #if DEBUG
    /// Launch argument that unlocks the subscribed UI state for development only.
    static let mockEntitlementArgument = "-MockProEntitlement"
    #endif

    func configure() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.mockEntitlementArgument) {
            isSubscribed = true
        }
        #endif
    }

    func purchase(_ plan: SubscriptionPlan) async {
        lastError = Self.unavailableMessage
    }

    func restore() async {
        lastError = Self.unavailableMessage
    }
}
