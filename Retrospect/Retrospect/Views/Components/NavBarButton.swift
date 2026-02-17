//
//  NavBarButton.swift
//  Retrospect
//
//  Created by AI Assistant
//

import SwiftUI

struct NavBarButton: View {
    let action: () -> Void
    let systemLabel: String
    let labelOffset: (x: CGFloat, y: CGFloat)
    let isSelected: Bool
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? 
                    LinearGradient(
                        colors: [LinearColors.terraCottaPrimary, LinearColors.terraCottaLight],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ) : 
                    LinearGradient(
                        colors: [LinearColors.warmGray, LinearColors.warmGray],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 0.5, y: 1)
            
                .offset(x: labelOffset.x, y: labelOffset.y)
                .frame(width: 45, height: 45)
            
                .background(buttonBackground)
                .overlay { buttonBorder }
        }
    }
    
    // Views
    
    private var buttonBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [LinearColors.Minimal.pureWhite, LinearColors.Minimal.pureWhite],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
    }
    
    private var buttonBorder: some View {
        Circle()
            .strokeBorder(LinearColors.Minimal.border) // #D2D2D2
    }
    
    // Init
    init(
        systemLabel: String,
        labelOffset: (x: CGFloat, y: CGFloat) = (0, 0),
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemLabel = systemLabel
        self.labelOffset = labelOffset
        self.isSelected = isSelected
        self.action = action
    }
}

struct NavBarContainer: View {
    @Binding var selectedTab: HomeTab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            // Write Tab
            CompactTabButton(
                icon: "pencil",
                title: "Write",
                isSelected: selectedTab == .reflections,
                animation: animation
            ) {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .reflections
                }
            }
            
            // Video Journal Tab  
            CompactTabButton(
                icon: "video.fill",
                title: "Journal",
                isSelected: selectedTab == .videoJournal,
                animation: animation
            ) {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .videoJournal
                }
            }
            
            // Entries Tab
            CompactTabButton(
                icon: "folder.fill",
                title: "Entries",
                isSelected: selectedTab == .entries,
                animation: animation
            ) {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .entries
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                )
                .shadow(
                    color: LinearColors.cardShadow,
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
}

// Compact tab button styled like segmented control
struct CompactTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? LinearColors.textDisplay : LinearColors.textTertiary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(LinearColors.inputBackground)
                            .brightness(0.03)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(LinearColors.Minimal.border, lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            .matchedGeometryEffect(id: "selectedTab", in: animation)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(3)
    }
}

// Old floating tab button - keeping for compatibility if needed elsewhere
struct FloatingTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon with brand-colored selection state
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? LinearColors.accent : LinearColors.textSecondary)
                    .frame(width: 24, height: 24)
                
                // Title label
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? LinearColors.accent : LinearColors.textTertiary)
            }
            .frame(minWidth: 64)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @State var selectedTab = HomeTab.reflections
    return NavBarContainer(selectedTab: $selectedTab)
}
