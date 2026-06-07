import Foundation
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

// SubscriptionPlan (.monthly / .yearly) is defined in PaywallView.swift.

/// Subscription backend. Uses RevenueCat when the SDK is present (add the
/// `purchases-ios` Swift Package), and falls back to a local mock so the paywall
/// flow is fully testable before the SDK/products exist.
///
/// SETUP when ready:
///  1. Xcode > Add Packages > https://github.com/RevenueCat/purchases-ios
///  2. Set `revenueCatAPIKey` below (RevenueCat dashboard > API keys, the public `appl_…`).
///  3. In App Store Connect create two auto-renewable subs in one group; map both
///     to a single entitlement named `pro` in RevenueCat (or change `entitlementID`).
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed = false
    @Published var monthlyPriceString = "$19.99"
    @Published var yearlyPriceString = "$239.99/y"
    @Published var isPurchasing = false
    @Published var lastError: String?

    private let revenueCatAPIKey = "appl_REPLACE_ME"
    private let entitlementID = "pro"

    func configure() {
        #if canImport(RevenueCat)
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: revenueCatAPIKey)
        Task { await refresh() }
        #endif
    }

    func refresh() async {
        #if canImport(RevenueCat)
        do {
            let info = try await Purchases.shared.customerInfo()
            isSubscribed = info.entitlements[entitlementID]?.isActive == true
            if let offering = try await Purchases.shared.offerings().current {
                if let m = offering.monthly { monthlyPriceString = m.storeProduct.localizedPriceString }
                if let y = offering.annual { yearlyPriceString = y.storeProduct.localizedPriceString + "/y" }
            }
        } catch { lastError = error.localizedDescription }
        #endif
    }

    func purchase(_ plan: SubscriptionPlan) async {
        isPurchasing = true
        defer { isPurchasing = false }
        #if canImport(RevenueCat)
        do {
            guard let offering = try await Purchases.shared.offerings().current else {
                lastError = "No offering configured"; return
            }
            let pkg = (plan == .monthly) ? offering.monthly : offering.annual
            guard let package = pkg else { lastError = "Plan unavailable"; return }
            let result = try await Purchases.shared.purchase(package: package)
            isSubscribed = result.customerInfo.entitlements[entitlementID]?.isActive == true
        } catch { lastError = error.localizedDescription }
        #else
        // Mock until RevenueCat is added.
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSubscribed = true
        #endif
    }

    func restore() async {
        #if canImport(RevenueCat)
        do {
            let info = try await Purchases.shared.restorePurchases()
            isSubscribed = info.entitlements[entitlementID]?.isActive == true
        } catch { lastError = error.localizedDescription }
        #else
        isSubscribed = true
        #endif
    }
}
