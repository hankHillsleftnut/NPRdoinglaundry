import SwiftUI
import AVKit
import LocalAuthentication
import Combine

// Enum for bottom navigation tabs
enum HomeTab {
    case reflections
    case entries
}

// Input field enum for focus management
enum InputField {
    case reflections
}

struct HomeScreen: View {
    @Binding var shouldStartVoiceRecording: Bool
    
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    @StateObject private var goalsManager = GoalsManager.shared
    @State private var inputText = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isShowingDetails = false
    @State private var animateGeneration = false
    @State private var showingSplash = true
    @State private var showingNamePrompt = false
    @State private var userName = ""
    @State private var isEditingName = false
    @AppStorage("userName") private var storedUserName: String = ""
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    @AppStorage("experimentalViewEnabled") private var experimentalViewEnabled: Bool = false

    @State private var isShowingAudioPlayer = false
    @State private var isAudioPlaying = false
    @FocusState private var focusedField: InputField?
    
    // Navigation State
    @State private var selectedTab: HomeTab = .reflections
    @State private var isShowingSettings = false
    @State private var isShowingVideoJournal = false
    @State private var isShowingGoals = false
    
    // Launch Animation State
    @State private var isAppearing = true
    @State private var headerOffset: CGFloat = 50
    @State private var inputOffset: CGFloat = 100
    @State private var buttonOffset: CGFloat = 150
    
    // Header Transition Animation State
    @State private var headerBlurRadius: CGFloat = 0
    @State private var headerOpacity: Double = 1
    @State private var isTransitioningHeader = false
    @State private var previousTab: HomeTab = .reflections
    
    // Focus Mode State
    @State private var isInFocusMode = false
    @Namespace private var cardAnimation
    
    // Voice Recording
    @State private var showingVoiceRecording = false
    
    // Error Handling
    @State private var showingErrorAlert = false
    
    // Keyboard handling
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardAnimationDuration: Double = 0.3
    @State private var keyboardPublisher: AnyCancellable?
    @State private var keyboardHidePublisher: AnyCancellable?
    
    // MARK: - Computed Properties
    
    // Determine if user is ready to generate insights (has reflections + goals)
    private var isReadyToGenerate: Bool {
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        goalsManager.goalsCount > 0
    }
    
    // Determine if generate button should be shown (now only on reflections page)
    private var shouldShowFloatingGenerateButton: Bool {
        return selectedTab == .reflections && viewModel.transcript == nil
    }
    
