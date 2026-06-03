//
//  DarkOnboardingFlow.swift
//  Retrospect
//
//  Figma-led onboarding flow matching the light privacy-card aesthetic.
//

import SwiftUI
import GoogleSignIn

// MARK: - Dark Onboarding Flow Container
struct DarkOnboardingFlow: View {
    var onComplete: (([RichGoal]) -> Void)? = nil

    @StateObject private var onboardingState = OnboardingState()

    private var screenIndex: Int {
        if !onboardingState.hasSignedIn { return 0 }
        if !onboardingState.questionsCompleted { return 1 }
        if !onboardingState.integrationsCompleted { return 2 }
        if !onboardingState.personaCompleted { return 3 }
        return 4
    }

    var body: some View {
        ZStack {
            if !onboardingState.hasSignedIn {
                WelcomeSignInPage(state: onboardingState)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if !onboardingState.questionsCompleted {
                VoiceGoalsPage(onComplete: { goals, name in
                    onboardingState.markQuestionsCompleted(name: name)
                    GoalsManager.shared.addRichGoals(goals)
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else if !onboardingState.integrationsCompleted {
                IntegrationsSetupPage(state: onboardingState)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if !onboardingState.personaCompleted {
                PersonaPickerPage(state: onboardingState, onComplete: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        onboardingState.markPersonaCompleted()
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                // Final closing — after integrations + persona
                OnboardingClosingPage(userName: onboardingState.userName) {
                    onboardingState.clearPersistedStep()
                    onComplete?([])
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: screenIndex)
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Dark Onboarding Screen Template
struct DarkOnboardingScreenTemplate: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?
    var onSkipStory: (() -> Void)? = nil
    
    @State private var displayedText = ""
    @State private var isAnimating = false
    @State private var showButton = false
    @State private var dragOffset: CGFloat = 0
    @State private var animationTimer: Timer?
    @State private var currentCharacterIndex = 0
    
    private let animationSpeed: Double = 0.04
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section
                topSection
                
                Spacer()
                
                // Main text — tap to complete animation instantly
                Text(displayedText)
                    .font(.custom("HedvigLettersSerif-24ptRegular", size: 38))
                    .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .onTapGesture {
                        if isAnimating {
                            animationTimer?.invalidate()
                            displayedText = title
                            currentCharacterIndex = title.count
                            withAnimation {
                                showButton = true
                                isAnimating = false
                            }
                        }
                    }
                
                Spacer()
                
                // Next button
                darkNextButton
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showButton)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .onAppear { startTextAnimation() }
        .onChange(of: title) { _, _ in resetAndAnimate() }
    }
    
    private var topSection: some View {
        VStack(spacing: 20) {
            // Skip button + drag handle row
            ZStack {
                if onExit != nil {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(LinearColors.Minimal.textTertiary.opacity(0.4))
                        .frame(width: 36, height: 4)
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
                
                if let skipAction = onSkipStory {
                    HStack {
                        Spacer()
                        Button(action: {
                            animationTimer?.invalidate()
                            skipAction()
                        }) {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                }
            }
            
            // Progress bar
            progressBar
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.border)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 3)
    }
    
    private var darkNextButton: some View {
        Button(action: onNext) {
            Text("Next")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearColors.Minimal.accent)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startTextAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        displayedText = ""
        showButton = false
        currentCharacterIndex = 0
        animationTimer?.invalidate()
        
        let characters = Array(title)
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { timer in
            guard currentCharacterIndex < characters.count else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        showButton = true
                        isAnimating = false
                    }
                }
                return
            }
            displayedText += String(characters[currentCharacterIndex])
            currentCharacterIndex += 1
            HapticManager.shared.playLightImpact()
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
}

// MARK: - Dark Privacy Onboarding Screen
struct DarkPrivacyOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?
    
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Icon & label
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Privacy")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        // Title
                        Text("Your data stays yours.")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 36))
                            .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.85))
                        
                        // Privacy points
                        VStack(alignment: .leading, spacing: 16) {
                            privacyPoint(icon: "iphone", text: "Everything is processed on your device")
                            privacyPoint(icon: "lock.fill", text: "Your entries are encrypted and private")
                            privacyPoint(icon: "xmark.icloud", text: "No data is sent to external servers")
                            privacyPoint(icon: "hand.raised.fill", text: "You control what information is included")
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Next button
                Button(action: onNext) {
                    Text("I Understand")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearColors.Minimal.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.border)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
            }
        }
        .frame(height: 3)
    }
    
    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(LinearColors.Minimal.accent)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textSecondary)
        }
    }
}

