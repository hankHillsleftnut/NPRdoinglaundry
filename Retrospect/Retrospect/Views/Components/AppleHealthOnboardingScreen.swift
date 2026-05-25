import SwiftUI
import HealthKit

// === APPLE HEALTH ONBOARDING SCREEN ===
// Matches app's design aesthetic with Hedvig titles and SF Pro Display body text

struct AppleHealthOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    let onExit: (() -> Void)?
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    
    private let healthStore = HKHealthStore()
    
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
            // Apple Health icon and heading
            healthHeader
            
            // Main title
            mainTitle
            
            // Body text
            bodyText
            
            // Connection status or button
            connectionSection
                .padding(.top, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 40)
    }
    
    private var healthHeader: some View {
        HStack(spacing: 6) {
            // Health icon
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary)
            
            // Integration label
            Text("Integration")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mainTitle: some View {
        Text("Connect Apple Health.")
            .font(.custom("HedvigLettersSerif-24ptRegular", size: 32))
            .foregroundColor(LinearColors.textDisplay)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bodyText: some View {
        Text("Include steps, heart rate, sleep, and mindfulness data to enrich your weekly insights.")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(LinearColors.textSecondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .offset(y: bodyTextAnimating ? 0 : 20)
            .blur(radius: bodyTextAnimating ? 0 : 8)
            .opacity(bodyTextAnimating ? 1.0 : 0.3)
            .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isConnected {
                // Connected state
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
                // Connect button
                connectButton
            }
        }
        .padding(.top, 20)
    }
    
    private var connectButton: some View {
        Button(action: {
            connectToAppleHealth()
        }) {
            HStack(spacing: 12) {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(isConnecting ? "Connecting..." : "Connect Apple Health")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(Color.white)
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
        VStack(spacing: 16) {
            // Primary action button
            if isConnected {
                // Continue button when connected
                continueButton
            } else {
                // Connect button when not connected
                primaryActionButton
            }
            
            // Skip button
            skipButton
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }
    
    private var continueButton: some View {
        Button(action: {
            onNext()
        }) {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
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
    
    private var primaryActionButton: some View {
        Button(action: {
            if !isConnected {
                connectToAppleHealth()
            }
        }) {
            Text("Connect")
                .font(.system(size: 17, weight: .medium))
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
        }, perform: {
            if !isConnected {
                connectToAppleHealth()
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
    private func connectToAppleHealth() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showError = true
            errorMessage = "Apple Health is not available on this device."
            return
        }
        
        isConnecting = true
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                isConnecting = false
                if success {
                    isConnected = true
                } else {
                    showError = true
                    errorMessage = "Failed to connect to Apple Health. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AppleHealthOnboardingScreen(
        currentStep: 10,
        totalSteps: 12,
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

