//
//  TotalActivityView.swift
//  ScreenTimeReport
//
//  Displays the extracted screen time summary from the JSON configuration string.
//

import SwiftUI

struct TotalActivityView: View {
    let totalActivity: String
    
    private var viewData: ViewData? {
        guard let data = totalActivity.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ViewData.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    var body: some View {
        if let data = viewData {
            structuredView(data)
        } else {
            Text(totalActivity)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding()
        }
    }
    
    @ViewBuilder
    private func structuredView(_ data: ViewData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(data.formattedDuration)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 11))
                        Text("\(data.totalPickups) pickups")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Category bars
            if !data.categories.isEmpty {
                HStack(spacing: 2) {
                    ForEach(data.categories.prefix(5), id: \.categoryName) { cat in
                        let fraction = data.totalMinutes > 0
                            ? CGFloat(cat.minutes) / CGFloat(data.totalMinutes)
                            : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForCategory(cat.categoryName))
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: max(fraction * 5, 0.1), anchor: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Top apps
            if !data.apps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Most Used")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(data.apps.prefix(5), id: \.appName) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.appName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                if let category = app.categoryName {
                                    Text(category)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(formatMinutes(app.minutes))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return minutes > 0 ? "\(minutes)m" : "<1m"
    }
    
    private func colorForCategory(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("social"): return Color(red: 0.30, green: 0.56, blue: 0.86)
        case let n where n.contains("entertainment"): return Color(red: 0.82, green: 0.42, blue: 0.42)
        case let n where n.contains("productivity"): return Color(red: 0.34, green: 0.72, blue: 0.52)
        case let n where n.contains("education"): return Color(red: 0.56, green: 0.44, blue: 0.82)
        case let n where n.contains("game"): return Color(red: 0.92, green: 0.62, blue: 0.24)
        case let n where n.contains("health"): return Color(red: 0.82, green: 0.36, blue: 0.56)
        default: return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}
