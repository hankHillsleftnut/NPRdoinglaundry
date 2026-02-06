import SwiftUI

struct PolaroidFrame: View {
    let geometry: GeometryProxy
    let isPlaying: Bool
    
    // Calculate size based on the reference image - much larger polaroid
    // Should take up a significant portion of the screen width
    private var polaroidSize: CGFloat {
        if isPlaying {
            // Large size when playing - 40% of screen
            return min(geometry.size.width * 0.8, geometry.size.height * 0.4)
        } else {
            // Large size for initial state to match reference
            return min(geometry.size.width * 0.65, geometry.size.height * 0.4)
        }
    }
    
    var body: some View {
        ZStack {
            // Traditional polaroid frame with large bottom chin
            let frameWidth = polaroidSize
            let frameHeight = polaroidSize * 1.2 // Taller to accommodate chin
            let chinHeight = frameHeight * 0.25 // Large chin (25% of total height)
            // Calculate photo area height (currently using square photo, but keeping calculation for future use)
            let _ = frameHeight - chinHeight - (frameWidth * 0.05) // Photo area minus chin and top border
            
            // Outer polaroid frame (white border) - traditional rectangular shape
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: frameWidth, height: frameHeight)
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            // Inner photo area with gradient - positioned in upper portion
            let photoSize = frameWidth * 0.9 // Thin borders on sides
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.95), // Light purple
                            Color(red: 0.95, green: 0.85, blue: 0.75), // Light peach
                            Color(red: 0.75, green: 0.90, blue: 0.85)  // Light mint
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: photoSize,
                    height: photoSize
                )
                .offset(y: -chinHeight * 0.4) // Position in upper area, leaving chin space
            
            // Optional: Add some subtle texture or pattern when playing
            if isPlaying {
                let frameWidth = polaroidSize
                let frameHeight = polaroidSize * 1.2
                let chinHeight = frameHeight * 0.25
                let photoSize = frameWidth * 0.9
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: photoSize,
                        height: photoSize
                    )
                    .offset(y: -chinHeight * 0.4)
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: isPlaying
                    )
            }
        }
        .rotation3DEffect(
            .degrees(isPlaying ? 0 : -2),
            axis: (x: 0, y: 0, z: 1)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPlaying)
    }
}

#Preview {
    GeometryReader { geometry in
        VStack(spacing: 40) {
            PolaroidFrame(geometry: geometry, isPlaying: false)
            PolaroidFrame(geometry: geometry, isPlaying: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearColors.backgroundGrey)
    }
}
