import SwiftUI

// === SQUIRCLE LOGO - iOS App Icon Style Logo Display ===
// Displays the Retrospect logo in a rounded squircle frame similar to iOS app icons
// Provides consistent spacing and styling across the app

struct SquircleLogo: View {
    let size: CGFloat
    let cornerRadiusRatio: CGFloat
    let shadowEnabled: Bool
    let backgroundColor: Color
    
    // Default iOS app icon corner radius is approximately 22.37% of the size
    private var cornerRadius: CGFloat {
        size * cornerRadiusRatio
    }
    
    init(
        size: CGFloat,
        cornerRadiusRatio: CGFloat = 0.2237, // iOS app icon standard
        shadowEnabled: Bool = true,
        backgroundColor: Color = Color.white
    ) {
        self.size = size
        self.cornerRadiusRatio = cornerRadiusRatio
        self.shadowEnabled = shadowEnabled
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            // Background squircle
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
                .frame(width: size, height: size)
                .shadow(
                    color: shadowEnabled ? Color.black.opacity(0.15) : Color.clear,
                    radius: shadowEnabled ? size * 0.08 : 0, // Shadow scales with size
                    x: 0,
                    y: shadowEnabled ? size * 0.04 : 0
                )
            
            // Logo image with proper padding
            Image("retrospect-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.7, height: size * 0.7) // 70% of container for good spacing
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius * 0.7)) // Slightly less rounded than container
        }
    }
}

// MARK: - Convenience Initializers
extension SquircleLogo {
    /// Small logo for settings, navigation, etc.
    static func small(shadowEnabled: Bool = true) -> SquircleLogo {
        SquircleLogo(size: 60, shadowEnabled: shadowEnabled)
    }
    
    /// Medium logo for splash screens, onboarding
    static func medium(shadowEnabled: Bool = true) -> SquircleLogo {
        SquircleLogo(size: 120, shadowEnabled: shadowEnabled)
    }
    
    /// Large logo for hero sections
    static func large(shadowEnabled: Bool = true) -> SquircleLogo {
        SquircleLogo(size: 180, shadowEnabled: shadowEnabled)
    }
    
    /// Custom size with standard iOS proportions
    static func custom(size: CGFloat, shadowEnabled: Bool = true) -> SquircleLogo {
        SquircleLogo(size: size, shadowEnabled: shadowEnabled)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        // Different sizes
        HStack(spacing: 30) {
            VStack(spacing: 8) {
                SquircleLogo.small()
                Text("Small (60pt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                SquircleLogo.medium()
                Text("Medium (120pt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                SquircleLogo.large()
                Text("Large (180pt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        // Different styles
        HStack(spacing: 30) {
            VStack(spacing: 8) {
                SquircleLogo.medium(shadowEnabled: false)
                Text("No Shadow")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                SquircleLogo(
                    size: 120,
                    backgroundColor: LinearColors.cardBackground
                )
                Text("Custom Background")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        // Custom corner radius
        VStack(spacing: 8) {
            SquircleLogo(
                size: 120,
                cornerRadiusRatio: 0.1 // More square
            )
            Text("Less Rounded")
                .font(.caption)
                .foregroundColor(.secondary)
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
