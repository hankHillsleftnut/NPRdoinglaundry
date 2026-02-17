import SwiftUI
import AVFoundation

// === SIMPLE POLAROID COMPONENT ===
// Clean, simple Polaroid with gentle descent animation and basic interactions

struct SimplePolaroid: View {
    @State private var isGenerated = false
    @State private var isGenerating = false
    @State private var dragOffset = CGSize.zero
    @State private var isFlipped = false
    @State private var rotationAngle: Double = 0
    
    // Animation states
    @State private var polaroidOffset: CGFloat = -200 // Start above screen
    @State private var polaroidRotation: Double = 0
    @State private var polaroidOpacity: Double = 0
    
    private let polaroidSize: CGFloat = 280
    
    var body: some View {
        ZStack {
            // Generate button (shows when not generated)
            if !isGenerated && !isGenerating {
                generateButton
            }
            
            // The Polaroid itself
            if isGenerating || isGenerated {
                polaroidView
                    .offset(y: polaroidOffset)
                    .rotationEffect(.degrees(polaroidRotation))
                    .opacity(polaroidOpacity)
                    .offset(dragOffset)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .rotationEffect(.degrees(rotationAngle))
                    .gesture(
                        isGenerated ?
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    dragOffset = .zero
                                }
                            }
                        : nil
                    )
                    .onTapGesture {
                        if isGenerated {
                            flipPolaroid()
                        }
                    }
            }
        }
        .frame(height: 400) // Fixed container height
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: generatePolaroid) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .medium))
                
                Text("Generate Polaroid")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearColors.accent)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Polaroid View
    private var polaroidView: some View {
        ZStack {
            // Front of the polaroid
            VStack(spacing: 0) {
                // Photo area with gradient - square shape
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                LinearColors.Minimal.iconPurple.opacity(0.5), // Light purple
                                LinearColors.terraCottaLight, // Light peach
                                LinearColors.Minimal.iconGreen.opacity(0.5)  // Light mint
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: polaroidSize * 0.9, height: polaroidSize * 0.9) // Square with thinner margins
                    .padding(.top, polaroidSize * 0.03) // Thinner top margin
                
                // Bottom white space for writing
                Rectangle()
                    .fill(LinearColors.Minimal.pureWhite)
                    .frame(width: polaroidSize, height: polaroidSize * 0.07) // Smaller bottom section to fit square photo
            }
            .frame(width: polaroidSize, height: polaroidSize)
            .background(LinearColors.Minimal.pureWhite)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .opacity(isFlipped ? 0 : 1)
            
            // Back of the polaroid
            VStack {
                Spacer()
                Text("Retrospect")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundColor(LinearColors.textSecondary)
                Spacer()
            }
            .frame(width: polaroidSize, height: polaroidSize)
            .background(LinearColors.Minimal.pureWhite)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)
        }
    }
    
    // MARK: - Actions
    private func generatePolaroid() {
        guard !isGenerating else { return }
        
        isGenerating = true
        isGenerated = false
        isFlipped = false
        rotationAngle = 0
        dragOffset = .zero
        
        // Generate random starting tilt (5-10 degrees)
        let randomTilt = Double.random(in: 5...10)
        let tiltDirection = Bool.random() ? 1.0 : -1.0
        
        // Set initial state
        polaroidOffset = -200 // Start above screen
        polaroidRotation = randomTilt * tiltDirection
        polaroidOpacity = 0
        
        // Play gentle sound
        AudioServicesPlaySystemSound(1103)
        
        // Gentle haptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Smooth descent animation
        withAnimation(.spring(response: 2.0, dampingFraction: 0.8)) {
            polaroidOffset = 0 // Move to center
            polaroidRotation = 0 // Straighten out
            polaroidOpacity = 1 // Fade in
        }
        
        // Complete generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            completeGeneration()
        }
    }
    
    private func completeGeneration() {
        isGenerating = false
        isGenerated = true
        
        // Success haptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Completion sound
        AudioServicesPlaySystemSound(1004)
    }
    
    private func flipPolaroid() {
        let randomTilt = Double.random(in: -8...8)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isFlipped.toggle()
            rotationAngle = isFlipped ? randomTilt : 0
        }
        
        // Light haptic for flip
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview
#Preview {
    SimplePolaroid()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearColors.backgroundGrey)
}
