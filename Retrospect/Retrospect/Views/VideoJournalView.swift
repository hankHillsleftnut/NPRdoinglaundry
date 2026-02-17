import SwiftUI
import AVFoundation
import Speech

struct VideoJournalView: View {
    @StateObject private var viewModel = VideoJournalViewModel()
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var journalManager = VideoJournalManager.shared
    @AppStorage("devMode") private var devMode: Bool = false
    
    // Local UI State
    @State private var isRecordButtonPressed = false
    @State private var showingCountdown = false
    @State private var countdownValue = 3
    @State private var showingFinishAlert = false
    @State private var showingTips = false
    @State private var cameraScale: CGFloat = 1.0
    @State private var showingFlashAnimation = false
    @State private var showingCameraError = false
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var showingRecordingDoneChip = false
    
    private let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let cardWidth = geometry.size.width - (Layout.cardHorizontalPadding * 2) - (Layout.cardPeekAmount * 2)
                let cardHeight = cardWidth / Layout.cardAspectRatio // Match weekly reflections exactly
                
                HStack {
                    Spacer(minLength: Layout.cardPeekAmount)
                    VStack(spacing: 0) {
                        // Unified Video Journal Card
                        unifiedVideoCard(cardWidth: cardWidth, cardHeight: cardHeight)
                            .padding(.top, 20)
                        
                        Spacer()
                    }
                    Spacer(minLength: Layout.cardPeekAmount)
                }
                .padding(.bottom, 240) // 100px above generate button
                .overlay(countdownOverlay)
            }
            
            // Recording Done Notification - subtle popup style
            if showingRecordingDoneChip {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.serifBody)
                            .foregroundColor(.green)
                        
                        Text("Recording saved")
                            .font(.serifLabel)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.top, 60) // Position below status bar
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingRecordingDoneChip)
            }
        }
        .task {
            await checkPermissions()
        }
        .onChange(of: showingRecordingDoneChip) { _, newValue in
            // Recording chip state changed
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if let error = error {
                showError(error)
            }
        }
        .onDisappear {
            cleanUp()
        }
        .alert("Permission Required", isPresented: $viewModel.showErrorAlert) {
            Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("End Recording?", isPresented: $showingFinishAlert) {
            Button("Stop & Save", role: .destructive) {
                    Task {
                    await stopRecording()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to stop recording and save your video journal?")
        }
        .sheet(isPresented: $showingTips) {
            TipsView()
        }
        .onAppear {
            // Removed test code - notification is working
        }
        .overlay(
            // Debug overlay - only shown in dev mode
            Group {
                if devMode {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Debug Info:")
                                    .font(.serifCaption)
                                    .fontWeight(.bold)
                                Text("Session: \(cameraViewModel.captureSession != nil ? "✅" : "❌")")
                                    .font(.serifCaption)
                                Text("Ready: \(cameraViewModel.isSessionReady ? "✅" : "❌")")
                                    .font(.serifCaption)
                                Text("Init: \(cameraViewModel.isInitialized ? "✅" : "❌")")
                                    .font(.serifCaption)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .cornerRadius(8)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        )
    }
    
    // MARK: - UI Components

    
    // MARK: - Unified Video Card
    
    private func unifiedVideoCard(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let videoPreviewSize = cardWidth - (Spacing.listItemSpacing * 2) // Account for consistent thin padding
        let transcriptionHeight: CGFloat = 60 // Fixed height for 2-3 lines
        
        return VStack(spacing: Spacing.listItemSpacing) {
            // Video Preview with Overlay Controls
            ZStack {
                // Camera Preview
                if let session = cameraViewModel.captureSession {
                    CameraPreviewViewRepresentable(session: session)
                        .frame(width: videoPreviewSize, height: videoPreviewSize)
                        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.small)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: BorderRadius.small)
                        .fill(LinearColors.inputBackground)
                        .frame(width: videoPreviewSize, height: videoPreviewSize)
                        .overlay(
                            VStack(spacing: Spacing.listItemSpacing) {
                                if !cameraViewModel.isInitialized {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .tint(LinearColors.accent)
                                    Text("Initializing Camera...")
                                        .font(.serifCaption)
                                        .foregroundColor(LinearColors.textSecondary)
                                } else {
                                    Image(systemName: "video.slash.fill")
                                        .font(.geistHeadline)
                                        .foregroundColor(LinearColors.textSecondary)
                                    Text("Camera Not Available")
                                        .font(.serifCaption)
                                        .foregroundColor(LinearColors.textSecondary)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.small)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Overlay Controls
                VStack {
                    HStack {
                        // Recording Timer (Top-left)
                        if viewModel.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearColors.accent)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.8)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: true)
                                Text(timeString(from: recordingDuration))
                                    .font(.serifCaption).fontWeight(.semibold)
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.6))
                            )
                        }
                        
                        Spacer()
                        
                        // Video Log Button (Top-right)
                        NavigationLink {
                            VideoJournalListView()
                        } label: {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                )
                                .shadow(
                                    color: Shadows.buttonShadow.color,
                                    radius: Shadows.buttonShadow.radius * 0.7,
                                    x: Shadows.buttonShadow.x,
                                    y: Shadows.buttonShadow.y * 0.7
                                )
                        }
                    }
                    .padding(Spacing.listItemSpacing)
                    
                    Spacer()
                    
                    // Record Button (Bottom-center)
                    Button(action: handleRecordButton) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? LinearColors.warningRed : LinearColors.accent)
                                .frame(width: 60, height: 60)
                                .shadow(
                                    color: Shadows.buttonShadow.color,
                                    radius: Shadows.buttonShadow.radius,
                                    x: Shadows.buttonShadow.x,
                                    y: Shadows.buttonShadow.y
                                )
                            
                            if viewModel.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                            } else {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .scaleEffect(isRecordButtonPressed ? 0.9 : 1.0)
                    .onLongPressGesture(minimumDuration: 0) {
                        // On press
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isRecordButtonPressed = true
                        }
                    } onPressingChanged: { pressing in
                        if !pressing {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isRecordButtonPressed = false
                            }
                        }
                    }
                    .padding(.bottom, Spacing.listItemSpacing)
                }
            }
            .frame(width: videoPreviewSize, height: videoPreviewSize)
            
            // Compact Transcription Area
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Live Transcription")
                        .font(.serifLabel).fontWeight(.semibold)
                        .foregroundColor(LinearColors.textPrimary)
                    Spacer()
                    if viewModel.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(LinearColors.accent)
                                .frame(width: 6, height: 6)
                                .opacity(0.8)
                                .animation(.easeInOut(duration: 0.6).repeatForever(), value: true)
                            Text("Listening...")
                                .font(.serifCaption)
                                .foregroundColor(LinearColors.textSecondary)
                        }
                    }
                }
                
                ScrollView {
                    Text(viewModel.transcribedText.isEmpty ? "Start recording to see live transcription..." : viewModel.transcribedText)
                        .font(.serifBody)
                        .foregroundColor(viewModel.transcribedText.isEmpty ? LinearColors.textPlaceholder : LinearColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                }
                .frame(height: transcriptionHeight)
            }
            .padding(Spacing.listItemSpacing)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.small)
                    .fill(LinearColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.small)
                            .stroke(LinearColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .padding(Spacing.listItemSpacing) // Same consistent thin padding as weekly reflections
        .coStarCard()
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private func cameraPreviewView(geometry: GeometryProxy) -> some View {
        ZStack {
            if let session = cameraViewModel.captureSession {
                CameraPreviewViewRepresentable(session: session)
                    .frame(width: geometry.size.width - 40, height: geometry.size.width - 40)
                    .clipShape(RoundedRectangle(cornerRadius: BorderRadius.card))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
                    .overlay(recordingIndicatorOverlay)
            } else {
                cameraPlaceholder(geometry: geometry)
            }
        }
    }
    
    private func cameraPlaceholder(geometry: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: BorderRadius.card)
            .fill(LinearColors.inputBackground)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
            .frame(width: geometry.size.width - 40, height: geometry.size.width - 40)
            .overlay(
                VStack(spacing: 16) {
                    if !cameraViewModel.isInitialized {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(LinearColors.accent)
                        Text("Initializing Camera...")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.primaryText)
                    } else {
                        Image(systemName: "video.slash.fill")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.secondaryText)
                        Text("Camera Not Available")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.primaryText)
                        Text("Check camera permissions in Settings.")
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            )
    }
    
    private var recordingIndicatorOverlay: some View {
        Group {
            if viewModel.isRecording {
                VStack {
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(LinearColors.accent)
                                .frame(width: 8, height: 8)
                                .opacity(0.5)
                                .animation(.easeInOut(duration: 0.6).repeatForever(), value: true)
                            Text(timeString(from: recordingDuration))
                                .font(.serifLabel).fontWeight(.semibold)
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                        .padding(16)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var countdownOverlay: some View {
        Group {
            if showingCountdown {
                ZStack {
                    Color.black.opacity(0.75)
                    VStack(spacing: 8) {
                        Text("\(countdownValue)")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning).fontWeight(.bold)
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .contentTransition(.numericText())
                        Text("Recording will start soon...")
                            .font(.serifBody)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
    }


    
    // MARK: - Helper Functions
    
    private func handleRecordButton() {
        if viewModel.isRecording {
            Task {
                await stopRecording()
            }
        } else {
            startRecordingWithCountdown()
        }
    }
    
    private func startRecordingWithCountdown() {
        showingCountdown = true
        countdownValue = 3
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation {
                if countdownValue > 0 {
                    countdownValue -= 1
                } else {
                    timer.invalidate()
                    showingCountdown = false
                    Task {
                        await startRecording()
                    }
                }
            }
        }
    }
    
    private func startRecording() async {
        do {
            try await viewModel.startRecording(cameraViewModel: cameraViewModel)
            startRecordingTimer()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func stopRecording() async {
        print("🛑 stopRecording() called")
        do {
            try await viewModel.stopRecording(cameraViewModel: cameraViewModel)
            stopRecordingTimer()
            
            print("📱 About to show recording done chip")
            // Show recording done chip
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingRecordingDoneChip = true
                    print("✅ Recording done chip state set to true")
                }
            }
        } catch {
            print("❌ Error in stopRecording: \(error)")
            showError(error.localizedDescription)
        }
    }
    
    private func checkPermissions() async {
        let cameraGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard cameraGranted else {
            showError("Camera permission is required.")
            return
        }
        
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard microphoneGranted else {
            showError("Microphone permission is required.")
            return
        }
        
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        if speechStatus == .authorized {
            print("🎤 Speech recognition authorized, starting camera...")
            do {
                // Initialize camera
                try await cameraViewModel.setupCamera()
                print("✅ Camera setup successful")
                // Initialize audio session for transcription
                try await viewModel.initializeCaptureSession()
                print("✅ Audio capture session initialized")
            } catch {
                print("❌ Error during setup: \(error.localizedDescription)")
                showError(error.localizedDescription)
            }
        } else {
            print("❌ Speech recognition not authorized: \(speechStatus)")
            showError("Speech recognition permission is required.")
        }
    }
    
    private func cleanUp() {
        stopRecordingTimer()
        Task {
            await viewModel.cleanUp()
        }
        cameraViewModel.stopCamera()
    }
    
    private func showError(_ message: String) {
        viewModel.errorMessage = message
        viewModel.showErrorAlert = true
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
            if recordingDuration >= maxRecordingDuration {
                Task {
                    await stopRecording()
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Helper Views

struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.5 : 1)
            .scaleEffect(isAnimating ? 1.2 : 1)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func pressAction(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressAction(onPress: onPress, onRelease: onRelease))
    }
}

struct PressAction: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension Calendar {
    func isDateInLastSevenDays(_ date: Date) -> Bool {
        guard let sevenDaysAgo = self.date(byAdding: .day, value: -7, to: Date()) else {
            return false
        }
        return date >= sevenDaysAgo && date <= Date()
    }
}

// Tips View
struct TipsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TipCard(
                        icon: "video.fill",
                        title: "Recording Tips",
                        tips: [
                            "Find a quiet, well-lit space",
                            "Position yourself at arm's length",
                            "Speak clearly and at a natural pace",
                            "Look directly at the camera"
                        ]
                    )
                    
                    TipCard(
                        icon: "waveform",
                        title: "Audio Tips",
                        tips: [
                            "Minimize background noise",
                            "Keep a consistent distance",
                            "Pause between thoughts",
                            "Project your voice naturally"
                        ]
                    )
                    
                    TipCard(
                        icon: "lightbulb.fill",
                        title: "Content Tips",
                        tips: [
                            "Share specific examples",
                            "Focus on key moments",
                            "Express your feelings",
                            "Be authentic"
                        ]
                    )
                }
                .padding()
            }
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [
                        LinearColors.backgroundLight,
                        LinearColors.background
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.width * 1.5
                )
                .edgesIgnoringSafeArea(.all)
            )
            .navigationTitle("Recording Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(LinearColors.accent)
                }
            }
        }
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                    .foregroundColor(LinearColors.accent)
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(LinearColors.primaryText)
            }
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LinearColors.accent)
                        .font(.system(size: 14))
                    Text(tip)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.primaryText)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .stroke(LinearColors.border, lineWidth: 1)
        )
    }
}

// Removed duplicate CameraPreviewView - using CameraPreviewViewRepresentable instead

#Preview {
    VideoJournalView()
}
