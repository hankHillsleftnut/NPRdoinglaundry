//
//  TotalActivityReport.swift
//  ScreenTimeReport
//
//  Extracts detailed app usage, categories, and pickups from DeviceActivityResults,
//  saves the structured summary to the shared App Group container for the main app to read,
//  and returns a JSON string to render in TotalActivityView.
//

import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

// MARK: - Shared Data Models (must match main app's ScreenTimeService models)

struct AppUsageData: Codable {
    let appName: String
    let bundleIdentifier: String?
    let minutes: Int
    let pickups: Int
    let categoryName: String?
}

struct CategoryUsageData: Codable {
    let categoryName: String
    let minutes: Int
}

struct ScreenTimeDailySummary: Codable {
    let date: String
    let totalScreenTimeMinutes: Int
    let totalPickups: Int
    let firstPickupTime: String?
    let appUsage: [AppUsageData]
    let categoryBreakdown: [CategoryUsageData]
}

// MARK: - Report Scene

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    
    let content: (String) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        var totalDuration: TimeInterval = 0
        var totalPickups: Int = 0
        var appMap: [String: (name: String, bundle: String?, minutes: Int, pickups: Int, category: String?)] = [:]
        var categoryMap: [String: Int] = [:]
        
        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                for await categoryActivity in segment.categories {
                    let categoryName = categoryActivity.category.localizedDisplayName ?? "Other"
                    let categoryMinutes = Int(categoryActivity.totalActivityDuration / 60)
                    categoryMap[categoryName, default: 0] += categoryMinutes
                    
                    for await appActivity in categoryActivity.applications {
                        let appName = appActivity.application.localizedDisplayName ?? "Unknown App"
                        let bundleId = appActivity.application.bundleIdentifier
                        let key = bundleId ?? appName
                        let minutes = Int(appActivity.totalActivityDuration / 60)
                        let pickups = appActivity.numberOfPickups
                        
                        totalPickups += pickups
                        
                        if var existing = appMap[key] {
                            existing.minutes += minutes
                            existing.pickups += pickups
                            appMap[key] = existing
                        } else {
                            appMap[key] = (
                                name: appName,
                                bundle: bundleId,
                                minutes: minutes,
                                pickups: pickups,
                                category: categoryName
                            )
                        }
                    }
                }
            }
        }
        
        let totalMinutes = Int(totalDuration / 60)
        
        let apps = appMap.values
            .map { AppUsageData(appName: $0.name, bundleIdentifier: $0.bundle, minutes: $0.minutes, pickups: $0.pickups, categoryName: $0.category) }
            .sorted { $0.minutes > $1.minutes }
        
        let categories = categoryMap
            .map { CategoryUsageData(categoryName: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
        
        // Save to shared App Group for the main app
        saveSummaryToAppGroup(
            totalMinutes: totalMinutes,
            totalPickups: totalPickups,
            apps: apps,
            categories: categories
        )
        
        // Encode as JSON to pass to the view
        let viewData = ViewData(
            totalMinutes: totalMinutes,
            totalPickups: totalPickups,
            formattedDuration: formatDuration(totalDuration),
            apps: apps,
            categories: categories
        )
        
        if let jsonData = try? JSONEncoder().encode(viewData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return formatDuration(totalDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? "\(Int(duration / 60))m"
    }
    
    private func saveSummaryToAppGroup(totalMinutes: Int, totalPickups: Int, apps: [AppUsageData], categories: [CategoryUsageData]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        let summary = ScreenTimeDailySummary(
            date: todayStr,
            totalScreenTimeMinutes: totalMinutes,
            totalPickups: totalPickups,
            firstPickupTime: nil,
            appUsage: apps,
            categoryBreakdown: categories
        )
        
        guard let defaults = UserDefaults(suiteName: "group.com.retrospect.shared") else { return }
        
        if let encoded = try? JSONEncoder().encode(summary) {
            defaults.set(encoded, forKey: "screenTimeDailySummary")
            
            // Append to history array (keep last 7 days)
            var history = loadHistory(from: defaults)
            history.removeAll { $0.date == todayStr }
            history.append(summary)
            if history.count > 7 {
                history = Array(history.suffix(7))
            }
            if let historyData = try? JSONEncoder().encode(history) {
                defaults.set(historyData, forKey: "screenTimeWeeklyHistory")
            }
        }
    }
    
    private func loadHistory(from defaults: UserDefaults) -> [ScreenTimeDailySummary] {
        guard let data = defaults.data(forKey: "screenTimeWeeklyHistory"),
              let history = try? JSONDecoder().decode([ScreenTimeDailySummary].self, from: data) else {
            return []
        }
        return history
    }
}

// Internal struct used to pass structured data as JSON through the String configuration type
struct ViewData: Codable {
    let totalMinutes: Int
    let totalPickups: Int
    let formattedDuration: String
    let apps: [AppUsageData]
    let categories: [CategoryUsageData]
}
