//
//  DarkAppContainer.swift
//  Retrospect
//
//  Main app container for the dark minimal UI
//  Hosts 5-tab navigation, global audio state, mini player, and voice recording
//

import SwiftUI
import AVFoundation
import DeviceActivity

/// Global audio state manager for the dark UI
class DarkAudioManager: ObservableObject {
    static let shared = DarkAudioManager()
    
    @Published var currentTranscript: TranscriptModel?
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var showMiniPlayer: Bool = false
    @Published var showFullPlayer: Bool = false
    @Published var lastError: String?
    @Published var isGeneratingAudio: Bool = false
    @Published var audioGenerationStatus: String = ""
    
    private init() {
        configureAudioSession()
    }
    
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
            lastError = "Audio session error: \(error.localizedDescription)"
        }
    }
    
    /// Opens transcript view (works even without audio)
    func showTranscript(transcript: TranscriptModel) {
        print("📖 Opening transcript view for: \(transcript.id)")
        print("   - Has audio URL: \(transcript.audioFileURL != nil)")
        print("   - Has processed transcript: \(transcript.processedTranscript != nil)")
        print("   - Mood: \(transcript.mood ?? "unknown")")
        
        currentTranscript = transcript
        showFullPlayer = true
        lastError = nil
        
        // Try to play audio if available
        if let audioURL = transcript.audioFileURL {
            playAudio(url: audioURL)
        } else {
            print("⚠️ No audio URL available - showing transcript only")
            lastError = "No audio generated yet. View transcript only."
        }
    }
    
    func playPodcast(transcript: TranscriptModel) {
        print("🎙️ playPodcast called for transcript: \(transcript.id)")
        
        // Always set the transcript so UI can display it
        currentTranscript = transcript
        
        guard let audioURL = transcript.audioFileURL else {
            print("❌ No audio URL available for podcast")
            lastError = "No audio file available. The podcast transcript exists but audio hasn't been generated."
            // Still show the player UI so user can see transcript
            showMiniPlayer = false
            return
        }
        
        print("🔊 Audio URL found: \(audioURL.path)")
        playAudio(url: audioURL)
    }
    
    private func playAudio(url: URL) {
        print("🔊 Attempting to play audio from: \(url.path)")
        
        // Check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("❌ Audio file does not exist at path: \(url.path)")
            lastError = "Audio file not found at: \(url.lastPathComponent)"
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            showMiniPlayer = true
            lastError = nil
            print("✅ Audio playback started successfully")
            print("   - Duration: \(audioPlayer?.duration ?? 0) seconds")
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
            lastError = "Failed to play audio: \(error.localizedDescription)"
            isPlaying = false
        }
    }
    
    func togglePlayback() {
        guard let player = audioPlayer else {
            print("⚠️ togglePlayback: No audio player available")
            return
        }
        
        if isPlaying {
            player.pause()
            print("⏸️ Audio paused")
        } else {
            player.play()
            print("▶️ Audio resumed")
        }
        isPlaying.toggle()
    }
    
    func stopPlayback() {
        print("⏹️ Stopping playback")
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        showMiniPlayer = false
        currentTranscript = nil
        lastError = nil
    }
    
    func seekTo(progress: Double) {
        guard let player = audioPlayer else { return }
        let newTime = player.duration * progress
        player.currentTime = newTime
        print("⏩ Seeked to: \(Int(newTime))s")
    }
}

struct DarkAppContainer: View {
    @StateObject private var audioManager = DarkAudioManager.shared
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    @StateObject private var goalsManager = GoalsManager.shared
    
    @State private var selectedTab: MinimalTab = .journal
    @State private var showingVoiceRecording = false
    @State private var hasNewPodcast = false // Shows notification pill on Podcasts tab
    @Binding var shouldStartVoiceRecording: Bool
    