// MARK: - Dark Google Docs Onboarding Screen
struct DarkGoogleDocsOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    let onExit: (() -> Void)?
    
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Icon & label
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Integration")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        // Title
                        Text("Connect your Google Docs.")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 36))
                            .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.85))
                        
                        // Description
                        Text("Automatically include your recent Google Docs in your weekly reflections. All processing happens on your device.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .lineSpacing(4)
                        
                        Text("Your documents stay private and are never shared.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                        
                        // Connection status
                        if googleDocsService.isConnected {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.success)
                                
                                Text("Connected Successfully")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                            }
                            .padding(.top, 16)
                        } else {
                            // Connect button
                            Button(action: connectToGoogleDocs) {
                                HStack(spacing: 12) {
                                    if isConnecting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "link")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    
                                    Text(isConnecting ? "Connecting..." : "Connect Google Account")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearColors.Minimal.backgroundCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(isConnecting)
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 12) {
                    if !googleDocsService.isConnected {
                        Button(action: onSkip) {
                            Text("Skip for now")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: onNext) {
                        Text(googleDocsService.isConnected ? "Continue" : "Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearColors.Minimal.accent)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.border)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
            }
        }
        .frame(height: 3)
    }
    
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

// MARK: - Dark Apple Health Onboarding Screen
struct DarkAppleHealthOnboardingScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    let onExit: (() -> Void)?
    
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @State private var isConnecting = false
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Icon & label
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Integration")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        // Title
                        Text("Connect Apple Health.")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 36))
                            .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.85))
                        
                        // Description
                        Text("Include your health data in reflections—sleep, activity, and mindfulness—for a complete picture of your wellbeing.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .lineSpacing(4)
                        
                        // Health points
                        VStack(alignment: .leading, spacing: 16) {
                            healthPoint(icon: "bed.double.fill", text: "Sleep patterns and quality")
                            healthPoint(icon: "figure.walk", text: "Activity and exercise")
                            healthPoint(icon: "brain.head.profile", text: "Mindfulness minutes")
                        }
                        .padding(.top, 8)
                        
                        // Connection status
                        if healthKitEnabled {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.success)
                                
                                Text("Health Access Enabled")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                            }
                            .padding(.top, 16)
                        } else {
                            // Connect button
                            Button(action: requestHealthAccess) {
                                HStack(spacing: 12) {
                                    if isConnecting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    
                                    Text(isConnecting ? "Requesting..." : "Enable Health Access")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearColors.Minimal.backgroundCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(isConnecting)
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 12) {
                    if !healthKitEnabled {
                        Button(action: onSkip) {
                            Text("Skip for now")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearColors.Minimal.accent)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.border)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
            }
        }
        .frame(height: 3)
    }
    
    private func healthPoint(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(LinearColors.Minimal.iconPink)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textSecondary)
        }
    }
    
    private func requestHealthAccess() {
        isConnecting = true
        
        // Request HealthKit permissions
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                isConnecting = false
                healthKitEnabled = success
            }
        }
    }
}

// MARK: - Dark Goals Onboarding Screen
struct DarkGoalsOnboardingScreen: View {
    let onComplete: () -> Void
    
    @StateObject private var goalsManager = GoalsManager.shared
    @State private var newGoalText = ""
    @State private var contentOpacity: Double = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Icon & label
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                                .font(.system(size: 12, weight: .medium))
                            Text("Setup")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        .padding(.top, 60)
                        
