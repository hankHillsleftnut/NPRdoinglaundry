import SwiftUI

// === ONBOARDING SCREEN TEMPLATE ===
// Rebuilt from scratch with app's dark mode design system

struct OnboardingScreenTemplate: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?

    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var showButton = false
    @State private var dragOffset: CGFloat = 0
    @State private var animationTimer: Timer?
    @State private var currentCharacterIndex = 0

    private let animationSpeed: Double = 0.05 // Speed per character - faster animation

    init(title: String, currentStep: Int, totalSteps: Int, onNext: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.title = title
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

                mainTextContent

                Spacer()

                // Bottom button area
                bottomSection
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .onAppear {
            startTextAnimation()
        }
        .onChange(of: title) { _, _ in
            resetAndAnimate()
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

    /// Calculate front-loaded progress (fast at start, slow at end)
    private func calculateFrontLoadedProgress() -> CGFloat {
        let progress = CGFloat(currentStep) / CGFloat(totalSteps)

        // Front-loaded curve: fast progress early, slow at end
        // Using exponential easing for front-loading
        let frontLoaded = 1 - pow(1 - progress, 2.5)

        return min(frontLoaded, 1.0)
    }

    // MARK: - Main Text Content

    private var mainTextContent: some View {
        Text(displayedText)
            .font(.custom("HedvigLettersSerif-24ptRegular", size: 35))
            .kerning(-0.5)
            .foregroundColor(LinearColors.textDisplay)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28) // Increased to 28pt for more breathing room
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Next button with ClickyButton styling
            clickyNextButton
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20) // Slide up from 20pt below
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showButton)
                .padding(.horizontal, 28) // Increased to 28pt to match text margins
                .padding(.bottom, 40) // Reduced from 60 to 40 for closer to bottom
        }
    }

    // MARK: - Clicky Next Button

    private var clickyNextButton: some View {
        Button(action: {
            onNext()
        }) {
            Text("Next")
                .font(.system(size: 17, weight: .medium))
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
                            LinearColors.charcoalCard, // Bottom: darker charcoal
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
                        .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(
                            gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )))
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
                .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(
                    gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )))
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

    // MARK: - Animation Logic

    private func startTextAnimation() {
        guard !isAnimating else { return }

        isAnimating = true
        displayedText = ""
        showButton = false
        currentCharacterIndex = 0

        // Cancel any existing timer
        animationTimer?.invalidate()

        let characters = Array(title)

        // Use Timer for truly sequential character appearance
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { timer in
            guard currentCharacterIndex < characters.count else {
                timer.invalidate()

                // Show button after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        showButton = true
                        isAnimating = false
                    }
                }
                return
            }

            // Add one character at a time
            let character = characters[currentCharacterIndex]
            displayedText += String(character)
            currentCharacterIndex += 1

            // Play subtle haptic for every character
            playCharacterHaptic()
        }
    }

    private func resetAndAnimate() {
        animationTimer?.invalidate()
        isAnimating = false
        displayedText = ""
        showButton = false
        currentCharacterIndex = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startTextAnimation()
        }
    }

    private func playCharacterHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }

    private func playButtonTouchDownHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred(intensity: 0.6)
    }

    private func playButtonTouchUpHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Onboarding Flow Container

struct OnboardingFlow: View {
    @State private var currentStep = 1
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)?

    private let onboardingSteps = [
        "I know your dirty little secret.",
        "You write notes, and you never get back to them.",
        "Save content, on social that you never go back to.",
        "Your life is scattered across so many products.\n\nYou don't even know how to make sense of it all...",
        "But who can blame you?\n\nIt's not like there's an easy way to make sense of it all, and remember the important things at the perfect time....",
        "Welcome to Retrospect.\n\nWe take all the information you touch, & generate a podcast about your life meant to give you memory superpowers.",
    ]

    private let totalStepsIncludingExtras = 12 // 6 onboarding steps + 1 privacy + 1 data explanation + 1 Google Docs + 1 Apple Health + 1 auth + 1 welcome

    var body: some View {
        ZStack {
            if currentStep <= onboardingSteps.count {
                // Regular onboarding screens (steps 1-6)
                OnboardingScreenTemplate(
                    title: onboardingSteps[currentStep - 1],
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == onboardingSteps.count + 1 {
                // Privacy screen (step 7)
                PrivacyScreen(
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == onboardingSteps.count + 2 {
                // Data explanation screen (step 8)
                DataExplanationScreen(
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == onboardingSteps.count + 3 {
                // Google Docs integration screen (step 9)
                GoogleDocsOnboardingScreen(
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == onboardingSteps.count + 4 {
                // Apple Health integration screen (step 10)
                AppleHealthOnboardingScreen(
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == onboardingSteps.count + 5 {
                // Authentication screen (step 11)
                AuthenticationScreen(
                    currentStep: currentStep,
                    totalSteps: totalStepsIncludingExtras,
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    },
                    onExit: {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            } else if currentStep == totalStepsIncludingExtras {
                // Welcome card screen as final step (step 12)
                WelcomeCardScreen(
                    onNext: {
                        // Onboarding complete - call completion handler
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlow()
}

#Preview("Single Screen") {
    OnboardingScreenTemplate(
        title: "Your life is scattered\nacross so many\nproducts.\n\nYou don't even know\nhow to make sense of\nit all...",
        currentStep: 4,
        totalSteps: 6,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
}