    var body: some View {
        ZStack {
            // Dark background
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            // Main content based on selected tab
            VStack(spacing: 0) {
                // Tab content
                Group {
                    switch selectedTab {
                    case .journal:
                        DarkJournalView(
                            viewModel: viewModel,
                            goalsManager: goalsManager,
                            audioManager: audioManager,
                            showingVoiceRecording: $showingVoiceRecording
                        )
                    case .podcasts:
                        DarkPodcastsView(
                            viewModel: viewModel,
                            audioManager: audioManager
                        )
                    case .goals:
                        DarkGoalsView()
                    case .entries:
                        DarkEntriesView()
                    case .settings:
                        DarkSettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Mini player (when audio is playing and not on full player)
                if audioManager.showMiniPlayer && !audioManager.showFullPlayer {
                    DarkMiniPlayer(audioManager: audioManager)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Separator (only on Journal tab)
                if selectedTab == .journal {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearColors.Minimal.pureBlack)
                            .frame(height: 1.5)
                        Rectangle()
                            .fill(LinearColors.Minimal.border)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 8)
                }
                
                // Tab bar - stays fixed
                MinimalTabBar(selectedTab: $selectedTab, hasNewPodcast: hasNewPodcast)
                    .padding(.horizontal, 8)
                    .padding(.bottom, -6)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showingVoiceRecording) {
            DarkVoiceRecordingView()
        }
        .fullScreenCover(isPresented: $audioManager.showFullPlayer) {
            if let transcript = audioManager.currentTranscript {
                DarkAudioPlayerView(
                    transcript: transcript,
                    audioManager: audioManager
                )
            } else {
                // Fallback view when no transcript is available
                ZStack {
                    LinearColors.Minimal.background
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Text("No Podcast Available")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        if let error = audioManager.lastError {
                            Text(error)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            audioManager.showFullPlayer = false
                        }) {
                            Text("Dismiss")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(LinearColors.Minimal.accent))
                        }
                        .padding(.top, 12)
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .onChange(of: shouldStartVoiceRecording) { _, shouldStart in
            if shouldStart {
                showingVoiceRecording = true
                shouldStartVoiceRecording = false
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.showMiniPlayer)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
    }
}

// MARK: - Hold Recording State
enum HoldRecordingState {
    case idle
    case recording
    case saved
    case tooShort
}

// MARK: - Session Tracker for Headline Animation
// This tracks whether the headline animation has played THIS SESSION (resets on app launch)
class HeadlineAnimationTracker: ObservableObject {
    static let shared = HeadlineAnimationTracker()
    @Published var hasPlayedThisSession: Bool = false
    
    private init() {}
    
    func reset() {
        hasPlayedThisSession = false
    }
}

// MARK: - Dark Journal View (Home Tab)
struct DarkJournalView: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @ObservedObject var goalsManager: GoalsManager
    @ObservedObject var audioManager: DarkAudioManager
    @Binding var showingVoiceRecording: Bool
    
    @StateObject private var screenTimeService = ScreenTimeService.shared
    
    @State private var journalText = ""
    @State private var attachedImages: [UIImage] = []
    @State private var isInFocusMode = false
    @State private var showImagePicker = false
    @State private var keyboardHeight: CGFloat = 0
    
    // Session-based animation flag (plays once per app session, resets on app launch)
    @ObservedObject private var animationTracker = HeadlineAnimationTracker.shared
    
    // Typewriter animation states
    @State private var displayedText: String = ""
    @State private var headlineOpacity: Double = 0
    private let fullHeadlineText = "How do you\nwant to rewire\nthe mind\ntoday?"
    
    // Animation states for other elements
    @State private var inputOpacity: Double = 0
    @State private var inputOffset: CGFloat = 20
    
    // Hold-to-record states
    @StateObject private var holdRecordingManager = AudioRecordingManager()
    @State private var isHoldRecording = false
    @State private var holdRecordingStarted = false
    @State private var recordingState: HoldRecordingState = .idle
    @State private var ellipsisCount = 0
    @State private var ellipsisTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hidden DeviceActivityReport — triggers the extension silently
                // so screen time data is written to App Group every time the app opens
                if screenTimeService.isAuthorized {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("Total Activity"),
                        filter: DeviceActivityFilter(
                            segment: .daily(
                                during: DateInterval(
                                    start: Calendar.current.startOfDay(for: Date()),
                                    end: Date()
                                )
                            )
                        )
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
                }
                
                // Main content
                VStack(spacing: 0) {
                    // Hold-to-record zone (headline + scroll area only)
                    VStack(spacing: 0) {
                        // Fixed headline area (not scrollable)
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                                .frame(height: 40)
                            
                            // Screen time ambient insight (only when authorized and data exists)
                            if !isHoldRecording, screenTimeService.isAuthorized, let nugget = screenTimeNugget {
                                HStack(spacing: 6) {
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(nugget)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.6))
                                .padding(.horizontal, 28)
                                .padding(.bottom, 8)
                                .transition(.opacity)
                            }
                            
                            // Headline - changes to Recording indicator during hold recording
                            if isHoldRecording {
                                if recordingState == .saved {
                                    // Saved state - clean checkmark pill
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.green)
                                        Text("Saved")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(LinearColors.Minimal.textPrimary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(LinearColors.Minimal.backgroundCard)
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(LinearColors.Minimal.success.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 28)
                                } else if recordingState == .tooShort {
                                    // Too short feedback pill
                                    HStack(spacing: 10) {
                                        Image(systemName: "hand.raised")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(LinearColors.Minimal.textTertiary)
                                        Text("Hold longer to record")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(LinearColors.Minimal.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(LinearColors.Minimal.backgroundCard)
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                            )
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 28)
                                } else {
                                    // Recording state - refined pill with duration and waveform
                                    RecordingIndicatorPill(duration: recordingDuration)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 28)
                                }
                                Spacer().frame(height: 0)
                            } else {
                                // Normal headline - typewriter effect on first launch
                                Text(displayedText)
                                    .font(.minimalHeadline)
                                    .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.7))
                                    .lineSpacing(10)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 28)
                                    .opacity(headlineOpacity)
                            }
                            
