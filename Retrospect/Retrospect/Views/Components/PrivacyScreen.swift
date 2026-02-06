import SwiftUI

// === PRIVACY SCREEN ===
// Inverted color scheme to emphasize privacy importance
// White background in dark mode, dark background in light mode

struct PrivacyScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    
    init(currentStep: Int = 1, totalSteps: Int = 6, onNext: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onExit = onExit
    }
    
    // Inverted colors for privacy emphasis
    private var backgroundColor: Color {
        themeManager.isDarkMode ? Color.white : Color.black
    }
    
    private var textColor: Color {
        themeManager.isDarkMode ? Color.black : Color.white
    }
    
    private var subtitleColor: Color {
        // Lighter gray for better contrast against titles
        themeManager.isDarkMode ? Color.gray.opacity(0.6) : Color.gray.opacity(0.7)
    }
    
    private var bodyTextColor: Color {
        // Slightly lighter than title for better contrast
        themeManager.isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.85)
    }
    
    private var progressTrackColor: Color {
        themeManager.isDarkMode ? Color.gray.opacity(0.3) : Color.white.opacity(0.3)
    }
    
    private var progressFillColor: Color {
        themeManager.isDarkMode ? Color.black : Color.white
    }
    
    var body: some View {
        ZStack {
            // Inverted background
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with draggable bar and dots
                topSection
                
                // Main content area
                Spacer()
                
                mainContent
                
                Spacer()
                
                // Bottom button area
                bottomSection
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .onAppear {
            bodyTextAnimating = true
        }
    }
    
    // MARK: - Top Section
    private var topSection: some View {
        VStack(spacing: 24) { // Healthy margin between bar and dots
            // Draggable bar (if onExit provided)
            if onExit != nil {
                draggableBar
            }
            
            // Progress bar
                progressIndicator
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
    }
    
    // MARK: - Draggable Dismiss Bar
    private var draggableBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(subtitleColor.opacity(0.3))
            .frame(width: 36, height: 5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onExit?()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
    
    // MARK: - Progress Indicator (Bar with front-loaded progress)
    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressTrackColor)
                    .frame(height: 3)
                
                // Progress fill with front-loaded calculation
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressFillColor)
                    .frame(width: geometry.size.width * calculateFrontLoadedProgress(), height: 3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 40)
    }
    
    // Calculate front-loaded progress (fast at start, slow at end)
    private func calculateFrontLoadedProgress() -> CGFloat {
        let progress = CGFloat(currentStep) / CGFloat(totalSteps)
        
        // Front-loaded curve: fast progress early, slow at end
        // Using exponential easing for front-loading
        let frontLoaded = 1 - pow(1 - progress, 2.5)
        
        return min(frontLoaded, 1.0)
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Privacy icon and heading
            privacyHeader
            
            // Main title
            mainTitle
            
            // Body text
            bodyText
            
            // Signature section - right-aligned with healthy margin
            signatureSection
                .padding(.top, 32)
            
            Spacer() // Push everything up, button stays at bottom
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28) // Increased to 28pt for more breathing room
        .padding(.top, 40) // Move content higher
    }
    
    private var privacyHeader: some View {
        HStack(spacing: 6) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(subtitleColor) // Match Privacy label color
            
            // Privacy subtitle
            Text("Privacy")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Left align
    }
    
    private var mainTitle: some View {
        Text("Nothing leaves your device.")
            .font(.custom("EBGaramond12-Regular", size: 32))
            .foregroundColor(textColor)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading) // Left align
    }
    
    private var bodyText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This app uses the content that you allow access to and process it **on your device**. none of it is sent to us or stored.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(bodyTextColor)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .offset(y: bodyTextAnimating ? 0 : 20)
                .blur(radius: bodyTextAnimating ? 0 : 8)
                .opacity(bodyTextAnimating ? 1.0 : 0.3)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)
            
            HStack {
                Text("Read our")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(bodyTextColor)
                
                Button("privacy policy") {
                    // Handle privacy policy tap
                }
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(bodyTextColor)
                .underline()
                
                Spacer()
            }
            .offset(y: bodyTextAnimating ? 0 : 20)
            .blur(radius: bodyTextAnimating ? 0 : 8)
            .opacity(bodyTextAnimating ? 1.0 : 0.3)
            .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.3), value: bodyTextAnimating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var signatureSection: some View {
        VStack(spacing: 16) {
            // Signature (using a handwritten-style text for now)
            Text("– Shaurya")
                .font(.custom("LibreBaskerville-Italic", size: 18))
                .foregroundColor(textColor)
            
            // Founder name
            Text("Shaurya Narang, Founder")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .trailing) // Right-aligned
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Next button
            nextButton
                .padding(.horizontal, 28) // Increased to 28pt to match text margins
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Next Button (ClickyButton Style)
    private var nextButton: some View {
        Button(action: {
            onNext()
        }) {
            Text("Next")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .kerning(0)
                .foregroundColor(Color.white)
                .shadow(color: LinearColors.cardShadow, radius: 2, x: 0, y: 2)
                .frame(maxWidth: .infinity)
                .frame(height: 66) // Full touch target height
                .contentShape(Rectangle()) // Ensure entire area is tappable
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
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                playButtonTouchDownHaptic()
            } else {
                playButtonTouchUpHaptic()
            }
        }, perform: {})
    }
    
    // MARK: - Haptic Functions
    private func playButtonTouchDownHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred(intensity: 0.6)
    }
    
    private func playButtonTouchUpHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Preview
#Preview("Privacy Screen - Light Mode") {
    PrivacyScreen(
        currentStep: 2,
        totalSteps: 6,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
    .environmentObject(ThemeManager.shared)
}

#Preview("Privacy Screen - Dark Mode") {
    PrivacyScreen(
        currentStep: 2,
        totalSteps: 6,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
    .environmentObject(ThemeManager.shared)
    .onAppear {
        ThemeManager.shared.isDarkMode = true
    }
}

