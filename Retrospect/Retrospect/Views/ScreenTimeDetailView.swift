//
//  ScreenTimeDetailView.swift
//  Retrospect
//
//  Detailed view of screen time data — daily summary, app breakdown,
//  category pie, weekly trend, and backend sync status.
//

import SwiftUI
import DeviceActivity

struct ScreenTimeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = ScreenTimeService.shared
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    
                    // Embed the DeviceActivityReport to trigger the extension and display live data
                    if service.isAuthorized {
                        deviceActivityReportSection
                    }
                    
                    if let summary = service.latestSummary {
                        todayCard(summary)
                        categoryBreakdown(summary)
                        topAppsSection(summary)
                    } else {
                        emptyState
                    }
                    
                    if !service.weeklyHistory.isEmpty {
                        weeklyTrend
                    }
                    
                    syncSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            service.refreshData()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
            }
            
            Spacer()
            
            Text("Screen Time")
                .font(.custom("EBGaramond12-Regular", size: 24))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            Spacer()
            
            Button(action: { service.refreshData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Device Activity Report (triggers extension)
    
    private var deviceActivityReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Report")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
                .textCase(.uppercase)
                .tracking(1)
            
            DeviceActivityReport(
                DeviceActivityReport.Context("Total Activity"),
                filter: DeviceActivityFilter(
                    segment: .daily(
                        during: DateInterval(
                            start: Calendar.current.startOfDay(for: Date()),
                            end: Date()
                        )
                    )
                )
            )
            .frame(minHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Today Card
    
    private func todayCard(_ summary: ScreenTimeSummary) -> some View {
        VStack(spacing: 20) {
            Text(summary.formattedTotalTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            Text("today")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
                .textCase(.uppercase)
                .tracking(1.5)
            
            HStack(spacing: 32) {
                statPill(icon: "hand.tap", value: "\(summary.totalPickups)", label: "Pickups")
                statPill(icon: "app.badge", value: "\(summary.appUsage.count)", label: "Apps")
                
                if summary.totalPickups > 0 && summary.totalScreenTimeMinutes > 0 {
                    let avgMin = summary.totalScreenTimeMinutes / summary.totalPickups
                    statPill(icon: "timer", value: "\(avgMin)m", label: "Avg Session")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(LinearColors.Minimal.accent)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
        }
    }
    
    // MARK: - Category Breakdown
    
    private func categoryBreakdown(_ summary: ScreenTimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categories")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            if summary.categoryBreakdown.isEmpty {
                Text("No category data available yet.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            } else {
                ForEach(summary.categoryBreakdown) { cat in
                    let percentage = summary.totalScreenTimeMinutes > 0
                        ? CGFloat(cat.minutes) / CGFloat(summary.totalScreenTimeMinutes)
                        : 0
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: iconForCategory(cat.categoryName))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colorForCategory(cat.categoryName))
                                .frame(width: 20)
                            
                            Text(cat.categoryName)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Spacer()
                            
                            Text(cat.formattedTime)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                            
                            Text("\(Int(percentage * 100))%")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearColors.Minimal.progressTrack)
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(colorForCategory(cat.categoryName))
                                    .frame(width: max(geo.size.width * percentage, 4), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Top Apps
    
    private func topAppsSection(_ summary: ScreenTimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Apps")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            if summary.appUsage.isEmpty {
                Text("No app usage data available yet.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            } else {
                ForEach(Array(summary.appUsage.prefix(10).enumerated()), id: \.element.id) { index, app in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .frame(width: 22, alignment: .center)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.appName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            if let category = app.categoryName {
                                Text(category)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(app.formattedTime)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            if app.pickups > 0 {
                                Text("\(app.pickups) opens")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if index < min(summary.appUsage.count, 10) - 1 {
                        Divider()
                            .background(LinearColors.Minimal.border)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Weekly Trend
    
    private var weeklyTrend: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Avg \(service.weeklyAverageMinutes / 60)h \(service.weeklyAverageMinutes % 60)m")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    Text("\(service.weeklyAveragePickups) avg pickups")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: 6) {
                let maxMinutes = service.weeklyHistory.map { $0.totalScreenTimeMinutes }.max() ?? 1
                
                ForEach(service.weeklyHistory.sorted(by: { $0.date < $1.date })) { day in
                    let fraction = CGFloat(day.totalScreenTimeMinutes) / CGFloat(max(maxMinutes, 1))
                    let isToday = day.date == todayString()
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isToday ? LinearColors.Minimal.accent : LinearColors.Minimal.accent.opacity(0.4))
                            .frame(height: max(fraction * 80, 4))
                        
                        Text(dayLabel(day.date))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(isToday ? LinearColors.Minimal.textPrimary : LinearColors.Minimal.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Sync Section
    
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Pipeline")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(LinearColors.Minimal.iconBlue)
                
                if let lastSync = service.lastSyncDate {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                } else {
                    Text("Not yet synced to backend")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
            
            Text("Screen time data is automatically synced daily to your analysis pipeline. It becomes part of your weekly podcast — patterns, habits, and behavioral insights included.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
                .lineSpacing(3)
            
            HStack(spacing: 10) {
                Button(action: {
                    service.syncToBackend()
                    HapticManager.shared.playLightImpact()
                }) {
                    HStack(spacing: 6) {
                        if service.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textPrimary))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text("Sync Today")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearColors.Minimal.accent)
                    )
                }
                .disabled(service.isSyncing || service.latestSummary == nil)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    service.syncWeeklyHistoryToBackend()
                    HapticManager.shared.playLightImpact()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14, weight: .medium))
                        Text("Sync Week")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearColors.Minimal.backgroundCardHover)
                    )
                }
                .disabled(service.isSyncing || service.weeklyHistory.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(LinearColors.Minimal.textTertiary)
            
            Text("No screen time data yet")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
            
            Text("Data will appear here after your device reports its first daily summary. This usually happens overnight.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Helpers
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func dayLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
    
    private func iconForCategory(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("social"): return "bubble.left.and.bubble.right"
        case let n where n.contains("entertainment"): return "play.rectangle"
        case let n where n.contains("productivity"): return "hammer"
        case let n where n.contains("education"): return "book"
        case let n where n.contains("game"): return "gamecontroller"
        case let n where n.contains("health"): return "heart"
        case let n where n.contains("creative") || n.contains("creativity"): return "paintbrush"
        case let n where n.contains("reading"): return "text.book.closed"
        case let n where n.contains("shopping"): return "bag"
        case let n where n.contains("finance") || n.contains("business"): return "chart.bar"
        case let n where n.contains("travel"): return "car"
        case let n where n.contains("news") || n.contains("information"): return "newspaper"
        case let n where n.contains("photo") || n.contains("video"): return "camera"
        case let n where n.contains("music"): return "music.note"
        default: return "square.grid.2x2"
        }
    }
    
    private func colorForCategory(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("social"): return LinearColors.Minimal.iconBlue
        case let n where n.contains("entertainment"): return LinearColors.Minimal.iconPink
        case let n where n.contains("productivity"): return LinearColors.Minimal.iconGreen
        case let n where n.contains("education"): return LinearColors.Minimal.iconPurple
        case let n where n.contains("game"): return LinearColors.Minimal.iconOrange
        case let n where n.contains("health"): return LinearColors.Minimal.iconGreen
        default: return LinearColors.Minimal.textTertiary
        }
    }
}
