//
//  LegacyHomeScreen.swift
//  Retrospect
//
//  Archive of the original UI (UI1) - warm cream theme with cards
//  Accessible from Settings > Advanced > Legacy UI
//

import SwiftUI

/// Wrapper for the original HomeScreen UI, preserved as "UI1"
/// This provides access to the legacy warm cream theme interface
struct LegacyHomeScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shouldStartVoiceRecording = false

    var body: some View {
        ZStack {
            // The original HomeScreen with all its functionality
            HomeScreen(shouldStartVoiceRecording: $shouldStartVoiceRecording)

            // Close button overlay to return to new UI
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("New UI")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(LinearColors.accent)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    LegacyHomeScreen()
}
