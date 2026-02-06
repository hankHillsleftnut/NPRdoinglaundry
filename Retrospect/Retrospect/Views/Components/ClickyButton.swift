import SwiftUI

// === CLICKY BUTTON - Premium Podcast Generation Button ===
// Sophisticated button with deep shadows and gradient for premium feel


struct ClickyButton: View {
    let text: String
    let action: () -> Void
    let isDisabled: Bool
    
    @State private var isPressed = false
    
    init(text: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            Text(text)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .kerning(0)
                .foregroundColor(LinearColors.textDisplay)
                .shadow(color: LinearColors.cardShadow, radius: 2, x: 0, y: 2)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 66)
        .background(
            // Main button background - adaptive dark gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LinearColors.metalGray, // Top: metal gray
                            LinearColors.charcoalCard  // Bottom: darker charcoal
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Inner shadow effect (top - adaptive light)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearColors.warmHighlight.opacity(0.4), lineWidth: 2)
                        .blur(radius: 0.5)
                        .offset(x: 0, y: 2)
                        .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
                )
        )
        .overlay(
            // 1pt stroke - adaptive border
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.cardBorder, lineWidth: 1)
        )
        .overlay(
            // Inner shadow effect (bottom - dark) - adaptive
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.textPrimary.opacity(0.8), lineWidth: 2)
                .blur(radius: 1)
                .offset(x: 0, y: -1)
                .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
        )
        // Drop shadows - adaptive
        .shadow(color: LinearColors.cardShadow, radius: 17, x: 0, y: 4)
        .shadow(color: LinearColors.cardShadow, radius: 3, x: 0, y: 2)
        // Interactive states
        .opacity(getOpacity())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .disabled(isDisabled)
    }
    
    private func getOpacity() -> Double {
        if isDisabled {
            return 0.5
        } else if isPressed {
            return 0.8
        } else {
            return 1.0
        }
    }
}


// MARK: - ButtonStyle Extension for Easy Usage
struct ClickyButtonStyle: ButtonStyle {
    let isDisabled: Bool
    
    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ClickyButton(
            text: "Generate Podcast", // Default text
            isDisabled: isDisabled
        ) {
            // Action will be handled by the parent button
        }
    }
}

// MARK: - Convenience Extension for View
extension View {
    func clickyButtonStyle(isDisabled: Bool = false) -> some View {
        self.buttonStyle(ClickyButtonStyle(isDisabled: isDisabled))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        // Normal state - showcases all specifications
        ClickyButton(text: "Generate Podcast") {
            print("Podcast generation started!")
        }
        
        // Different text - shows reusability
        ClickyButton(text: "Create Deep Insights") {
            print("Deep insights generation")
        }
        
        // Disabled state - shows 50% opacity
        ClickyButton(text: "Processing...", isDisabled: true) {
            print("This won't fire")
        }
        
        // Custom text examples
        ClickyButton(text: "Next") {
            print("Next action")
        }
    }
    .padding(40)
    .background(
        LinearGradient(
            gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.white]),
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
