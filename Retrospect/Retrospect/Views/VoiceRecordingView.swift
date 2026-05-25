import SwiftUI

struct VoiceRecordingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var showCancelAlert = false
    @State private var isSaving = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    LinearColors.backgroundGrey,
                    LinearColors.backgroundGrey.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                Spacer()
                
                // Main Content
                VStack(spacing: 32) {
                    // Waveform/Recording Indicator
                    recordingIndicator
                    
                    // Timer
                    timerDisplay
                    
                    // Transcription Display
                    transcriptionDisplay
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Stop Button
                stopButton
                    .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StopVoiceRecordingFromLiveActivity"))) { _ in
            stopRecordingAndSave()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            if let error = audioManager.errorMessage {
                Text(error)
            }
        }
        .alert("Cancel Recording?", isPresented: $showCancelAlert) {
            Button("Continue Recording", role: .cancel) {}
            Button("Discard", role: .destructive) {
                audioManager.cancelRecording()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your recording will be lost if you cancel.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Cancel Button
            Button(action: {
                HapticManager.shared.playLightImpact()
                showCancelAlert = true
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LinearColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(LinearColors.cardBackground)
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8, x: 0, y: 2
                            )
                    )
            }
            
            Spacer()
            
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearColors.Minimal.recordingActive)
                    .frame(width: 8, height: 8)
                    .opacity(audioManager.isRecording ? 1 : 0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: audioManager.isRecording)
                
                Text("Recording")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LinearColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 8, x: 0, y: 2
                    )
            )
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        ZStack {
            // Pulsing circles
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(LinearColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                    .scaleEffect(audioManager.isRecording ? 1.2 : 1.0)
                    .opacity(audioManager.isRecording ? 0.0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: audioManager.isRecording
                    )
            }
            
            // Center microphone icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LinearColors.accent, LinearColors.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: LinearColors.accent.opacity(0.3),
                        radius: 20, x: 0, y: 10
                    )
                
                Image(systemName: "waveform")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .symbolEffect(.variableColor.iterative, isActive: audioManager.isRecording)
            }
        }
        .padding(.top, 40)
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        Text(formatDuration(audioManager.recordingDuration))
            .font(.system(size: 48, weight: .bold))
            .foregroundColor(LinearColors.textPrimary)
            .monospacedDigit()
    }
    
    // MARK: - Transcription Display
    
    private var transcriptionDisplay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                    
                    Text("Live Transcription")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LinearColors.textSecondary)
                }
                
                if audioManager.currentTranscription.isEmpty {
                    Text("Start speaking...")
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textTertiary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    Text(audioManager.currentTranscription)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .frame(maxHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(
                    color: Shadows.cardShadow.color,
                    radius: Shadows.cardShadow.radius,
                    x: Shadows.cardShadow.x,
                    y: Shadows.cardShadow.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Stop Button
    
    private var stopButton: some View {
        Button(action: {
            HapticManager.shared.playHeavyImpact()
            stopRecordingAndSave()
        }) {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24, weight: .bold))
                }
                
                Text(isSaving ? "Saving..." : "Stop Recording")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [LinearColors.Minimal.recordingActive, LinearColors.Minimal.recordingActive.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: LinearColors.Minimal.recordingPulse,
                        radius: 15, x: 0, y: 8
                    )
            )
        }
        .disabled(isSaving)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Private Methods
    
    private func startRecording() {
        audioManager.requestPermissions { granted in
            if granted {
                audioManager.startRecording()
            } else {
                showError = true
            }
        }
    }
    
    private func stopRecordingAndSave() {
        guard !isSaving else { return }
        isSaving = true
        
        audioManager.stopRecording { result in
            Task { @MainActor in
                switch result {
                case .success(let (audioURL, transcription)):
                    let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                    let audioFileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
                    let hasUsableAudio = FileManager.default.fileExists(atPath: audioURL.path) && audioFileSize > 1000
                    
                    guard !trimmed.isEmpty || hasUsableAudio else {
                        audioManager.errorMessage = "Recording was empty — nothing to save."
                        showError = true
                        isSaving = false
                        return
                    }
                    
                    await saveVoiceEntry(audioURL: audioURL, transcription: trimmed)
                    
                case .failure(let error):
                    print("❌ Recording failed: \(error.localizedDescription)")
                    audioManager.errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
    
    private func saveVoiceEntry(audioURL: URL, transcription: String) async {
        let entryId = UUID()
        let entryDate = Date()
        
        // Move audio file to permanent location
        let finalAudioURL: URL
        do {
            finalAudioURL = try FileStorageManager.shared.moveAudio(from: audioURL, to: entryId)
        } catch {
            print("❌ Failed to move audio file: \(error)")
            audioManager.errorMessage = "Failed to save audio file"
            showError = true
            isSaving = false
            return
        }
        
        // Generate title and tags from transcription
        AIServiceManager.shared.analyzeEntryForMetadata(content: transcription) { result in
            Task { @MainActor in
                switch result {
                case .success(let metadata):
                    let voiceEntry = Entry(
                        id: entryId,
                        date: entryDate,
                        type: .voice,
                        content: transcription,
                        videoURL: nil,
                        audioURL: finalAudioURL,
                        aiGeneratedTitle: metadata.title,
                        tags: metadata.tags,
                        isIncludedInInsights: true
                    )

                    EntryManager.shared.addEntry(voiceEntry)
                    print("✅ Saved voice entry: \(metadata.title ?? "Untitled")")

                    // Upload to backend so the agent builds memory from voice sessions
                    if !transcription.isEmpty {
                        Task {
                            do {
                                try await RetrospectAPIClient.shared.uploadContent(
                                    contentType: "voice_journal",
                                    content: transcription,
                                    contentDate: entryDate,
                                    metadata: ["source": "ios_voice_recording"]
                                )
                            } catch {
                                print("⚠️ Voice entry upload failed: \(error)")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("⚠️ Failed to generate metadata: \(error), using fallback")
                    let voiceEntry = Entry(
                        id: entryId,
                        date: entryDate,
                        type: .voice,
                        content: transcription,
                        videoURL: nil,
                        audioURL: finalAudioURL,
                        aiGeneratedTitle: nil,
                        tags: [],
                        isIncludedInInsights: true
                    )
                    
                    EntryManager.shared.addEntry(voiceEntry)
                    print("✅ Saved voice entry (no metadata)")
                }
                
                isSaving = false
                HapticManager.shared.playSuccessNotification()
                
                // Dismiss with a slight delay for better UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    VoiceRecordingView()
}

