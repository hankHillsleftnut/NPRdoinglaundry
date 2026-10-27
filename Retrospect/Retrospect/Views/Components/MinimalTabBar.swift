//
//  MinimalTabBar.swift
//  Retrospect
//
//  5-tab navigation bar for minimal dark home screen
//  Journal, Podcasts, Goals, Entries, Settings
//

import SwiftUI

enum MinimalTab: CaseIterable {
    case journal
    case podcasts
    case goals
    case entries
    case settings
    
    var icon: String {
        switch self {
        case .journal: return "square.and.pencil"
        case .podcasts: return "waveform"
        case .goals: return "target"
        case .entries: return "book.closed.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
    
    var title: String {
        switch self {
        case .journal: return "Journal"
        case .podcasts: return "Podcasts"
        case .goals: return "Goals"
        case .entries: return "Entries"
        case .settings: return "Settings"
        }
    }
}

struct MinimalTabBar: View {
    @Binding var selectedTab: MinimalTab
    var hasNewPodcast: Bool = false
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(MinimalTab.allCases, id: \.self) { tab in
                MinimalTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    hasNotification: tab == .podcasts && hasNewPodcast,
                    animation: animation
                ) {
                    HapticManager.shared.playLightImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct MinimalTabButton: View {
    let tab: MinimalTab
    let isSelected: Bool
    var hasNotification: Bool = false
    let animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 20 : 19, weight: isSelected ? .bold : .regular))
                    
                    // Notification pill (shows when there's something to attend to)
                    if hasNotification {
                        Circle()
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }
                
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
            }
            .foregroundColor(isSelected ? LinearColors.Minimal.tabTextSelected : LinearColors.Minimal.tabText)
            .frame(width: 60, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            MinimalTabBar(selectedTab: .constant(.journal))
                .padding(.bottom, 30)
        }
    }
}