    // Get entry count for header
    private var entryCount: Int {
        return EntryManager.shared.getAllEntries().count
    }
    
    
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Main Content Area
                    if showingSplash {
                        SplashScreenView(isPresented: $showingSplash)
                            .transition(.opacity)
                    } else if experimentalViewEnabled {
                        // Show Experimental View
                        ExperimentalView()
                            .transition(.opacity)
                    } else {
                        // Clean light grey background (CoStar style)
                        LinearColors.backgroundGrey
                            .ignoresSafeArea()
                        
                        // Content area
                        VStack(spacing: 16) {
                            // Top Navigation Bar
                            topNavigationBar
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            // Swipeable Tab content with card peeking
                            TabView(selection: $selectedTab) {
                                mainReflectionsView
                                    .tag(HomeTab.reflections)

                                EntriesView()
                                    .tag(HomeTab.entries)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .animation(.easeInOut(duration: 0.3), value: selectedTab)
                        }
                    }
                    
                    // Name Input Card
                    nameInputCard
                    
                    // Edit Name Popup
                    editNamePopup
                }
                // Overlay fixed elements that should not move with keyboard
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Compact Generate Insights Button - Fixed position
                        if shouldShowFloatingGenerateButton && !showingSplash {
                            VStack(spacing: 12) {
                                // Voice Recording Button
                                Button(action: {
                                    HapticManager.shared.playMediumImpact()
                                    showingVoiceRecording = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Voice Note")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [LinearColors.Minimal.iconPurple, LinearColors.Minimal.iconPurple.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .shadow(
                                                color: LinearColors.Minimal.iconPurple.opacity(0.3),
                                                radius: 12, x: 0, y: 6
                                            )
                                    )
                                }
                                
                                Group {
                                    // Show loading pill when processing, generate button when ready
                                    if viewModel.isProcessing {
                                        TransformingLoadingPill(viewModel: viewModel)
                                            .padding(.horizontal, 20)
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.8, anchor: .center).combined(with: .opacity),
                                                removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
                                            ))
                                    } else {
                                        HStack {
                                            Spacer()
                                            ClickyButton(
                                                text: viewModel.deepResearchMode ? "Generate Deep Insights" : "Generate Podcast",
                                                isDisabled: !isReadyToGenerate
                                            ) {
                                                generateTranscript()
                                            }
                                            .opacity(!isReadyToGenerate ? 0.6 : 1.0)
                                            Spacer()
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.8, anchor: .center).combined(with: .opacity),
                                            removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
                                        ))
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isProcessing)
                        }
                        
                        // Bottom Navigation Bar - Fixed at bottom
                        if !showingSplash {
                            bottomNavigationBar
                                .padding(.bottom, 15)
                        }
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            // Focus Mode Overlay
            if isInFocusMode {
                ZStack {
                    // Blurred/darkened background
                    LinearColors.Minimal.background
                        .opacity(0.4)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                        .onTapGesture {
                            HapticManager.shared.playLightImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isInFocusMode = false
                                focusedField = nil
                            }
                        }
                    
                    // Focus Mode Card
                    FocusModeCard(
                        text: $inputText,
                        isPresented: $isInFocusMode,
                        keyboardHeight: keyboardHeight,
                        isSendEnabled: !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onSend: {
                            saveReflectionAsEntry()
                        }
                    )
                    .scaleEffect(isInFocusMode ? 1.0 : 0.95, anchor: .center)
                    .rotation3DEffect(
                        .degrees(isInFocusMode ? 0 : 5),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.5
                    )
                    .offset(y: isInFocusMode ? 0 : 50)
                    .opacity(isInFocusMode ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isInFocusMode)
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .onChange(of: showingSplash) { newValue in
            if !newValue && storedUserName.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNamePrompt = true
                }
            }
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if newValue != nil {
                showingErrorAlert = true
            }
        }
        .alert("Error", isPresented: $showingErrorAlert, presenting: viewModel.errorMessage) { _ in
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: { error in
            Text(error)
        }
        .fullScreenCover(isPresented: $showingVoiceRecording) {
            VoiceRecordingView()
        }
        .onChange(of: shouldStartVoiceRecording) { _, shouldStart in
            if shouldStart {
                showingVoiceRecording = true
                shouldStartVoiceRecording = false  // Reset the trigger
            }
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            }
        }
    }
    
    // Configure audio session for playback
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: Spacing.sm) {
            // Dynamic header content based on selected tab
            if !isShowingAudioPlayer {
                VStack(alignment: .leading, spacing: 4) {
                    if selectedTab == .entries {
                        // Entries page header
                        Text("All Entries")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)
                        
                        Text("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
                            .font(.serifSubheadline)
                            .foregroundColor(LinearColors.textSecondary)
                    } else {
                        // Default header for reflections and video journal
                        Text(storedUserName.isEmpty ? "Retrospect" : "Hello, \(firstName)")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)
                            .onTapGesture {
                                userName = storedUserName
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isEditingName = true
                                }
                            }
                        
                        Text("Your Weekly Life Insights")
                            .font(.serifSubheadline)
                            .foregroundColor(LinearColors.textSecondary)
                    }
                }
                .blur(radius: headerBlurRadius)
                .opacity(headerOpacity)
                .animation(.easeInOut(duration: 0.15), value: headerBlurRadius)
                .animation(.easeInOut(duration: 0.15), value: headerOpacity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .leading)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .leading))
                ))
            }
            
            Spacer()
            
            // Settings Button
            Button(action: {
                HapticManager.shared.playNavigationTransition() // Modal presentation haptic
                isShowingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                    .foregroundColor(LinearColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.cardBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onChange(of: selectedTab) { newTab in
            // Only trigger blur animation when switching to/from Entries tab
            // (Reflections and Video Journal both show "Hello" header, so no animation needed between them)
            let shouldAnimate = (previousTab == .entries || newTab == .entries) && previousTab != newTab
            
            if shouldAnimate {
                guard !isTransitioningHeader else { return }
                isTransitioningHeader = true
                
                // Blur out
                withAnimation(.easeInOut(duration: 0.15)) {
                    headerBlurRadius = 10
                    headerOpacity = 0
                }
                
                // Blur in after content change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        headerBlurRadius = 0
                        headerOpacity = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTransitioningHeader = false
                    }
                }
            }
            
            // Update previous tab for next comparison
            previousTab = newTab
        }
    }
    

    
    // Bottom Navigation Bar
    private var bottomNavigationBar: some View {
        HStack {
            Spacer() // Center the navigation
            
            NavBarContainer(selectedTab: $selectedTab)
            
            Spacer() // Center the navigation
        }
        .padding(.bottom, Layout.safeAreaBottomOffset)
        .allowsHitTesting(true)
    }
    
    
    
    // Existing main content view, now wrapped in a computed property
    private var mainReflectionsView: some View {
        ZStack {
            // Clean background - no gradient needed (inherited from parent)
            Color.clear
            
            VStack(alignment: .leading, spacing: getSpacing()) {
                // New Generation Pill Button - Only show when transcript exists
                if viewModel.transcript != nil {
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.transcript = nil
                                }
                            }) {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.geistLabel)
                                                                                Text("New Generation")
                                                .font(.geistLabel)
                                }
                                .foregroundColor(LinearColors.buttonText)
                            }
                            .coStarPillButton()
                        }
                        
                        // Weekly Insights Results Card - Unified with consistent width
                        GeometryReader { geometry in
                            let cardWidth = geometry.size.width - (Layout.cardHorizontalPadding * 2) - (Layout.cardPeekAmount * 2)
                            let cardHeight = cardWidth / Layout.cardAspectRatio // Match other cards exactly
                            
                            HStack {
                                Spacer(minLength: Layout.cardPeekAmount)
                                VStack(spacing: 24) {
                                // Top section (waveform and text)
                                VStack(spacing: 32) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [
                                                    LinearColors.accent.opacity(0.15),
                                                    LinearColors.accent.opacity(0.05)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 160, height: 160)
                                            .blur(radius: 20)
                                        
                                        Circle()
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [
                                                    LinearColors.accent.opacity(0.2),
                                                    LinearColors.accent.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 140, height: 140)
                                        
                                        WaveformView()
                                            .frame(width: 90, height: 70)
                                            .foregroundColor(LinearColors.accent)
                                    }
                                    .padding(.top, 24)
                                    
                                    VStack(spacing: 12) {
                                        Text("Weekly Insights")
                                            .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                            .foregroundColor(LinearColors.textPrimary)
                                        
                                        Text("Your reflection has been processed")
                                            .font(.serifBody)
                                            .foregroundColor(LinearColors.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, Spacing.xl)
                                    }
                                }
                                
                                // Action buttons
                                VStack(spacing: 20) {
                                    Button(action: {
                                        if let audioURL = viewModel.transcript?.audioFileURL {
                                            do {
                                                configureAudioSession()
                                                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                                                audioPlayer?.prepareToPlay()
                                                audioPlayer?.play()
                                                isAudioPlaying = true
                                                withAnimation(.spring(response: 0.3)) {
                                                    isShowingAudioPlayer = true
                                                }
                                            } catch {
                                                print("Failed to play audio: \(error)")
                                                if let transcript = viewModel.transcript?.processedTranscript {
                                                    viewModel.generateSpeechWithElevenLabs(transcript: transcript)
                                                }
                                            }
                                        } else {
                                            if let transcript = viewModel.transcript?.processedTranscript {
                                                viewModel.generateSpeechWithElevenLabs(transcript: transcript)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: viewModel.transcript?.audioFileURL == nil ? "waveform" : "play.fill")
                                                .font(.serifButton)
                                                .fontWeight(.medium)
                                            Text(viewModel.transcript?.audioFileURL == nil ? "Generate Audio" : "Listen")
                                                .font(.serifButton)
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: Spacing.buttonHeight)
                                    }
                                    .coStarPrimaryButton(isDisabled: inputText.isEmpty || goalsManager.goalsCount == 0 || viewModel.isProcessing)
                                    
                                    Button(action: {
                                        HapticManager.shared.playLightImpact()
                                        // Debug logging for View Transcript button
                                        let transcriptText = viewModel.transcript?.processedTranscript ?? ""
                                        print("🔍 DEBUG: View Transcript button tapped")
                                        print("🔍 DEBUG: viewModel.transcript is nil: \(viewModel.transcript == nil)")
                                        print("🔍 DEBUG: processedTranscript is nil: \(viewModel.transcript?.processedTranscript == nil)")
                                        print("🔍 DEBUG: transcript length: \(transcriptText.count)")
                                        print("🔍 DEBUG: First 50 chars: \(String(transcriptText.prefix(50)))")
                                        isShowingDetails = true
                                    }) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "doc.text")
                                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            Text("View Transcript")
                                                .font(.serifButton)
                                        }
                                        .foregroundColor(LinearColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: Spacing.buttonHeight)
                                    }
                                    .coStarSecondaryButton()
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 32)
                            }
                            .coStarCard()
                            .frame(width: cardWidth, height: cardHeight)
                                Spacer(minLength: Layout.cardPeekAmount)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                
                if viewModel.transcript == nil {
                    // Weekly Reflections Card - Unified 3:5 aspect ratio for consistent design
                    GeometryReader { geometry in
                        let cardWidth = geometry.size.width - (Layout.cardHorizontalPadding * 2) - (Layout.cardPeekAmount * 2)
                        let cardHeight = cardWidth / Layout.cardAspectRatio // 3:5 ratio (width:height)
                        let textFieldHeight = cardHeight - 120 // Reserve space for title, goals button, and padding
                        
                        HStack {
                            Spacer(minLength: Layout.cardPeekAmount)
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: Spacing.listItemSpacing) {
                                    // Header with title and goals button
                                    HStack {
                                        Text("Weekly Reflections")
                                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            .foregroundColor(LinearColors.primaryText)
                                        
                                        Spacer()
                                        
                                        // Goals Button - small button matching settings style
                                        Button(action: {
                                            HapticManager.shared.playNavigationTransition() // Modal presentation haptic
                                            isShowingGoals = true
                                        }) {
                                            Image(systemName: "target")
                                                .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                                                .foregroundColor(LinearColors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: BorderRadius.button)
                                                        .fill(LinearColors.cardBackground)
                                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: BorderRadius.button)
                                                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                                                )
                                        }
                                        .disabled(viewModel.transcript != nil)
                                    }
                                    
                                    EnhancedTextField(
                                        placeholder: "Capture your thoughts, challenges, and experiences...",
                                        text: $inputText,
                                        isFocused: $focusedField,
                                        field: .reflections,
                                        showSendButton: !isInFocusMode,
                                        isSendEnabled: !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                        onSend: {
                                            saveReflectionAsEntry()
                                        }
                                    )
                                    .frame(
                                        height: max(textFieldHeight, keyboardHeight > 0 ? 120 : 180), // Minimum height when keyboard appears
                                        alignment: .top
                                    )
                                    .opacity(isInFocusMode ? 0 : 1)
                                }
                                .padding(Spacing.listItemSpacing) // Consistent thin padding around entire content
                            }
                            .coStarCard()
                            .frame(width: cardWidth, height: max(cardHeight, keyboardHeight > 0 ? 220 : cardHeight))
                            .overlay {
                                // Transparent overlay to capture all taps
                                if !isInFocusMode {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            HapticManager.shared.playLightImpact()
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                                isInFocusMode = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    focusedField = .reflections
                                                }
                                            }
                                        }
                                }
                            }
                            
                            Spacer(minLength: Layout.cardPeekAmount)
                        }
                    }
                    .frame(height: keyboardHeight > 0 ? 220 : nil) // Compact when keyboard is visible
                    .offset(y: isAppearing ? inputOffset : 0)
                    .opacity(isAppearing ? 0 : 1)
                    .disabled(viewModel.transcript != nil)
                    .animation(.spring(response: keyboardAnimationDuration, dampingFraction: 0.8), value: keyboardHeight)
                    
                    Spacer()
                        .padding(.bottom, keyboardHeight > 0 ? 10 : 240) // 100px above generate button
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Loading is now handled by the inline TransformingLoadingPill
            // Modal loading views removed for better UX
            
            // Bottom Mini Player - positioned at screen bottom
            if selectedTab == .reflections && viewModel.transcript != nil && !isShowingAudioPlayer {
                VStack {
                    Spacer()
                    BottomMiniPlayer(
                        transcript: viewModel.transcript!,
                        audioPlayer: $audioPlayer,
                        isPlaying: $isAudioPlaying,
                        onTap: {
                            HapticManager.shared.playLightImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isShowingAudioPlayer = true
                            }
                        },
                        onDismiss: {
                            HapticManager.shared.playMediumImpact()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                audioPlayer?.stop()
                                audioPlayer = nil
                                isAudioPlaying = false
                                viewModel.transcript = nil
                            }
                        }
                    )
                    .padding(.bottom, 100) // Above bottom navigation
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.transcript != nil)
                .zIndex(50) // Above content, below fullscreen player
            }
            
            // Fullscreen Podcast Card - Big Round Card Design
            if isShowingAudioPlayer, let transcript = viewModel.transcript?.processedTranscript {
                FullscreenPodcastCard(
                    transcript: transcript,
                    mood: viewModel.transcript?.mood,
                    generationType: viewModel.transcript?.generationType,
                    audioPlayer: $audioPlayer,
                    isPlaying: $isAudioPlaying,
                    onDismiss: {
                        HapticManager.shared.playMediumImpact()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isShowingAudioPlayer = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(100) // Above everything else
            }
        }
        .onAppear {
            // Trigger launch animation
            animateGeneration = true
            
            // Stagger the appearance of elements
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isAppearing = false
                }
            }
            
            // Setup keyboard notifications using Combine
            keyboardPublisher = NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { notification -> (height: CGFloat, duration: Double)? in
                    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                          let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                    else { return nil }
                    return (keyboardFrame.height, duration)
                }
                .sink { values in
                    withAnimation(.spring(response: values.duration, dampingFraction: 0.8)) {
                        keyboardHeight = values.height
                        keyboardAnimationDuration = values.duration
                    }
                }
            
            keyboardHidePublisher = NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .compactMap { notification -> Double? in
                    return notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                }
                .sink { duration in
                    withAnimation(.spring(response: duration, dampingFraction: 0.8)) {
                        keyboardHeight = 0
                        keyboardAnimationDuration = duration
                    }
                }
        }
        .onDisappear {
            // Clean up publishers
            keyboardPublisher?.cancel()
            keyboardHidePublisher?.cancel()
        }
        .onChange(of: viewModel.transcript?.audioFileURL) { newURL in
            if let url = newURL {
                do {
                    configureAudioSession()
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.prepareToPlay()
                    // Auto-open fullscreen player when audio is ready
                    withAnimation(.spring(response: 0.3)) {
                        isShowingAudioPlayer = true
                    }
                } catch {
                    print("Failed to load newly generated audio: \(error)")
                }
            }
        }
        .sheet(isPresented: $isShowingGoals) {
            GoalsView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingDetails) {
            EnhancedTranscriptDetailView(transcript: viewModel.transcript?.processedTranscript ?? "")
        }
    }
    
    // Waveform Animation View
    struct WaveformView: View {
        @State private var isAnimating = false
        
        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.accent)
                        .frame(width: 4, height: 20 + CGFloat.random(in: 0...40))
                        .scaleEffect(y: isAnimating ? 0.3 + CGFloat.random(in: 0...0.7) : 1)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.05),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
    }
    
    // MARK: Computed Properties
    // Computed property to get first name
    private var firstName: String {
        storedUserName.components(separatedBy: " ").first ?? storedUserName
    }
    
    // Computed property for header font size
    private var headerFontSize: CGFloat {
        focusedField != nil ? 28 : 36
    }
    
    // Computed property for subheader font size
    private var subheaderFontSize: CGFloat {
        focusedField != nil ? 14 : 18
    }
    
    // MARK: Functions
    
    // Helper functions for dynamic spacing
    private func getSpacing() -> CGFloat {
        let progress = 1 - min(1, keyboardHeight / 400)
        return 16 + (16 * progress) // Ranges from 16 to 32
    }
    
    private func getHeaderPadding() -> CGFloat {
        let progress = 1 - min(1, keyboardHeight / 400)
        return progress * 16 // Ranges from 0 to 16
    }
    
    private func getInputSpacing() -> CGFloat {
        let progress = 1 - min(1, keyboardHeight / 400)
        return 4 + (4 * progress) // Ranges from 4 to 8
    }
    
    private func getBottomPadding() -> CGFloat {
        let progress = 1 - min(1, keyboardHeight / 400)
        return keyboardHeight > 0 ? (10 + (10 * progress)) : 30 // Extra padding when keyboard is not visible
    }
    
    // Updated InputSection
    private func InputSection(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focusedField: FocusState<InputField?>.Binding,
        field: InputField,
        keyboardHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.primaryText)
                .padding(.horizontal, 4)
            
            EnhancedTextField(
                placeholder: placeholder,
                text: text,
                isFocused: focusedField,
                field: field
            )
            .frame(
                height: getInputHeight(field: field, keyboardHeight: keyboardHeight),
                alignment: .top
            )
        }
        .padding(.vertical, 8)
        .animation(.spring(response: keyboardAnimationDuration, dampingFraction: 0.8), value: keyboardHeight)
    }
    
    private func getInputHeight(field: InputField, keyboardHeight: CGFloat) -> CGFloat {
        let isFieldFocused = focusedField == field
        let isOtherFieldFocused = focusedField != nil && focusedField != field
        
        // Special handling for reflections field to achieve 4:3 aspect ratio
        if field == .reflections {
            if isFieldFocused {
                return keyboardHeight > 0 ? 180 : 240  // Taller when keyboard is visible, much taller when not
            } else if isOtherFieldFocused {
                let progress = min(1, keyboardHeight / 400)
                return 240 - (60 * progress) // Smoothly transitions from 240 to 180
            } else {
                return 240  // 4:3 aspect ratio height (assuming ~320px width)
            }
        } else {
            // Default heights for other fields
            if isFieldFocused {
                return keyboardHeight > 0 ? 80 : 120
            } else if isOtherFieldFocused {
                let progress = min(1, keyboardHeight / 400)
                return 140 - (80 * progress)
            } else {
                return 140
            }
        }
    }
    
    // MARK: - Save Reflection as Entry
    private func saveReflectionAsEntry() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Light haptic feedback for quick save
        HapticManager.shared.playLightImpact()
        
        let reflectionText = inputText
        let entryDate = Date()
        
        // Generate metadata for the text entry
        OpenAIService.shared.analyzeEntryForMetadata(content: reflectionText) { result in
            Task { @MainActor in
                switch result {
                case .success(let metadata):
                    let textEntry = Entry(
                        date: entryDate,
                        type: .text,
                        content: reflectionText,
                        videoURL: nil,
                        aiGeneratedTitle: metadata.title,
                        tags: metadata.tags,
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(textEntry)
                    print("✅ Saved reflection as entry: \(metadata.title ?? "Untitled")")
                    
                case .failure(let error):
                    print("⚠️ Failed to generate metadata: \(error), using fallback")
                    // Create entry without AI metadata (will use date-based title)
                    let textEntry = Entry(
                        date: entryDate,
                        type: .text,
                        content: reflectionText,
                        videoURL: nil,
                        aiGeneratedTitle: nil,
                        tags: [],
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(textEntry)
                    print("✅ Saved reflection as entry (no metadata)")
                }
                
                // Clear the input field
                inputText = ""
                
                // Close focus mode if open
                if isInFocusMode {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isInFocusMode = false
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    private func generateTranscript() {
        // Strong haptic feedback for major action
        HapticManager.shared.playHeavyImpact()
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        print("🚀 Generate button pressed")
        print("Input text length: \(inputText.count)")
                    print("Active Goals: \(goalsManager.goals)")
        print("Deep Research Mode: \(viewModel.deepResearchMode)")
        
        // Save the written reflection as a unified entry
        let reflectionText = inputText
        let entryDate = Date()
        
        // Generate metadata for the text entry
        OpenAIService.shared.analyzeEntryForMetadata(content: reflectionText) { result in
            Task { @MainActor in
                switch result {
                case .success(let metadata):
                    let textEntry = Entry(
                        date: entryDate,
                        type: .text,
                        content: reflectionText,
                        videoURL: nil,
                        aiGeneratedTitle: metadata.title,
                        tags: metadata.tags,
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(textEntry)
                    print("✅ Created unified text entry with metadata")
                    
                case .failure(let error):
                    print("⚠️ Failed to generate metadata: \(error), using fallback")
                    // Create entry without AI metadata (will use date-based title)
                    let textEntry = Entry(
                        date: entryDate,
                        type: .text,
                        content: reflectionText,
                        videoURL: nil,
                        aiGeneratedTitle: nil,
                        tags: [],
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(textEntry)
                }
            }
        }
        
        var combinedInput = inputText

        // Include recent voice session transcriptions
        let recentVoiceEntries = EntryManager.shared.getAllEntries()
            .filter { $0.type == .voice && $0.isIncludedInInsights }
            .prefix(10)
        if !recentVoiceEntries.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            combinedInput += "\n\nVoice Sessions:\n"
            for entry in recentVoiceEntries {
                combinedInput += "\n[\(dateFormatter.string(from: entry.date))]: \(entry.content)\n"
            }
        }
        
                    let goalsList = goalsManager.goalContextForGeneration

        // Choose generation method based on Deep Research mode
        if viewModel.deepResearchMode {
            viewModel.generateDeepResearchTranscript(text: combinedInput, goals: goalsList)
        } else {
            viewModel.generateTranscript(text: combinedInput, goals: goalsList)
        }
    }
    
    // Restore missing views
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Text("Welcome Back")
                .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                .foregroundColor(LinearColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Reflect on your journey")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(LinearColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    private var nameInputCard: some View {
        ZStack {
            // Name Input Popup
            if showingNamePrompt {
                LinearColors.Minimal.background.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Welcome to Retrospect")
                            .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                            .foregroundColor(LinearColors.primaryText)
                        
                        Text("What should we call you?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.secondaryText)
                    }
                    
                    EnhancedSingleLineTextField(placeholder: "First and last name", text: $userName)
                        .frame(maxWidth: 280)
                    
                    Button(action: {
                        let trimmedName = (userName.trimmingCharacters(in: .whitespacesAndNewlines))
                        if !trimmedName.isEmpty {
                            storedUserName = trimmedName
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingNamePrompt = false
                            }
                        }
                    }) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .frame(width: 200)
                    }
                    .coStarPrimaryButton(isDisabled: userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.inputBackground)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var editNamePopup: some View {
        Group {
            if isEditingName {
                LinearColors.Minimal.background.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                Text("Edit Your Name")
                                    .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                    .foregroundColor(LinearColors.textPrimary)
                                
                                Text("Enter your full name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(LinearColors.secondaryText)
                            }
                            
                            EnhancedSingleLineTextField(placeholder: "First and last name", text: $userName)
                                .frame(maxWidth: 280)
                            
                            HStack(spacing: 16) {
                                // Cancel button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isEditingName = false
                                    }
                                }) {
                                    Text("Cancel")
                                        .fontWeight(.semibold)
                                        .frame(width: 120)
                                }
                                .coStarSecondaryButton()
                                
                                // Save button
                                Button(action: {
                                    let trimmedName = (userName.trimmingCharacters(in: .whitespacesAndNewlines))
                                    if !trimmedName.isEmpty {
                                        storedUserName = trimmedName
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isEditingName = false
                                        }
                                    }
                                }) {
                                    Text("Save")
                                        .fontWeight(.semibold)
                                        .foregroundColor(LinearColors.Minimal.textPrimary)
                                        .frame(width: 120)
                                }
                                .coStarPrimaryButton(isDisabled: userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                            .padding(32)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.button)
                                    .fill(LinearColors.inputBackground)
                                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                            )
                            .padding(.horizontal, 40)
                            .transition(.scale.combined(with: .opacity))
                    )
                    .ignoresSafeArea()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditingName)
    }
    
    // Enhanced Transcript Detail View
    struct EnhancedTranscriptDetailView: View {
        let transcript: String
        @Environment(\.presentationMode) var presentationMode
        @State private var searchText = ""
        @State private var showShareSheet = false
        @GestureState private var dragOffset = CGSize.zero
        @State private var selectedSection: String?
        
        // Parse sections from markdown
        private var sections: [(title: String, content: String)] {
            let parts = transcript.components(separatedBy: "# ")
            return parts.dropFirst().compactMap { section -> (String, String)? in
                let lines = section.components(separatedBy: "\n")
                guard let title = lines.first else { return nil }
                let content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return (title, content)
            }
        }
        
        // Filtered sections based on search
        private var filteredSections: [(title: String, content: String)] {
            if searchText.isEmpty {
                return sections
            }
            return sections.filter { section in
                section.title.localizedCaseInsensitiveContains(searchText) ||
                section.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    LinearColors.background.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        // Custom Header
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Back Button
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.geistTitle)
                                        .foregroundColor(LinearColors.accent)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(LinearColors.inputBackground)
                                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                        )
                                }
                                
                                Text("Weekly Insights")
                                    .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                    .foregroundColor(LinearColors.primaryText)
                                
                                Spacer()
                                
                                // Share Button
                                Button(action: {
                                    showShareSheet = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(LinearColors.accent)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(LinearColors.inputBackground)
                                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                        )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(LinearColors.secondaryText)
                                
                                TextField("Search insights...", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 16))
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(LinearColors.secondaryText)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.button)
                                    .fill(LinearColors.inputBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        .background(LinearColors.background)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        
                        // Content
                        ScrollView {
                            VStack(spacing: 16) {
                                if filteredSections.isEmpty {
                                    VStack(spacing: 12) {
                                                                    Image(systemName: "magnifyingglass")
                                .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                .foregroundColor(LinearColors.textSecondary)
                                        Text("No matching insights found")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(LinearColors.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                                } else {
                                    ForEach(filteredSections, id: \.title) { section in
                                        VStack(alignment: .leading, spacing: 12) {
                                            // Section Header
                                            Text(section.title)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(LinearColors.primaryText)
                                                .padding(.bottom, 4)
                                            
                                            // Section Content
                                            Text(section.content)
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundColor(LinearColors.secondaryText)
                                                .lineSpacing(4)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(20)
                                        .background(
                                            RoundedRectangle(cornerRadius: BorderRadius.button)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                        )
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedSection = selectedSection == section.title ? nil : section.title
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                    .frame(height: 20)
                            }
                            .padding(.top)
                        }
                    }
                }
                .offset(x: dragOffset.width)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.width > 0 {
                                state = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > geometry.size.width * 0.3 {
                                HapticManager.shared.playMediumImpact() // Swipe dismiss confirmation
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                )
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                let textToShare = sections.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n")
                ShareSheet(activityItems: [textToShare])
            }
        }
    }
    

    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            HomeScreen(shouldStartVoiceRecording: .constant(false))
        }
    }
    

    

    
    // Header View Component
    private struct HeaderView: View {
        let storedUserName: String
        let firstName: String
        let headerFontSize: CGFloat
        let subheaderFontSize: CGFloat
        let headerOffset: CGFloat
        let isAppearing: Bool
        let focusedField: InputField?

        @Binding var userName: String
        @Binding var isEditingName: Bool
        
        var body: some View {
            // Empty view since header content is now in topNavigationBar
            EmptyView()
        }
    }
}

// MARK: - Experimental View
struct ExperimentalView: View {
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    @StateObject private var videoViewModel = VideoJournalViewModel()
    @StateObject private var speechRecognizer = SpeechRecognizerManager()
    @AppStorage("userName") private var storedUserName: String = ""
    @State private var inputText = ""
    @State private var currentWeekIndex = 0
    @State private var isRecordingVoice = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAudioPlaying = false
    @State private var isShowingSettings = false
    @FocusState private var isInputFocused: Bool
    
    // Mock podcast data for now
    private let mockPodcasts = [
        MockPodcast(week: "This Week", topic: "Love and Relationships", transcript: "Mock transcript for this week about love and relationships..."),
        MockPodcast(week: "Last Week", topic: "Career Growth", transcript: "Mock transcript for last week about career and professional development..."),
        MockPodcast(week: "2 Weeks Ago", topic: "Personal Health", transcript: "Mock transcript about maintaining balance and personal wellness..."),
        MockPodcast(week: "3 Weeks Ago", topic: "Family Connections", transcript: "Mock transcript about strengthening family bonds and communication...")
    ]
    
    private var firstName: String {
        storedUserName.components(separatedBy: " ").first ?? storedUserName
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            LinearColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Podcast Cards Section
                        podcastCardsSection
                        
                        // Input Card Section
                        inputCardSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
            // Static Generate Podcast Button - stays in place when keyboard appears
            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ClickyButton(
                            text: "Generate Podcast",
                            isDisabled: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            generatePodcast()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50) // Above safe area
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: inputText.isEmpty)
            }
        }
        .onAppear {
            setupAudioSession()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storedUserName.isEmpty ? "Hello, Shaurya" : "Hello, \(firstName)")
                        .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                        .foregroundColor(LinearColors.textPrimary)
                    
                    Text("This week's podcast is about \(mockPodcasts[currentWeekIndex].topic.lowercased())")
                        .font(.serifLabel)
                        .foregroundColor(LinearColors.textSecondary)
                }
                
                Spacer()
                
                // Settings Button
                Button(action: {
                    HapticManager.shared.playNavigationTransition()
                    isShowingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.button)
                                .fill(LinearColors.cardBackground)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.button)
                                .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Podcast Cards Section
    private var podcastCardsSection: some View {
        VStack(spacing: 16) {
            // Scrollable Podcast Cards
            TabView(selection: $currentWeekIndex) {
                ForEach(Array(mockPodcasts.enumerated()), id: \.offset) { index, podcast in
                    podcastCard(for: podcast)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
            
            // Week Indicators
            HStack(spacing: 8) {
                ForEach(Array(mockPodcasts.enumerated()), id: \.offset) { index, _ in
                    Circle()
                        .fill(currentWeekIndex == index ? LinearColors.accent : LinearColors.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentWeekIndex)
                }
            }
        }
    }
    
    private func podcastCard(for podcast: MockPodcast) -> some View {
        VStack(spacing: 20) {
            // Album Art with Mesh Gradient
            Button(action: {
                playPodcast(podcast)
            }) {
                ZStack {
                    // Mesh Gradient Background
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            SIMD2<Float>(0.0, 0.0),
                            SIMD2<Float>(0.5, 0.0),
                            SIMD2<Float>(1.0, 0.0),
                            SIMD2<Float>(0.0, 0.5),
                            SIMD2<Float>(0.5, 0.5),
                            SIMD2<Float>(1.0, 0.5),
                            SIMD2<Float>(0.0, 1.0),
                            SIMD2<Float>(0.5, 1.0),
                            SIMD2<Float>(1.0, 1.0)
                        ],
                        colors: [
                            LinearColors.terraCottaLight,
                            LinearColors.accent,
                            LinearColors.terraCottaDark,
                            LinearColors.terraCottaSubtle,
                            LinearColors.warmHighlight,
                            LinearColors.terraCottaLight,
                            LinearColors.terraCottaDark,
                            LinearColors.accent,
                            LinearColors.terraCottaLight
                        ]
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Play Icon
                    Image(systemName: isAudioPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .frame(width: 200, height: 200)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Podcast Info
            VStack(spacing: 8) {
                Text(podcast.week)
                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                    .foregroundColor(LinearColors.textPrimary)
                
                Text("About \(podcast.topic)")
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Input Card Section
    private var inputCardSection: some View {
        VStack(spacing: 0) {
            // Input Text Field
            VStack(alignment: .leading, spacing: 12) {
                TextField("Type something...", text: $inputText, axis: .vertical)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textPrimary)
                    .focused($isInputFocused)
                    .lineLimit(3...6)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.input)
                            .fill(LinearColors.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: BorderRadius.input)
                                    .stroke(isInputFocused ? LinearColors.inputFocusBorder : LinearColors.inputBorder, lineWidth: BorderWidth.standard)
                            )
                    )
                
                // Voice and Video Recording Buttons
                HStack(spacing: 12) {
                    // Voice Recording Button
                    Button(action: {
                        toggleVoiceRecording()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.geistBody)
                                .foregroundColor(isRecordingVoice ? .red : LinearColors.accent)
                            
                            Text(isRecordingVoice ? "Stop Recording" : "Record Voice")
                                .font(.serifButton)
                                .foregroundColor(isRecordingVoice ? .red : LinearColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.button)
                                .fill(isRecordingVoice ? LinearColors.Minimal.errorSubtle : LinearColors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BorderRadius.button)
                                        .stroke(isRecordingVoice ? LinearColors.Minimal.recordingPulse : LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Video Recording Button
                    Button(action: {
                        startVideoRecording()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "video.circle.fill")
                                .font(.geistBody)
                                .foregroundColor(LinearColors.accent)
                            
                            Text("Record Video")
                                .font(.serifButton)
                                .foregroundColor(LinearColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.button)
                                .fill(LinearColors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BorderRadius.button)
                                        .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Shadows.cardShadow.color,
                        radius: Shadows.cardShadow.radius,
                        x: Shadows.cardShadow.x,
                        y: Shadows.cardShadow.y
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                    )
            )
        }
    }
    
    // MARK: - Functions
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowAirPlay, .defaultToSpeaker]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    

    
    private func playPodcast(_ podcast: MockPodcast) {
        // For now, just simulate podcast playback
        HapticManager.shared.playMediumImpact()
        
        // Simulate playing audio - in real implementation, this would use the actual audio file
        print("Playing podcast: \(podcast.topic)")
        withAnimation(.easeInOut(duration: 0.2)) {
            isAudioPlaying.toggle()
        }
        
        // Auto-stop after 3 seconds for demo purposes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAudioPlaying = false
            }
        }
    }
    
    private func toggleVoiceRecording() {
        HapticManager.shared.playLightImpact()
        
        if isRecordingVoice {
            // Stop recording
            speechRecognizer.stopTranscribing()
            isRecordingVoice = false
        } else {
            // Start recording
            speechRecognizer.requestAuthorization { authorized in
                if authorized {
                    speechRecognizer.startTranscribing()
                    isRecordingVoice = true
                }
            }
        }
    }
    
    private func startVideoRecording() {
        HapticManager.shared.playMediumImpact()
        
        // For now, just simulate video recording start
        // In a real implementation, this would integrate with the existing VideoJournalView
        print("Starting video recording...")
        
        // TODO: Integrate with existing video recording functionality
        // This could present a full-screen video recording view
    }
    
    private func generatePodcast() {
        HapticManager.shared.playHeavyImpact()
        
        // Dismiss keyboard
        isInputFocused = false
        
        print("🚀 Generate Podcast button pressed")
        print("Input text length: \(inputText.count)")
        print("Input text: \(inputText)")
        
        // Use the existing transcript generation functionality
        // This would integrate with the existing podcast generation system
        viewModel.generateTranscript(text: inputText, goals: [])
        
        // Clear input after generation starts
        inputText = ""
    }
}

// MARK: - Mock Data Model
struct MockPodcast {
    let week: String
    let topic: String
    let transcript: String
}
