//
//  ScreenTimeService.swift
//  Retrospect
//
//  Full-featured Screen Time integration service.
//  Manages authorization, daily monitor scheduling, data reading from
//  the shared App Group, and backend syncing for the AI analysis pipeline.
//

import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

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
    
    // MARK: - Private
    
    private let authCenter = AuthorizationCenter.shared
    private let appGroupID = "group.com.retrospect.shared"
    private let summaryKey = "screenTimeDailySummary"
    private let historyKey = "screenTimeWeeklyHistory"
    private let lastSyncKey = "screenTimeLastSyncDate"
    private var refreshTimer: Timer?
    
    private init() {
        checkAuthorizationStatus()
        loadLatestSummary()
        loadWeeklyHistory()
        loadLastSyncDate()
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = true
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
        switch authCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied, .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func revokeAuthorization() {
        authCenter.revokeAuthorization(completionHandler: { result in
            Task { @MainActor in
                switch result {
                case .success:
                    self.isAuthorized = false
                    self.cancelDailyMonitor()
                    self.latestSummary = nil
                    self.weeklyHistory = []
                    print("✅ Screen Time: Authorization revoked")
                case .failure(let error):
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
        autoSyncIfNeeded()
    }
    
    // MARK: - Data Reading (from App Group shared by extension)
    
    func loadLatestSummary() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ Screen Time: Cannot access App Group defaults")
            return
        }
        
        guard let data = defaults.data(forKey: summaryKey) else { return }
        
        do {
            let summary = try JSONDecoder().decode(ScreenTimeSummary.self, from: data)
            latestSummary = summary
            print("📊 Screen Time: Loaded summary for \(summary.date) — \(summary.totalScreenTimeMinutes)min, \(summary.totalPickups) pickups, \(summary.appUsage.count) apps")
        } catch {
            print("❌ Screen Time: Failed to decode summary — \(error.localizedDescription)")
        }
    }
    
    func loadWeeklyHistory() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let data = defaults.data(forKey: historyKey) else { return }
        
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
        
        let content = summary.toNaturalLanguage()
        
        Task {
            do {
                try await RetrospectAPIClient.shared.uploadContent(
                    contentType: "screen_time",
                    content: content,
                    contentDate: summary.dateObject
                )
                lastSyncDate = Date()
                saveLastSyncDate()
                isSyncing = false
                print("✅ Screen Time: Summary synced to backend (\(content.count) chars)")
            } catch {
                isSyncing = false
                print("❌ Screen Time: Backend sync failed — \(error.localizedDescription)")
            }
        }
    }
    
    /// Sync the entire weekly history to the backend (for backfill)
    func syncWeeklyHistoryToBackend() {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        guard !weeklyHistory.isEmpty else { return }
        
        isSyncing = true
        
        Task {
            var syncCount = 0
            for summary in weeklyHistory {
                let content = summary.toNaturalLanguage()
                guard !content.isEmpty else { continue }
                
                do {
                    try await RetrospectAPIClient.shared.uploadContent(
                        contentType: "screen_time",
                        content: content,
                        contentDate: summary.dateObject
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
    
    var id: String { date }
    
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
        
        if totalPickups > 0 && totalScreenTimeMinutes > 0 {
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
            let socialNames = socialApps.prefix(3).map { $0.appName }.joined(separator: ", ")
            lines.append("  - Spent \(socialMinutes / 60)h \(socialMinutes % 60)m on social media (\(socialNames)). Consider: is this consumption aligned with your values and goals?")
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
            lines.append("  - Productivity apps: \(productivityMinutes / 60)h \(productivityMinutes % 60)m (\(productivityRatio)% of screen time). This reflects intentional digital work.")
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
    
    var id: String { bundleIdentifier ?? appName }
    
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
    
    var id: String { categoryName }
    
    var formattedTime: String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes)m" : "<1m"
    }
}
