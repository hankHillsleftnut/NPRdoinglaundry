//
//  MinimalPillButton.swift
//  Retrospect
//
//  Reusable pill-shaped button with the same styling as the journal input card:
//  - Gray background
//  - Inner 4pt stroke
//  - Outer gradient stroke
//  - Drop shadow
//  - Pill shape
//

import SwiftUI

struct MinimalPillButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playMediumImpact()
            action()
        }) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // 1. Base fill
                    Capsule()
                        .fill(LinearColors.Minimal.inputBackground)
                    
                    // 2. Inner stroke (4pt)
                    Capsule()
                        .strokeBorder(
                            LinearColors.Minimal.border.opacity(0.5),
                            lineWidth: 4
                        )
                        .padding(1)
                    
                    // 3. Inner shadow overlay
                    Capsule()
                        .stroke(Color.black.opacity(0.3), lineWidth: 6)
                        .blur(radius: 3)
                        .offset(y: 2)
                        .mask(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black, Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .padding(1)
                    
                    // 4. Outer stroke - gradient frame
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LinearColors.Minimal.textSecondary,
                                    LinearColors.Minimal.textTertiary
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Large Variant for prominent actions
struct MinimalPillButtonLarge: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playMediumImpact()
            action()
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(
                ZStack {
                    // 1. Base fill
                    Capsule()
                        .fill(LinearColors.Minimal.inputBackground)
                    
                    // 2. Inner stroke (4pt)
                    Capsule()
                        .strokeBorder(
                            LinearColors.Minimal.border.opacity(0.5),
                            lineWidth: 4
                        )
                        .padding(1)
                    
                    // 3. Inner shadow overlay
                    Capsule()
                        .stroke(Color.black.opacity(0.3), lineWidth: 6)
                        .blur(radius: 3)
                        .offset(y: 2)
                        .mask(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black, Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .padding(1)
                    
                    // 4. Outer stroke - gradient frame
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LinearColors.Minimal.textSecondary,
                                    LinearColors.Minimal.textTertiary
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        VStack(spacing: 24) {
            MinimalPillButton(title: "Continue", icon: "arrow.right") {
                print("Continue tapped")
            }
            
            MinimalPillButton(title: "Get Started") {
                print("Get Started tapped")
            }
            
            MinimalPillButtonLarge(title: "Play", icon: "play.fill") {
                print("Play tapped")
            }
        }
    }
}