                        // Title
                        Text("What do you want to focus on?")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 36))
                            .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.85))
                        
                        // Description
                        Text("Add some goals to help personalize your reflections. You can always change these later.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .lineSpacing(4)
                        
                        // Goal input
                        HStack(spacing: 12) {
                            TextField("Add a goal...", text: $newGoalText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .focused($isInputFocused)
                                .submitLabel(.done)
                                .onSubmit { addGoal() }
                            
                            Button(action: addGoal) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(newGoalText.isEmpty ? LinearColors.Minimal.textTertiary : LinearColors.Minimal.accent)
                            }
                            .disabled(newGoalText.isEmpty)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            isInputFocused ? LinearColors.Minimal.borderFocus : LinearColors.Minimal.border,
                                            lineWidth: isInputFocused ? 2 : 1
                                        )
                                )
                        )
                        .padding(.top, 8)
                        
                        // Current goals
                        if goalsManager.goalsCount > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Goals")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.textTertiary)
                                
                                ForEach(goalsManager.goals, id: \.self) { goal in
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(LinearColors.Minimal.accent)
                                        
                                        Text(goal)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(LinearColors.Minimal.textPrimary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            goalsManager.removeGoal(goal)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(LinearColors.Minimal.textTertiary)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(LinearColors.Minimal.backgroundCard)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.top, 16)
                        }
                        
                        // Suggestions
                        if goalsManager.goalsCount < 3 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggestions")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.textTertiary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(goalSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            goalsManager.addGoal(suggestion)
                                            HapticManager.shared.playLightImpact()
                                        }) {
                                            Text(suggestion)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(LinearColors.Minimal.backgroundCard)
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: onComplete) {
                        Text(goalsManager.goalsCount > 0 ? "Get Started" : "Skip for now")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(goalsManager.goalsCount > 0 ? LinearColors.Minimal.accent : LinearColors.Minimal.backgroundCard)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [LinearColors.Minimal.background.opacity(0), LinearColors.Minimal.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -60)
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
    
    private var goalSuggestions: [String] {
        let allSuggestions = [
            "Exercise more", "Better sleep", "Read daily", "Learn something new",
            "Reduce stress", "Eat healthier", "Save money", "Be more present",
            "Improve focus", "Build habits"
        ]
        return allSuggestions.filter { !goalsManager.goals.contains($0) }.prefix(6).map { $0 }
    }
    
    private func addGoal() {
        let trimmed = newGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goalsManager.addGoal(trimmed)
        newGoalText = ""
        HapticManager.shared.playLightImpact()
    }
}

// MARK: - Onboarding Closing Page (shown AFTER integrations + persona)

struct OnboardingClosingPage: View {
    let userName: String
    let onPlay: () -> Void

    private let lines: [String]
    @State private var visibleLine: Int = 0
    @State private var fullText: String = ""
    @State private var revealCount: Int = 0
    @State private var streamDone: Bool = false
    @State private var showButton: Bool = false
    @State private var timer: Timer?

    init(userName: String, onPlay: @escaping () -> Void) {
        self.userName = userName
        self.onPlay = onPlay
        self.lines = [
            userName.isEmpty ? "Now I know what matters to you." : "Now I know what matters to you, \(userName).",
            "Let's help you get there."
        ]
    }

    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 200)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<lines.count, id: \.self) { i in
                        if i < visibleLine {
                            Text(attributed(lines[i], count: lines[i].count))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if i == visibleLine {
                            Text(attributed(fullText, count: revealCount))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                if showButton {
                    OnboardingPrimaryButton(title: "Play Podcast") {
                        HapticManager.shared.playSuccessNotification()
                        onPlay()
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 34)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Spacer(minLength: 100)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear { streamLine(0) }
        .onDisappear { timer?.invalidate() }
    }

    private func attributed(_ full: String, count: Int) -> AttributedString {
        var attr = AttributedString(full)
        attr.font = .exposure(0, size: 30)
        attr.foregroundColor = OnboardingStyle.primaryText
        attr.tracking = -0.5
        if count < full.count {
            let start = attr.index(attr.startIndex, offsetByCharacters: count)
            attr[start..<attr.endIndex].foregroundColor = .clear
        }
        return attr
    }

    private func streamLine(_ idx: Int) {
        timer?.invalidate()
        visibleLine = idx
        fullText = lines[idx]
        revealCount = 0
        let total = lines[idx].count
        timer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { t in
            guard revealCount < total else {
                t.invalidate()
                if idx < lines.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { streamLine(idx + 1) }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showButton = true }
                    }
                }
                return
            }
            revealCount += 1
            HapticManager.shared.playTextStreamTick()
        }
    }
}

#Preview {
    DarkOnboardingFlow()
}
