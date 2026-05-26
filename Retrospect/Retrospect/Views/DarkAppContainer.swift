//
//  DarkAppContainer.swift
//  Retrospect
//
//  Main app container for the dark minimal UI
//  Hosts side-panel navigation, global audio state, mini player, and voice recording
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
    @State private var isSidePanelOpen = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastSettleProgress: CGFloat = 0
    @State private var activeEntry: Entry? = nil
    @Binding var shouldStartVoiceRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sidePanelWidth: CGFloat = min(UIScreen.main.bounds.width * 0.69, 276)
    private let edgeGrabWidth: CGFloat = 36
    private let flickVelocity: CGFloat = 420
    private let drawerBackgroundColor = Color(red: 228 / 255, green: 228 / 255, blue: 226 / 255)
    private let cardSurfaceColor = Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255)

    private var drawerSettleAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.08)
    }

    private var sidePanelTabBinding: Binding<MinimalTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                activeEntry = nil
                selectedTab = newTab
            }
        )
    }

    /// The card's current x offset, including any in-flight drag (with rubber-banding).
    private var currentOffset: CGFloat {
        let base = isSidePanelOpen ? sidePanelWidth : 0
        let raw = base + dragOffset
        if raw < 0 {
            return raw * 0.25
        } else if raw > sidePanelWidth {
            let extra = raw - sidePanelWidth
            return sidePanelWidth + extra * 0.25
        }
        return raw
    }

    /// 0...1 — drives every continuous visual change.
    private var progress: CGFloat {
        min(max(currentOffset / sidePanelWidth, 0), 1)
    }

    private func resolvedSafeAreaInsets(from geometry: GeometryProxy) -> EdgeInsets {
        let windowInsets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero

        return EdgeInsets(
            top: max(geometry.safeAreaInsets.top, windowInsets.top),
            leading: max(geometry.safeAreaInsets.leading, windowInsets.left),
            bottom: max(geometry.safeAreaInsets.bottom, windowInsets.bottom),
            trailing: max(geometry.safeAreaInsets.trailing, windowInsets.right)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                drawerBackgroundColor
                    .ignoresSafeArea()

                SideOverPanel(
                    isOpen: $isSidePanelOpen,
                    selectedTab: sidePanelTabBinding,
                    hasNewPodcast: hasNewPodcast,
                    progress: progress,
                    safeAreaTop: resolvedSafeAreaInsets(from: geometry).top,
                    safeAreaBottom: resolvedSafeAreaInsets(from: geometry).bottom,
                    onSelectEntry: { entry in
                        selectedTab = .entries
                        activeEntry = entry
                    }
                )
                .frame(width: sidePanelWidth, height: geometry.size.height, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .allowsHitTesting(progress > 0.5)
                .zIndex(0)

                ZStack {
                    cardSurfaceColor

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
                                DarkEntriesView(activeEntry: $activeEntry)
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
                                .padding(.bottom, 10)
                        }
                    }
                    .padding(.bottom, selectedTab == .journal ? 0 : resolvedSafeAreaInsets(from: geometry).bottom)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .environment(\.dynamicSafeAreaTop, resolvedSafeAreaInsets(from: geometry).top)
                    .environment(\.dynamicSafeAreaBottom, resolvedSafeAreaInsets(from: geometry).bottom)
                    .environment(\.sidePanelProgress, progress)
                    .environment(\.openSidePanel, { openSidePanel() })
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 60 * progress, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 60 * progress, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.92 * progress),
                            lineWidth: progress > 0 ? 1 : 0
                        )
                        .allowsHitTesting(false)
                }
                .offset(x: currentOffset)
                .shadow(
                    color: Color.black.opacity(0.25 * progress),
                    radius: 4,
                    x: 0,
                    y: 2
                )
                .shadow(
                    color: Color.black.opacity(0.10 * progress),
                    radius: 15.4,
                    x: 0,
                    y: 4
                )
                .gesture(panelDragGesture(geometry: geometry))
                .allowsHitTesting(progress < 0.5 || isDragging)
                .zIndex(1)

                if progress > 0.5 {
                    cardInteractionLayer(width: geometry.size.width, height: geometry.size.height)
                        .zIndex(2)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.container, edges: .all)
        .preferredColorScheme(.light)
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textPrimary)

                        if let error = audioManager.lastError {
                            Text(error)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Button(action: {
                            audioManager.showFullPlayer = false
                        }) {
                            Text("Dismiss")
                                .font(.system(size: 16, weight: .semibold))
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

    // MARK: - Side panel control

    private func cardInteractionLayer(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: max(currentOffset, 0))
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    closeSidePanel()
                }
                .gesture(panelDragGesture(width: width))
        }
        .frame(width: width, height: height, alignment: .leading)
    }

    private func openSidePanel() {
        withAnimation(drawerSettleAnimation) {
            isSidePanelOpen = true
            dragOffset = 0
        }
        playSettleHapticIfNeeded(target: 1)
    }

    private func closeSidePanel() {
        withAnimation(drawerSettleAnimation) {
            isSidePanelOpen = false
            dragOffset = 0
        }
        playSettleHapticIfNeeded(target: 0)
    }

    private func playSettleHapticIfNeeded(target: CGFloat) {
        // Soft impact when the spring settles past 95% in either direction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            HapticManager.shared.playSoftImpact()
            lastSettleProgress = target
        }
    }

    // MARK: - Live drag gesture

    private func panelDragGesture(geometry: GeometryProxy) -> some Gesture {
        panelDragGesture(width: geometry.size.width)
    }

    private func panelDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let h = value.translation.width
                let v = value.translation.height

                // Only honor horizontal-leaning drags
                guard abs(h) > abs(v) * 1.45 else {
                    return
                }

                if !isSidePanelOpen {
                    guard h > 0 else { return }
                } else {
                    // When open, allow both directions but treat right-drag as overshoot
                }

                if !isDragging {
                    isDragging = true
                }
                dragOffset = h
            }
            .onEnded { value in
                let h = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let velocity = predicted - h // rough velocity proxy in pt

                // Decide target state from position + velocity
                let base = isSidePanelOpen ? sidePanelWidth : 0
                let endPosition = base + predicted
                var shouldOpen: Bool

                if abs(velocity) > flickVelocity {
                    shouldOpen = velocity > 0
                } else {
                    shouldOpen = endPosition > sidePanelWidth * 0.38
                }

                isDragging = false
                withAnimation(drawerSettleAnimation) {
                    isSidePanelOpen = shouldOpen
                    dragOffset = 0
                }
                playSettleHapticIfNeeded(target: shouldOpen ? 1 : 0)
            }
    }
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
    @StateObject private var inlineVoiceRecorder = AudioRecordingManager()

    @State private var journalText = ""
    @State private var attachedImages: [UIImage] = []
    @State private var isInFocusMode = false
    @State private var showImagePicker = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var isTestingAgentPodcast = false
    @State private var agentPodcastTestStatus: String?
    @State private var agentPodcastTestError: String?
    @State private var inlineVoiceBaseText = ""
    @State private var inlineVoiceError: String?
    @AppStorage("devMode") private var devMode: Bool = false
    @FocusState private var isJournalFocused: Bool
    @Environment(\.dynamicSafeAreaTop) private var dynamicSafeAreaTop
    @Environment(\.dynamicSafeAreaBottom) private var dynamicSafeAreaBottom
    @Environment(\.openSidePanel) private var openSidePanel

    // Session-based animation flag (plays once per app session, resets on app launch)
    @ObservedObject private var animationTracker = HeadlineAnimationTracker.shared

    // Typewriter animation states
    @State private var displayedText: String = ""
    @State private var headlineOpacity: Double = 0
    private let fullHeadlineText = "How do you\nwant to rewire\nthe mind\ntoday?"

    // Animation states for other elements
    @State private var inputOpacity: Double = 0
    @State private var inputOffset: CGFloat = 20

    private let homeBackdropColor = Color(red: 0.894, green: 0.894, blue: 0.886) // #E4E4E2
    private let homeSurfaceColor = Color(red: 0.957, green: 0.949, blue: 0.933) // #F4F2EE
    private let homeControlColor = Color(red: 0.969, green: 0.953, blue: 0.933) // #F7F3EE
    private let homeMutedText = Color(red: 0.620, green: 0.620, blue: 0.620) // #9E9E9E
    private let homePromptText = Color(red: 0.765, green: 0.761, blue: 0.745) // #C3C2BE

    var body: some View {
        journalContent
    }

    private var journalContent: some View {
        GeometryReader { geometry in
            ZStack {
                homeBackdropColor
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .fill(homeSurfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 60, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.10), radius: 15, x: 0, y: 4)
                    .ignoresSafeArea()

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
                    .onAppear {
                        scheduleScreenTimeRefreshes()
                    }
                }

                VStack(spacing: 0) {
                    homeTopBar
                        .padding(.top, dynamicSafeAreaTop + 8)
                        .padding(.horizontal, 34)

                    Spacer()
                }

                journalEditor
                    .frame(width: min(geometry.size.width - 48, 340), height: isJournalFocused ? 220 : 170)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * (isJournalFocused ? 0.34 : 0.50))
                    .opacity(inputOpacity)
                    .offset(y: inputOffset)

                VStack(spacing: 12) {
                    if let transcript = viewModel.transcript, transcript.audioFileURL != nil, !isJournalFocused {
                        latestPodcastButton(transcript: transcript)
                    }

                    if viewModel.isProcessing {
                        processingPill
                    } else if !isJournalFocused {
                        if devMode {
                            devGenerateButton
                                .offset(y: 18)
                        } else {
                            nextEpisodePill
                                .offset(y: 18)
                        }
                    }

                    typingAccessoryBar
                }
                .padding(.horizontal, 34)
                .padding(.bottom, bottomAccessoryPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .opacity(inputOpacity)
                .offset(y: inputOffset)
            }
        }
        .onAppear {
            animateIn()
            setupKeyboardObservers()
        }
        .onDisappear {
            if inlineVoiceRecorder.isRecording {
                inlineVoiceRecorder.cancelRecording()
            }
            removeKeyboardObservers()
        }
        .onChange(of: inlineVoiceRecorder.currentTranscription) { _, transcription in
            applyInlineTranscription(transcription)
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
        .alert("Agent Podcast Test Failed", isPresented: Binding(
            get: { agentPodcastTestError != nil },
            set: { if !$0 { agentPodcastTestError = nil } }
        )) {
            Button("OK", role: .cancel) {
                agentPodcastTestError = nil
            }
        } message: {
            Text(agentPodcastTestError ?? "Something went wrong.")
        }
        .alert("Voice Recording Failed", isPresented: Binding(
            get: { inlineVoiceError != nil },
            set: { if !$0 { inlineVoiceError = nil } }
        )) {
            Button("OK", role: .cancel) {
                inlineVoiceError = nil
            }
        } message: {
            Text(inlineVoiceError ?? "Something went wrong.")
        }
    }

    private var homeTopBar: some View {
        ZStack {
            HStack {
                homeIconButton(systemName: "line.3.horizontal") {
                    isJournalFocused = false
                    openSidePanel()
                }

                Spacer()

                HStack(spacing: 8) {
                    if devMode {
                        agentPodcastTestButton
                    }

                    inlineMicButton
                }
            }

            Text("Journal")
                .font(.system(size: 18, weight: .regular, design: .monospaced))
                .foregroundColor(homeMutedText)
        }
    }

    private var journalEditor: some View {
        ZStack(alignment: .center) {
            if journalText.isEmpty {
                Text("tell me something.....")
                    .font(.minimalHeadline)
                    .foregroundColor(homePromptText)
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            TextEditor(text: $journalText)
                .scrollContentBackground(.hidden)
                .font(.minimalHeadline)
                .foregroundColor(journalText.isEmpty ? homePromptText : FigmaLightTheme.primaryText)
                .multilineTextAlignment(.center)
                .tint(FigmaLightTheme.primaryText)
                .focused($isJournalFocused)
                .padding(.horizontal, 8)
                .opacity(journalText.isEmpty ? 0.02 : 1)
                .background(Color.clear)
                .onTapGesture {
                    isJournalFocused = true
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isJournalFocused = true
        }
    }

    private var typingAccessoryBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                HapticManager.shared.playLightImpact()
                showImagePicker = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(homeMutedText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(homeControlColor))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())

            if !attachedImages.isEmpty {
                attachedImagesChip
            }

            Spacer(minLength: 12)

            if !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: sendJournalEntry) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(homeMutedText)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(homeControlColor))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(isJournalFocused || !attachedImages.isEmpty || !journalText.isEmpty ? 1 : 0)
        .allowsHitTesting(isJournalFocused || !attachedImages.isEmpty || !journalText.isEmpty)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: journalText.isEmpty)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: attachedImages.count)
    }

    private var inlineMicButton: some View {
        Button(action: toggleInlineVoiceRecording) {
            ZStack {
                if inlineVoiceRecorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .scaleEffect(1.15)
                }

                Image(systemName: inlineVoiceRecorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: inlineVoiceRecorder.isRecording ? 18 : 25, weight: .semibold))
                    .foregroundColor(inlineVoiceRecorder.isRecording ? Color.red.opacity(0.65) : homePromptText)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(inlineVoiceRecorder.isRecording ? "Stop voice typing" : "Start voice typing")
    }

    private var attachedImagesChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.fill")
                .font(.system(size: 12, weight: .medium))

            Text("\(attachedImages.count)")
                .font(.system(size: 13, weight: .semibold, design: .default))

            Button(action: {
                HapticManager.shared.playLightImpact()
                attachedImages.removeAll()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .foregroundColor(homeMutedText)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Capsule(style: .continuous).fill(homeControlColor))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
    }

    private var nextEpisodePill: some View {
        Text(statusPillText)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundColor(homeMutedText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(Capsule(style: .continuous).fill(Color(red: 0.918, green: 0.906, blue: 0.890)))
    }

    private var devGenerateButton: some View {
        Button(action: testAgentPodcastFlow) {
            HStack(spacing: 8) {
                if isTestingAgentPodcast {
                    ProgressView()
                        .controlSize(.small)
                        .tint(homeMutedText)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(isTestingAgentPodcast ? "Generating Podcast" : "Generate Podcast")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundColor(homeMutedText)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Capsule(style: .continuous).fill(homeControlColor))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isTestingAgentPodcast)
        .opacity(isTestingAgentPodcast ? 0.72 : 1)
    }

    private var processingPill: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(homeMutedText)

            Text("Creating your episode")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(homeMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Capsule(style: .continuous).fill(Color(red: 0.918, green: 0.906, blue: 0.890)))
    }

    private func latestPodcastButton(transcript: TranscriptModel) -> some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            audioManager.showTranscript(transcript: transcript)
        }) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))

                Text(transcript.mood.map { "\($0) episode" } ?? "Latest episode")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .lineLimit(1)

                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(homeMutedText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(homeControlColor))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func homeIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: systemName == "mic.fill" ? 24 : 15, weight: .semibold))
                .foregroundColor(homePromptText)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(homeControlColor)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusPillText: String {
        if inlineVoiceRecorder.isRecording {
            return inlineVoiceRecorder.currentTranscription.isEmpty
                ? "Listening..."
                : "Voice typing..."
        }
        if let status = agentPodcastTestStatus, !status.isEmpty {
            return status
        }
        if let nugget = screenTimeNugget {
            return nugget
        }
        return "Your next episode is in 3 days"
    }

    private var bottomAccessoryPadding: CGFloat {
        if keyboardHeight > 0 {
            return keyboardHeight + 14
        }
        return dynamicSafeAreaBottom + 52
    }

    private var agentPodcastTestButton: some View {
        Button(action: testAgentPodcastFlow) {
            HStack(spacing: 7) {
                if isTestingAgentPodcast {
                    ProgressView()
                        .controlSize(.small)
                        .tint(LinearColors.Minimal.buttonPrimaryText)
                } else {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(isTestingAgentPodcast ? "Generating" : "Generate")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearColors.Minimal.accent)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isTestingAgentPodcast)
        .opacity(isTestingAgentPodcast ? 0.72 : 1)
    }

    private func toggleInlineVoiceRecording() {
        if inlineVoiceRecorder.isRecording {
            stopInlineVoiceRecording()
        } else {
            startInlineVoiceRecording()
        }
    }

    private func startInlineVoiceRecording() {
        HapticManager.shared.playMediumImpact()
        inlineVoiceBaseText = journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        isJournalFocused = true

        inlineVoiceRecorder.requestPermissions { granted in
            guard granted else {
                inlineVoiceError = inlineVoiceRecorder.errorMessage ?? "Microphone and speech recognition access are required."
                HapticManager.shared.playErrorNotification()
                return
            }
            inlineVoiceRecorder.startRecording()
        }
    }

    private func stopInlineVoiceRecording() {
        HapticManager.shared.playLightImpact()
        inlineVoiceRecorder.stopRecording { result in
            switch result {
            case .success:
                HapticManager.shared.playSuccessNotification()
            case .failure(let error):
                inlineVoiceError = error.localizedDescription
                HapticManager.shared.playErrorNotification()
            }
        }
    }

    private func applyInlineTranscription(_ transcription: String) {
        let cleanedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard inlineVoiceRecorder.isRecording else { return }

        if inlineVoiceBaseText.isEmpty {
            journalText = cleanedTranscription
        } else if cleanedTranscription.isEmpty {
            journalText = inlineVoiceBaseText
        } else {
            journalText = "\(inlineVoiceBaseText)\n\(cleanedTranscription)"
        }
    }

    // MARK: - Animation Functions

    private func animateIn() {
        displayedText = fullHeadlineText
        headlineOpacity = 1

        withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(0.08)) {
            inputOpacity = 1
            inputOffset = 0
        }

        animationTracker.hasPlayedThisSession = true
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

    /// The Screen Time extension writes data to the App Group asynchronously after the
    /// hidden DeviceActivityReport renders. These staggered refreshes give the extension
    /// time to finish before the main app re-reads.
    private func scheduleScreenTimeRefreshes() {
        for delay in [2.0, 5.0, 10.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                screenTimeService.refreshData()
            }
        }
    }

    private func saveReflectionAsEntry() {
        sendJournalEntry()
    }

    private func sendJournalEntry() {
        let trimmedText = journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let entryId = UUID()
        let imageURLs = attachedImages.isEmpty
            ? nil
            : FileStorageManager.shared.saveImages(for: entryId, images: attachedImages)

        let entry = Entry(
            id: entryId,
            type: .text,
            content: trimmedText,
            imageURLs: imageURLs,
            tags: []
        )

        EntryManager.shared.addEntry(entry)
        HapticManager.shared.playSuccessNotification()

        journalText = ""
        attachedImages.removeAll()
        isJournalFocused = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isInFocusMode = false
        }
    }

    private func testAgentPodcastFlow() {
        guard RetrospectAPIClient.shared.isAuthenticated else {
            agentPodcastTestError = "Sign in first so the backend knows which user's data the agent should use."
            return
        }

        HapticManager.shared.playMediumImpact()
        isTestingAgentPodcast = true
        agentPodcastTestStatus = "Asking the backend to create a podcast with the agent..."

        Task {
            do {
                let episode = try await RetrospectAPIClient.shared.generatePodcast(daysSince: 14)
                let transcript = episode.toTranscriptModel()

                await MainActor.run {
                    viewModel.savePodcast(transcript)
                    viewModel.transcript = transcript
                    audioManager.showTranscript(transcript: transcript)
                    agentPodcastTestStatus = "Created \"\(episode.title)\" through the agent."
                    isTestingAgentPodcast = false
                    HapticManager.shared.playSuccessNotification()
                }
            } catch {
                await MainActor.run {
                    agentPodcastTestError = error.localizedDescription
                    agentPodcastTestStatus = "Agent podcast test failed."
                    isTestingAgentPodcast = false
                    HapticManager.shared.playErrorNotification()
                }
            }
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

#Preview {
    DarkAppContainer(shouldStartVoiceRecording: .constant(false))
}
