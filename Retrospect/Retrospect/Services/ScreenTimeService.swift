//
//  ScreenTimeService.swift
//  Retrospect
//
//  Full-featured Screen Time integration service.
//  Manages authorization, daily monitor scheduling, data reading from
//  the shared App Group, and backend syncing for the AI analysis pipeline.
//

import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var authorizationError: String?
    @Published var latestSummary: ScreenTimeSummary?
    @Published var weeklyHistory: [ScreenTimeSummary] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    /// True while 30-day retroactive backfill is running (hidden report in app root).
    @Published var isBackfilling: Bool = false
    @Published var backfillDayIndex: Int = 0

    // MARK: - Private

    private let authCenter = AuthorizationCenter.shared
    private let appGroupID = "group.com.retrospect.shared"
    private let summaryKey = "screenTimeDailySummary"
    private let historyKey = "screenTimeWeeklyHistory"
    private let lastSyncKey = "screenTimeLastSyncDate"
    /// Persisted so we stay "authorized" across app launches (system can report .notDetermined until re-request).
    private let userApprovedKey = "screenTimeUserApproved"
    /// Set by main app before rendering DeviceActivityReport for retroactive backfill; extension uses it as summary date.
    private let requestedDateKey = "screenTimeRequestedDate"
    private var refreshTimer: Timer?
    private var backfillTimer: Timer?
    private let backfillTotalDays = 30
    private let backfillDelayPerDay: TimeInterval = 1.5

    private init() {
        checkAuthorizationStatus()
        loadLatestSummary()
        loadWeeklyHistory()
        loadLastSyncDate()
        startPeriodicRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
        backfillTimer?.invalidate()
    }

    // MARK: - Retroactive Backfill (background, no UI)

    /// Interval for the current backfill day; nil when not backfilling or when done.
    var currentBackfillDateInterval: DateInterval? {
        guard isBackfilling, backfillDayIndex < backfillTotalDays,
              let day = Calendar.current.date(byAdding: .day, value: -backfillDayIndex, to: Date()) else { return nil }
        let start = Calendar.current.startOfDay(for: day)
        if backfillDayIndex == 0 {
            return DateInterval(start: start, end: Date())
        }
        guard let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: day) else {
            return DateInterval(start: start, end: start.addingTimeInterval(86400 - 1))
        }
        return DateInterval(start: start, end: end)
    }

    /// Start 30-day retroactive backfill; runs in background via hidden report in app root.
    func startRetroactiveBackfill() {
        guard isAuthorized else { return }
        backfillTimer?.invalidate()
        isBackfilling = true
        backfillDayIndex = 0
        setRequestedDateForExtension(Date())
        backfillTimer = Timer.scheduledTimer(withTimeInterval: backfillDelayPerDay, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceBackfillOneDay()
            }
        }
        RunLoop.main.add(backfillTimer!, forMode: .common)
    }

    private func advanceBackfillOneDay() {
        backfillDayIndex += 1
        if backfillDayIndex >= backfillTotalDays {
            backfillTimer?.invalidate()
            backfillTimer = nil
            isBackfilling = false
            setRequestedDateForExtension(nil)
            refreshData()
            return
        }
        guard let day = Calendar.current.date(byAdding: .day, value: -backfillDayIndex, to: Date()) else { return }
        setRequestedDateForExtension(day)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: userApprovedKey)
            authorizationError = nil
            print("✅ Screen Time: Authorization granted")

            scheduleDailyMonitor()
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            print("❌ Screen Time: Authorization failed — \(error.localizedDescription)")
        }
    }

    func checkAuthorizationStatus() {
        let status = authCenter.authorizationStatus
        switch status {
        case .approved:
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: userApprovedKey)
            print("✅ Screen Time: Auth status = .approved")
        case .denied:
            let previouslyApproved = UserDefaults.standard.bool(forKey: userApprovedKey)
            isAuthorized = previouslyApproved
            print("⚠️ Screen Time: Auth status = .denied (using cached=\(previouslyApproved))")
        case .notDetermined:
            let previouslyApproved = UserDefaults.standard.bool(forKey: userApprovedKey)
            isAuthorized = previouslyApproved
            print("⚠️ Screen Time: Auth status = .notDetermined (using cached=\(previouslyApproved))")
        @unknown default:
            let previouslyApproved = UserDefaults.standard.bool(forKey: userApprovedKey)
            isAuthorized = previouslyApproved
            print("⚠️ Screen Time: Auth status = unknown (using cached=\(previouslyApproved))")
        }
    }

    /// Set the date the extension should stamp on the next report (for 30-day backfill). Pass nil to clear.
    func setRequestedDateForExtension(_ date: Date?) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            defaults.set(formatter.string(from: date), forKey: requestedDateKey)
        } else {
            defaults.removeObject(forKey: requestedDateKey)
        }
    }

    func revokeAuthorization() {
        authCenter.revokeAuthorization(completionHandler: { result in
            Task { @MainActor in
                switch result {
                case .success:
                    self.isAuthorized = false
                    UserDefaults.standard.set(false, forKey: self.userApprovedKey)
                    self.cancelDailyMonitor()
                    self.latestSummary = nil
                    self.weeklyHistory = []
                    print("✅ Screen Time: Authorization revoked")
                case let .failure(error):
                    print("❌ Screen Time: Revoke failed — \(error.localizedDescription)")
                }
            }
        })
    }

    // MARK: - Device Activity Monitor

    func scheduleDailyMonitor() {
        let center = DeviceActivityCenter()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(
                DeviceActivityName("daily_screen_time"),
                during: schedule
            )
            print("✅ Screen Time: Daily monitor scheduled (midnight to 11:59 PM, repeating)")
        } catch {
            print("❌ Screen Time: Failed to schedule monitor — \(error.localizedDescription)")
        }
    }

    func cancelDailyMonitor() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("daily_screen_time")])
        print("✅ Screen Time: Daily monitor cancelled")
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshData()
            }
        }
    }

    func refreshData() {
        guard isAuthorized else { return }
        loadLatestSummary()
        loadWeeklyHistory()
        readExtensionDiagnostics()
        autoSyncIfNeeded()
    }

    // MARK: - Data Reading (from App Group shared by extension)

    func loadLatestSummary() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ Screen Time: Cannot access App Group defaults")
            return
        }

        guard let data = defaults.data(forKey: summaryKey) else {
            print("⚠️ Screen Time: No data at key '\(summaryKey)' in App Group (extension hasn't written yet)")
            return
        }

        do {
            let summary = try JSONDecoder().decode(ScreenTimeSummary.self, from: data)
            latestSummary = summary
            print(
                "📊 Screen Time: Loaded summary for \(summary.date) — \(summary.totalScreenTimeMinutes)min, \(summary.totalPickups) pickups, \(summary.appUsage.count) apps"
            )
        } catch {
            print("❌ Screen Time: Failed to decode summary — \(error.localizedDescription)")
        }
    }

    /// Reads diagnostic breadcrumbs left by the ScreenTimeReport extension in the App Group.
    private func readExtensionDiagnostics() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let log = defaults.stringArray(forKey: "screenTimeExtensionLog"), !log.isEmpty else {
            print("🔍 Screen Time Extension: No diagnostic log found — extension may not have run")
            return
        }
        for entry in log {
            print("🔍 Screen Time Extension: \(entry)")
        }
    }

    func loadWeeklyHistory() {
        guard let defaults = UserDefaults(suiteName: appGroupID), let data = defaults.data(forKey: historyKey) else { return }

        do {
            let history = try JSONDecoder().decode([ScreenTimeSummary].self, from: data)
            weeklyHistory = history.sorted { $0.date > $1.date }
            print("📊 Screen Time: Loaded \(history.count) days of history")
        } catch {
            print("❌ Screen Time: Failed to decode history — \(error.localizedDescription)")
        }
    }

    // MARK: - Backend Sync

    private func autoSyncIfNeeded() {
        guard latestSummary != nil else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        if let lastSync = lastSyncDate {
            let lastSyncStr = dateFormatter.string(from: lastSync)
            if lastSyncStr == todayStr {
                return // Already synced today
            }
        }

        syncToBackend()
    }

    func syncToBackend() {
        guard let summary = latestSummary else {
            print("⚠️ Screen Time: No summary to sync")
            return
        }

        guard RetrospectAPIClient.shared.isAuthenticated else {
            print("⚠️ Screen Time: Not authenticated — skipping sync")
            return
        }

        isSyncing = true

        Task {
            do {
                try await RetrospectAPIClient.shared.uploadIntegrationItems(
                    providerId: "screen_time",
                    runType: "incremental_sync",
                    cursorBefore: ["last_sync_at": lastSyncDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""],
                    cursorAfter: ["last_sync_at": ISO8601DateFormatter().string(from: Date())],
                    items: [summary.integrationItem()]
                )
                lastSyncDate = Date()
                saveLastSyncDate()
                isSyncing = false
                print("✅ Screen Time: Structured summary synced to backend")
            } catch {
                isSyncing = false
                print("❌ Screen Time: Backend sync failed — \(error.localizedDescription)")
            }
        }
    }

    /// Sync the entire weekly history to the backend (for backfill)
    func syncWeeklyHistoryToBackend() {
        guard RetrospectAPIClient.shared.isAuthenticated, !weeklyHistory.isEmpty else { return }

        isSyncing = true

        Task {
            var syncCount = 0
            for summary in weeklyHistory {
                do {
                    try await RetrospectAPIClient.shared.uploadIntegrationItems(
                        providerId: "screen_time",
                        runType: "initial_backfill",
                        cursorAfter: ["last_synced_day": summary.date],
                        items: [summary.integrationItem()]
                    )
                    syncCount += 1
                } catch {
                    print("❌ Screen Time: Failed to sync \(summary.date) — \(error.localizedDescription)")
                }

                // Rate limit
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            isSyncing = false
            print("✅ Screen Time: Synced \(syncCount)/\(weeklyHistory.count) days of history")
        }
    }

    // MARK: - Persistence Helpers

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
    }

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    // MARK: - Computed Properties

    var weeklyAverageMinutes: Int {
        guard !weeklyHistory.isEmpty else { return 0 }
        let total = weeklyHistory.reduce(0) { $0 + $1.totalScreenTimeMinutes }
        return total / weeklyHistory.count
    }

    var weeklyAveragePickups: Int {
        guard !weeklyHistory.isEmpty else { return 0 }
        let total = weeklyHistory.reduce(0) { $0 + $1.totalPickups }
        return total / weeklyHistory.count
    }

    var mostUsedApp: String? {
        latestSummary?.appUsage.first?.appName
    }

    var topCategory: String? {
        latestSummary?.categoryBreakdown.first?.categoryName
    }
}

