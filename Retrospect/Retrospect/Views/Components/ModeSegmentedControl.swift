import SwiftUI

// === MODE SEGMENTED CONTROL ===
// iOS-style sliding 2-option selector for Writing vs Video Recording modes

struct ModeSegmentedControl: View {
    @Binding var selectedMode: HomeTab

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            // Writing Option
            segmentButton(
                title: "Write",
                icon: "pencil",
                mode: .reflections
            )

            // Entries Option
            segmentButton(
                title: "Entries",
                icon: "folder.fill",
                mode: .entries
            )
        }
        .frame(height: 36) // More compact height
        .background(
            RoundedRectangle(cornerRadius: 12) // Match settings button corner radius
                .fill(LinearColors.inputBackground) // Adaptive color for light/dark mode
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearColors.cardBorder, lineWidth: 1) // Subtle border
        )
        .fixedSize(horizontal: true, vertical: false) // Make it compact horizontally
        .padding(.horizontal, 24)
    }

    private func segmentButton(title: String, icon: String, mode: HomeTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMode = mode
            }
            HapticManager.shared.playLightImpact()
        }) {
            HStack(spacing: 5) { // Tighter spacing
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium)) // Smaller icon
                Text(title)
                    .font(.system(size: 14, weight: .medium)) // Smaller text
            }
            .foregroundColor(selectedMode == mode ? LinearColors.textDisplay : LinearColors.textTertiary) // Adaptive colors
            .padding(.horizontal, 12) // More compact horizontal padding
            .frame(height: 30) // More compact height
            .background(
                ZStack {
                    if selectedMode == mode {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(LinearColors.cardBackground) // Adaptive selected background
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(LinearColors.cardBorder, lineWidth: 0.5)
                            )
                            .matchedGeometryEffect(id: "selectedSegment", in: animation)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(3)
    }
}

#Preview {
    VStack(spacing: 20) {
        ModeSegmentedControl(selectedMode: .constant(.reflections))
        ModeSegmentedControl(selectedMode: .constant(.entries))
    }
    .padding()
    .background(LinearColors.background)
}
