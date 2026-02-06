import SwiftUI

// === DATA EXPLANATION SCREEN ===
// Explains how user data is analyzed for personalized insights

struct DataExplanationScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?
    
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    
    init(currentStep: Int = 1, totalSteps: Int = 6, onNext: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onExit = onExit
    }
    
    var body: some View {
        ZStack {
            // App's dark mode background
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
        .onAppear {
            bodyTextAnimating = true
        }
    }
    
    // MARK: - Top Section
    private var topSection: some View {
        VStack(spacing: 24) {
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
            .fill(LinearColors.textTertiary.opacity(0.3))
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
            // Data icon and heading
            dataHeader
            
            // Main title
            mainTitle
            
            // Body text
            bodyText
            
            Spacer() // Push everything up, button stays at bottom
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 40)
    }
    
    private var dataHeader: some View {
        HStack(spacing: 6) {
            // Chart icon
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary)
            
            // Data Usage label
            Text("Data Usage")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mainTitle: some View {
        Text("Personalized Insights")
            .font(.custom("EBGaramond12-Regular", size: 32))
            .foregroundColor(LinearColors.textDisplay)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bodyText: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We analyze the data you interact with—your notes, documents, and health metrics—to create personalized podcast insights about your life. Everything is processed securely on your device.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .offset(y: bodyTextAnimating ? 0 : 20)
                .blur(radius: bodyTextAnimating ? 0 : 8)
                .opacity(bodyTextAnimating ? 1.0 : 0.3)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Next button
            nextButton
                .padding(.horizontal, 28)
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
                .frame(height: 66)
                .contentShape(Rectangle())
        }
        .frame(height: 66)
        .background(
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
#Preview {
    DataExplanationScreen(
        currentStep: 8,
        totalSteps: 12,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
}