// MARK: - Screen Time Data Models

struct ScreenTimeSummary: Codable, Identifiable {
    let date: String
    let totalScreenTimeMinutes: Int
    let totalPickups: Int
    let firstPickupTime: String?
    let appUsage: [AppUsageEntry]
    let categoryBreakdown: [CategoryUsageEntry]

    var id: String {
        date
    }

    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var formattedTotalTime: String {
        let h = totalScreenTimeMinutes / 60
        let m = totalScreenTimeMinutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    func integrationItem() -> [String: Any] {
        let occurredAt = dateObject ?? Date()
        let payload: [String: Any] = [
            "date": date,
            "timezone": TimeZone.current.identifier,
            "total_screen_time_minutes": totalScreenTimeMinutes,
            "total_pickups": totalPickups,
            "first_pickup_time": firstPickupTime ?? "",
            "app_usage": appUsage.map {
                [
                    "app_name": $0.appName,
                    "bundle_identifier": $0.bundleIdentifier ?? "",
                    "minutes": $0.minutes,
                    "pickups": $0.pickups,
                    "category_name": $0.categoryName ?? "",
                ] as [String: Any]
            },
            "category_breakdown": categoryBreakdown.map {
                [
                    "category_name": $0.categoryName,
                    "minutes": $0.minutes,
                ] as [String: Any]
            },
        ]

        return [
            "providerObjectType": "daily_attention_summary",
            "providerObjectId": date,
            "payload": payload,
            "canonicalType": "attention_day",
            "canonicalText": toSourceCanonicalText(),
            "normalizedData": payload,
            "occurredAt": ISO8601DateFormatter().string(from: occurredAt),
            "parserVersion": "device-activity-v1",
            "normalizerVersion": "attention-day-v1",
            "contentType": "screen_time",
            "metadata": [
                "source": "screen_time",
                "sync_day": date,
                "sync_scope": "daily",
            ],
        ]
    }

    /// Describes only measured source facts. Behavioral interpretation belongs
    /// to the agent, where it can remain provisional and evidence-grounded.
    func toSourceCanonicalText() -> String {
        var lines = [
            "Screen Time report for \(date):",
            "Total screen time: \(totalScreenTimeMinutes) minutes",
            "Phone pickups: \(totalPickups)",
        ]
        if let firstPickupTime {
            lines.append("First pickup: \(firstPickupTime)")
        }
        if !categoryBreakdown.isEmpty {
            lines.append("Usage by category:")
            lines.append(contentsOf: categoryBreakdown.sorted { $0.minutes > $1.minutes }
                .map { "- \($0.categoryName): \($0.minutes) minutes" })
        }
        if !appUsage.isEmpty {
            lines.append("Top apps:")
            lines.append(contentsOf: appUsage.sorted { $0.minutes > $1.minutes }.prefix(15)
                .map { "- \($0.appName): \($0.minutes) minutes, \($0.pickups) pickups" })
        }
        return lines.joined(separator: "\n")
    }

    /// Convert the summary into a detailed, structured natural-language format
    /// that the AI extraction pipeline can deeply analyze for behavioral patterns.
    func toNaturalLanguage() -> String {
        var lines: [String] = []

        let hours = totalScreenTimeMinutes / 60
        let minutes = totalScreenTimeMinutes % 60

        lines.append("=== SCREEN TIME REPORT — \(date) ===")
        lines.append("")
        lines.append("OVERVIEW:")
        lines.append("Total screen time: \(hours)h \(minutes)m (\(totalScreenTimeMinutes) minutes)")
        lines.append("Phone pickups: \(totalPickups) times")

        if let firstPickup = firstPickupTime {
            lines.append("First pickup of the day: \(firstPickup)")
        }

        if totalPickups > 0, totalScreenTimeMinutes > 0 {
            let avgSessionMinutes = totalScreenTimeMinutes / max(totalPickups, 1)
            lines.append("Average session length: ~\(avgSessionMinutes) minutes per pickup")
        }

        // Category breakdown with percentage analysis
        if !categoryBreakdown.isEmpty {
            lines.append("")
            lines.append("USAGE BY CATEGORY:")
            let sortedCategories = categoryBreakdown.sorted { $0.minutes > $1.minutes }
            for cat in sortedCategories {
                let h = cat.minutes / 60
                let m = cat.minutes % 60
                let percentage = totalScreenTimeMinutes > 0
                    ? Int(round(Double(cat.minutes) / Double(totalScreenTimeMinutes) * 100))
                    : 0
                let timeStr = h > 0 ? "\(h)h \(m)m" : "\(m)m"
                lines.append("  - \(cat.categoryName): \(timeStr) (\(percentage)% of total)")
            }
        }

        // Top apps — detailed
        if !appUsage.isEmpty {
            lines.append("")
            lines.append("TOP APPS (by time spent):")
            let sortedApps = appUsage.sorted { $0.minutes > $1.minutes }
            for (index, app) in sortedApps.prefix(15).enumerated() {
                let h = app.minutes / 60
                let m = app.minutes % 60
                let timeStr = h > 0 ? "\(h)h \(m)m" : "\(m)m"
                let catLabel = app.categoryName.map { " [\($0)]" } ?? ""
                let pickupLabel = app.pickups > 0 ? ", \(app.pickups) pickups" : ""
                lines.append("  \(index + 1). \(app.appName)\(catLabel): \(timeStr)\(pickupLabel)")
            }
        }

        // Behavioral signals for AI to pick up on
        lines.append("")
        lines.append("BEHAVIORAL SIGNALS:")

        if totalScreenTimeMinutes > 360 {
            lines.append("  - HIGH screen time day (over 6 hours). This may indicate avoidance behavior, boredom, or a particularly demanding digital workday.")
        } else if totalScreenTimeMinutes > 240 {
            lines.append("  - MODERATE-HIGH screen time (4-6 hours).")
        } else if totalScreenTimeMinutes < 60 {
            lines.append("  - LOW screen time day (under 1 hour). This may indicate an active day offline, digital detox, or simply a busy day.")
        }

        if totalPickups > 80 {
            lines.append("  - VERY HIGH pickup frequency (\(totalPickups) times). This suggests habitual phone checking, potential anxiety, or restlessness.")
        } else if totalPickups > 50 {
            lines.append("  - HIGH pickup frequency (\(totalPickups) times). Consider whether these are intentional or reflexive.")
        } else if totalPickups < 15 {
            lines.append("  - LOW pickup frequency (\(totalPickups) times). This suggests focused, intentional phone use.")
        }

        // Social media specific insight
        let socialApps = appUsage.filter { ($0.categoryName ?? "").lowercased().contains("social") }
        let socialMinutes = socialApps.reduce(0) { $0 + $1.minutes }
        if socialMinutes > 60 {
            let socialNames = socialApps.prefix(3).map(\.appName).joined(separator: ", ")
            lines
                .append(
                    "  - Spent \(socialMinutes / 60)h \(socialMinutes % 60)m on social media (\(socialNames)). Consider: is this consumption aligned with your values and goals?"
                )
        }

        // Entertainment insight
        let entertainmentApps = appUsage.filter { ($0.categoryName ?? "").lowercased().contains("entertainment") }
        let entertainmentMinutes = entertainmentApps.reduce(0) { $0 + $1.minutes }
        if entertainmentMinutes > 90 {
            lines.append("  - \(entertainmentMinutes / 60)h \(entertainmentMinutes % 60)m on entertainment. Is this recharging or avoidance?")
        }

        // Productivity insight
        let productivityApps = appUsage.filter { ($0.categoryName ?? "").lowercased().contains("productivity") }
        let productivityMinutes = productivityApps.reduce(0) { $0 + $1.minutes }
        if productivityMinutes > 0 {
            let productivityRatio = totalScreenTimeMinutes > 0
                ? Int(round(Double(productivityMinutes) / Double(totalScreenTimeMinutes) * 100))
                : 0
            lines
                .append(
                    "  - Productivity apps: \(productivityMinutes / 60)h \(productivityMinutes % 60)m (\(productivityRatio)% of screen time). This reflects intentional digital work."
                )
        }

        lines.append("")
        lines.append("=== END SCREEN TIME REPORT ===")

        return lines.joined(separator: "\n")
    }
}

struct AppUsageEntry: Codable, Identifiable {
    let appName: String
    let bundleIdentifier: String?
    let minutes: Int
    let pickups: Int
    let categoryName: String?

    var id: String {
        bundleIdentifier ?? appName
    }

    var formattedTime: String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes)m" : "<1m"
    }
}

struct CategoryUsageEntry: Codable, Identifiable {
    let categoryName: String
    let minutes: Int

    var id: String {
        categoryName
    }

    var formattedTime: String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes)m" : "<1m"
    }
}
