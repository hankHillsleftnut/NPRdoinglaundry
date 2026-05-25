import SwiftUI
import GoogleSignIn

// === GOOGLE DOCS ONBOARDING SCREEN ===
// Matches app's design aesthetic with Hedvig titles and SF Pro Display body text

struct GoogleDocsOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    let onExit: (() -> Void)?
    
    @StateObject private var googleDocsService = GoogleDocsService()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    
    init(currentStep: Int, totalSteps: Int, onNext: @escaping () -> Void, onSkip: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onSkip = onSkip
        self.onExit = onExit
    }
    
    var body: some View {
        ZStack {
            // App's background
            LinearColors.background
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
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
            .fill(LinearColors.textSecondary.opacity(0.3))
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
                    .fill(LinearColors.textTertiary.opacity(0.2))
                    .frame(height: 3)
                
                // Progress fill with front-loaded calculation
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.accent)
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
            // Google Docs icon and heading - top left like privacy screen
            googleDocsHeader
            
            // Main title - left aligned
            mainTitle
            
            // Body text - left aligned
            bodyText
            
            // Connection status or button - higher up with healthy margin
            connectionSection
                .padding(.top, 32)
            
            Spacer() // Push everything up, buttons stay at bottom
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28) // Increased to 28pt for more breathing room
        .padding(.top, 40) // Move content higher to match privacy screen
    }
    
    private var googleDocsHeader: some View {
        HStack(spacing: 6) {
            // Google Docs icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary) // Lighter for better contrast
            
            // Integration label
            Text("Integration")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary) // Lighter for better contrast
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Left align like privacy screen
    }
    
    private var mainTitle: some View {
        Text("Connect your Google Docs.")
            .font(.custom("HedvigLettersSerif-24ptRegular", size: 32))
            .foregroundColor(LinearColors.textDisplay)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bodyText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automatically include your recent Google Docs in your weekly reflections. All processing happens **on your device**.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.textSecondary) // Lighter for better contrast
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .offset(y: bodyTextAnimating ? 0 : 20)
                .blur(radius: bodyTextAnimating ? 0 : 8)
                .opacity(bodyTextAnimating ? 1.0 : 0.3)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)
            
            Text("Your documents stay private and are never shared.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.textSecondary) // Lighter for better contrast
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .offset(y: bodyTextAnimating ? 0 : 20)
                .blur(radius: bodyTextAnimating ? 0 : 8)
                .opacity(bodyTextAnimating ? 1.0 : 0.3)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.3), value: bodyTextAnimating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if googleDocsService.isConnected {
                // Connected state - left aligned
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                    
                    Text("Connected Successfully")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.textDisplay)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Connect button - full width
                connectButton
            }
        }
        .padding(.top, 20)
    }
    
    private var connectButton: some View {
        Button(action: {
            connectToGoogleDocs()
        }) {
            HStack(spacing: 12) {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textPrimary))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(isConnecting ? "Connecting..." : "Connect Google Account")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.accent)
            )
        }
        .disabled(isConnecting)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Show skip button above Next button if not connected
            if !googleDocsService.isConnected {
                skipButton
                    .padding(.bottom, 16)
            }
            
            // Next/Continue button
            nextButton
        }
        .padding(.horizontal, 28) // Increased to 28pt to match text margins
        .padding(.bottom, 40)
    }
    
    private var nextButton: some View {
        Button(action: {
            onNext()
        }) {
            Text(googleDocsService.isConnected ? "Continue" : "Connect & Continue")
                .font(.system(size: 17, weight: .medium))
                .kerning(0)
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .shadow(color: LinearColors.cardShadow, radius: 2, x: 0, y: 2)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .contentShape(Rectangle())
        }
        .frame(height: 66)
        .background(
            // ClickyButton style background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LinearColors.metalGray,
                            LinearColors.charcoalCard
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearColors.warmHighlight.opacity(0.4), lineWidth: 2)
                        .blur(radius: 0.5)
                        .offset(x: 0, y: 2)
                        .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.cardBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.textPrimary.opacity(0.8), lineWidth: 2)
                .blur(radius: 1)
                .offset(x: 0, y: -1)
                .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
        )
        .shadow(color: LinearColors.cardShadow, radius: 17, x: 0, y: 4)
        .shadow(color: LinearColors.cardShadow, radius: 3, x: 0, y: 2)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                playButtonTouchDownHaptic()
            } else {
                playButtonTouchUpHaptic()
            }
        }, perform: {
            // If not connected, trigger connection on button press
            if !googleDocsService.isConnected {
                connectToGoogleDocs()
            }
        })
    }
    
    private var skipButton: some View {
        Button(action: {
            onSkip()
        }) {
            Text("Skip for now")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Actions
    private func connectToGoogleDocs() {
        isConnecting = true
        
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    showError = true
                    errorMessage = "Failed to connect to Google account. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GoogleDocsOnboardingScreen(
        currentStep: 7,
        totalSteps: 8,
        onNext: {
            print("Next tapped")
        },
        onSkip: {
            print("Skip tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
}