                            Spacer()
                                .frame(height: 40)
                        }
                        
                        // Scrollable content area
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                // Featured podcast card (if transcript exists)
                                if let transcript = viewModel.transcript, transcript.audioFileURL != nil {
                                    DarkFeaturedPodcastCard(
                                        transcript: transcript,
                                        audioManager: audioManager
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 24)
                                }
                                
                                // Processing indicator
                                if viewModel.isProcessing {
                                    DarkLoadingPill(viewModel: viewModel)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 24)
                                }
                                
                                Spacer(minLength: 100)
                            }
                        }
                        .opacity(isHoldRecording ? 0.3 : 1.0)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                            .onChanged { value in
                                switch value {
                                case .first(true):
                                    // Long press detected, start recording
                                    if !isHoldRecording && !isInFocusMode {
                                        startHoldRecording()
                                    }
                                case .second(true, _):
                                    // Holding — just keep recording, no drag tracking needed
                                    break
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                if isHoldRecording {
                                    // Release = stop recording (cancel if under 2 seconds)
                                    let tooShort = recordingDuration < 2.0
                                    endHoldRecording(cancelled: tooShort)
                                }
                            }
                    )
                    
                    // Input area at bottom (NOT part of hold-to-record zone)
                    if !isHoldRecording {
                        VStack(spacing: 16) {
                            // Generate button (when ready)
                            if !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && goalsManager.goalsCount > 0 && !viewModel.isProcessing {
                                Button(action: {
                                    HapticManager.shared.playMediumImpact()
                                    viewModel.generateTranscript(text: journalText, goals: goalsManager.goals)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Generate Podcast")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(LinearColors.Minimal.accent)
                                    )
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Hold to record hint
                            HStack(spacing: 6) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Hold anywhere above to record")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.5))
                            
                            // Journal input - tappable to enter focus mode
                            MinimalJournalInput(
                                text: $journalText,
                                attachedImages: $attachedImages,
                                onMicTap: {
                                    showingVoiceRecording = true
                                },
                                onPlusTap: {
                                    showImagePicker = true
                                },
                                onTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        isInFocusMode = true
                                    }
                                }
                            )
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 24)
                        .opacity(inputOpacity)
                        .offset(y: inputOffset)
                    }
                }
                
                // "Too short" feedback when released before 2 seconds
                // (cancel zone and waveform pill removed — release to stop)
            
            // Focus Mode Overlay
            if isInFocusMode {
                ZStack {
                    // Darkened background
                    Color.black
                        .opacity(0.7)
                        .ignoresSafeArea()
                        .onTapGesture {
                            HapticManager.shared.playLightImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isInFocusMode = false
                            }
                        }
                    
                    // Focus Mode Card
                    DarkFocusModeCard(
                        text: $journalText,
                        isPresented: $isInFocusMode,
                        keyboardHeight: keyboardHeight,
                        isSendEnabled: !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onSend: {
                            saveReflectionAsEntry()
                        },
                        onMicTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isInFocusMode = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingVoiceRecording = true
                            }
                        }
                    )
                    .scaleEffect(isInFocusMode ? 1.0 : 0.95, anchor: .center)
                    .opacity(isInFocusMode ? 1 : 0)
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        }
        .onAppear {
            animateIn()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
            ellipsisTimer?.invalidate()
        }
        .overlay {
            if showImagePicker {
                // Full-screen overlay that covers everything including tab bar
                ZStack {
                    // Dark overlay covering entire screen
                    LinearColors.Minimal.overlayHeavy
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showImagePicker = false
                            }
                        }
                    
                    // Attachment picker positioned at bottom
                    VStack {
                        Spacer()
                        AttachmentPickerSheet(
                            isPresented: $showImagePicker,
                            selectedImages: $attachedImages,
                            onDeepResearch: {
                                // TODO: Trigger deep research podcast generation
                            }
                        )
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showImagePicker)
    }
    
    // MARK: - Animation Functions
    
    private func animateIn() {
        if animationTracker.hasPlayedThisSession {
            // Instant show if animation already played this session
            displayedText = fullHeadlineText
            headlineOpacity = 1
            
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                inputOpacity = 1
                inputOffset = 0
            }
        } else {
            // First-time typewriter animation for headline (once per session)
            headlineOpacity = 1
            typeOutHeadline()
            
            // Input appears immediately with bounce (doesn't wait for typewriter)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.3)) {
                inputOpacity = 1
                inputOffset = 0
            }
            
            // Mark animation as played after typewriter completes
            let typewriterDuration = Double(fullHeadlineText.count) * 0.025 + 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + typewriterDuration + 0.3) {
                animationTracker.hasPlayedThisSession = true
            }
        }
    }
    
    private func typeOutHeadline() {
        displayedText = ""
        let characters = Array(fullHeadlineText)
        
        for (index, character) in characters.enumerated() {
            // Fast typing: 25ms per character
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.025) {
                displayedText += String(character)
                // Haptic feedback for every character - using soft impact for subtle, rapid feedback
                HapticManager.shared.playSoftImpact()
            }
        }
    }
    
    // MARK: - Hold-to-Record Functions
    
    private func startHoldRecording() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isHoldRecording = true
            recordingState = .recording
        }
        
        // Haptic feedback
        HapticManager.shared.playMediumImpact()
        
        // Start recording duration timer
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
        
        // Start ellipsis animation
        ellipsisCount = 0
        ellipsisTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            ellipsisCount = (ellipsisCount + 1) % 4
        }
        
        // Start actual recording
        holdRecordingManager.requestPermissions { granted in
            if granted {
                self.holdRecordingManager.startRecording()
            }
        }
    }
    
    private func endHoldRecording(cancelled: Bool) {
        ellipsisTimer?.invalidate()
        ellipsisTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if cancelled {
            // Cancel recording (too short or explicit cancel)
            holdRecordingManager.cancelRecording()
            HapticManager.shared.playLightImpact()
            
            // Show "too short" feedback briefly
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                recordingState = .tooShort
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isHoldRecording = false
                    recordingState = .idle
                }
            }
        } else {
            // Save recording
            holdRecordingManager.stopRecording { result in
                switch result {
                case .success(let (audioURL, transcription)):
                    let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Reject if transcription is empty and audio file doesn't exist or is tiny
                    let audioFileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
                    let hasUsableAudio = FileManager.default.fileExists(atPath: audioURL.path) && audioFileSize > 1000
                    
                    guard !trimmedTranscription.isEmpty || hasUsableAudio else {
                        print("⚠️ Discarding empty voice recording — no transcription and no usable audio")
                        HapticManager.shared.playErrorNotification()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            recordingState = .tooShort
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isHoldRecording = false
                                recordingState = .idle
                            }
                        }
                        return
                    }
                    
                    // Create and save entry
                    let entryId = UUID()
                    do {
                        try FileStorageManager.shared.moveAudio(from: audioURL, to: entryId)
                        
                        var title = "Voice Note"
                        if !trimmedTranscription.isEmpty {
                            let words = trimmedTranscription.split(separator: " ").prefix(8)
                            title = words.joined(separator: " ")
                            if trimmedTranscription.split(separator: " ").count > 8 {
                                title += "..."
                            }
                        }
                        
                        let entry = Entry(
                            id: entryId,
                            type: .voice,
                            content: trimmedTranscription,
                            audioURL: FileStorageManager.shared.getAudioURL(for: entryId),
                            aiGeneratedTitle: title,
                            tags: []
                        )
                        
                        EntryManager.shared.addEntry(entry)
                    } catch {
                        print("Failed to save audio: \(error)")
                    }
                    
                    // Show saved state
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        recordingState = .saved
                    }
                    
                    HapticManager.shared.playSuccessNotification()
                    
                    // Dismiss after showing saved state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isHoldRecording = false
                            recordingState = .idle
                        }
                    }
                    
                case .failure(let error):
                    print("Recording failed: \(error)")
                    HapticManager.shared.playErrorNotification()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isHoldRecording = false
                        recordingState = .idle
                    }
                }
            }
        }
    }
    
    // MARK: - Screen Time Ambient Insight
    
    private var screenTimeNugget: String? {
        guard let summary = screenTimeService.latestSummary else { return nil }
        
        let history = screenTimeService.weeklyHistory
        let todayMinutes = summary.totalScreenTimeMinutes
        
        // If we have history, compute trend
        if history.count >= 2 {
            let previousDays = history.filter { $0.date != summary.date }
            guard !previousDays.isEmpty else {
                return formatSimpleNugget(summary)
            }
            let avgMinutes = previousDays.reduce(0) { $0 + $1.totalScreenTimeMinutes } / previousDays.count
            
            if avgMinutes > 0 {
                let changePercent = Int(round(Double(todayMinutes - avgMinutes) / Double(avgMinutes) * 100))
                
                if changePercent > 15 {
                    return "Screen time is up \(changePercent)% today"
                } else if changePercent < -15 {
                    return "Screen time is down \(abs(changePercent))% today"
                } else {
                    return "\(formatTime(todayMinutes)) on screen today"
                }
            }
        }
        
        return formatSimpleNugget(summary)
    }
    
    private func formatSimpleNugget(_ summary: ScreenTimeSummary) -> String? {
        let minutes = summary.totalScreenTimeMinutes
        if minutes < 5 { return nil }
        
        if summary.totalPickups > 60 {
            return "\(summary.totalPickups) pickups today · \(formatTime(minutes)) on screen"
        }
        
        if let topApp = summary.appUsage.first, topApp.minutes > 30 {
            return "\(formatTime(minutes)) on screen · \(topApp.appName) \(formatTime(topApp.minutes))"
        }
        
        return "\(formatTime(minutes)) on screen today"
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
    
    private func saveReflectionAsEntry() {
        let trimmedText = journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Create and save entry
        let entry = Entry(
            type: .text,
            content: trimmedText,
            tags: []
        )
        
        EntryManager.shared.addEntry(entry)
        HapticManager.shared.playSuccessNotification()
        
        // Clear text and close focus mode
        journalText = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isInFocusMode = false
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Recording Indicator Pill (replaces headline during recording)
struct RecordingIndicatorPill: View {
    let duration: TimeInterval
    @State private var waveformPhase: CGFloat = 0
    @State private var dotOpacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 14) {
            // Red recording dot (pulsing)
            Circle()
                .fill(LinearColors.Minimal.recordingActive)
                .frame(width: 10, height: 10)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        dotOpacity = 0.3
                    }
                }
            
            // Duration counter
            Text(formatDuration(duration))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            Spacer()
            
            // Pulsing waveform on right
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearColors.Minimal.accent)
                        .frame(width: 3, height: waveformHeight(for: index))
                        .animation(
                            .easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                            value: waveformPhase
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearColors.Minimal.recordingPulse, lineWidth: 1)
                )
        )
        .onAppear {
            waveformPhase = 1
        }
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [8, 14, 20, 14, 8]
        let animatedHeights: [CGFloat] = [14, 20, 10, 20, 14]
        return waveformPhase == 0 ? heights[index] : animatedHeights[index]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Hold Recording Waveform Pill (follows finger)
struct HoldRecordingWaveformPill: View {
    @State private var waveformPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: 3, height: waveformHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.08),
                        value: waveformPhase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            waveformPhase = 1
        }
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [10, 16, 22, 16, 10]
        let animatedHeights: [CGFloat] = [16, 22, 12, 22, 16]
        return waveformPhase == 0 ? heights[index] : animatedHeights[index]
    }
}

#Preview {
    DarkAppContainer(shouldStartVoiceRecording: .constant(false))
}

