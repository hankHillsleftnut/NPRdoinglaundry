import SwiftUI

struct HoldToActivateButton: View {
    let action: () -> Void
    let isDeepResearchMode: Bool
    let isDisabled: Bool
    let text: String
    let icon: String
    let isProcessing: Bool
    
    // Default initializer for backward compatibility
    init(action: @escaping () -> Void, isDeepResearchMode: Bool, isDisabled: Bool) {
        self.action = action
        self.isDeepResearchMode = isDeepResearchMode
        self.isDisabled = isDisabled
        self.text = "Generate"
        self.icon = isDeepResearchMode ? "brain.head.profile" : "bolt.fill"
        self.isProcessing = false
    }
    
    // Full initializer
    init(action: @escaping () -> Void, isDeepResearchMode: Bool = false, isDisabled: Bool, text: String, icon: String, isProcessing: Bool = false) {
        self.action = action
        self.isDeepResearchMode = isDeepResearchMode
        self.isDisabled = isDisabled
        self.text = text
        self.icon = icon
        self.isProcessing = isProcessing
    }
    
    @State private var isPressed = false
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    @State private var hapticTimer: Timer?
    
    private let holdDuration: Double = 0.5
    private let hapticInterval: Double = 0.05 // 20 haptics over 0.5 seconds
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(isProcessing ? "Generating..." : text)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Base background (same as original styling)
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.15),
                                    Color(red: 0.05, green: 0.05, blue: 0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Progress fill overlay
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    LinearColors.accent.opacity(0.8),
                                    LinearColors.accent
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(x: progress, y: 1, anchor: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.button))
                        .animation(.linear(duration: 0.016), value: progress) // Smooth 60fps animation
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed && !isDisabled {
                        startHolding()
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        stopHolding()
                    }
                }
        )
    }
    
    private func startHolding() {
        guard !isDisabled && !isProcessing else { return }
        
        isPressed = true
        progress = 0.0
        
        // Start fill animation timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            if progress < 1.0 {
                progress += 0.016 / holdDuration // Progress from 0 to 1 over holdDuration
            } else {
                // Hold completed successfully
                stopHolding()
                HapticManager.shared.playHoldActivationSuccess()
                action()
            }
        }
        
        // Start progressive haptic feedback
        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) { _ in
            let intensity = min(progress, 1.0)
            HapticManager.shared.playProgressiveHaptic(intensity: intensity)
        }
        
        // Initial haptic
        HapticManager.shared.playProgressiveHaptic(intensity: 0.0)
    }
    
    private func stopHolding() {
        isPressed = false
        timer?.invalidate()
        timer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
        
        // Animate progress back to 0
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 0.0
        }
    }
}

// MARK: - Preview
struct HoldToActivateButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HoldToActivateButton(
                action: { print("Generated!") },
                isDeepResearchMode: false,
                isDisabled: false
            )
            
            HoldToActivateButton(
                action: { print("Generated with research!") },
                isDeepResearchMode: true,
                isDisabled: false
            )
            
            HoldToActivateButton(
                action: { print("Should not work") },
                isDeepResearchMode: false,
                isDisabled: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
