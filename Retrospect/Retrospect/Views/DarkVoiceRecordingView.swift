//
//  DarkVoiceRecordingView.swift
//  Retrospect
//
//  Voice recording view in dark UI
//  Dark pulsing animation, timer display, live transcription
//

import SwiftUI

struct DarkVoiceRecordingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var showCancelAlert = false
    @State private var isSaving = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Dark background
            LinearColors.Minimal.background
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
        .preferredColorScheme(.dark)
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
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                Circle()
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        Capsule()
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
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
                    .stroke(LinearColors.Minimal.recordingActive.opacity(0.3), lineWidth: 2)
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
            
            // Center circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            LinearColors.Minimal.recordingActive.opacity(0.3),
                            LinearColors.Minimal.recordingActive.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
            
            // Waveform icon
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(LinearColors.Minimal.recordingActive)
                .scaleEffect(audioManager.isRecording ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true),
                    value: audioManager.isRecording
                )
        }
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        Text(formatTime(audioManager.recordingDuration))
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundColor(LinearColors.Minimal.textPrimary)
    }
    
    // MARK: - Transcription Display
    
    private var transcriptionDisplay: some View {
        VStack(spacing: 12) {
            Text("Live Transcription")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
            
            ScrollView {
                Text(audioManager.currentTranscription.isEmpty ? "Listening..." : audioManager.currentTranscription)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(audioManager.currentTranscription.isEmpty ? LinearColors.Minimal.placeholderText : LinearColors.Minimal.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: 150)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Stop Button
    
    private var stopButton: some View {
        Button(action: {
            HapticManager.shared.playSuccessNotification()
            stopRecordingAndSave()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(LinearColors.Minimal.recordingActive.opacity(0.3), lineWidth: 4)
                    .frame(width: 88, height: 88)
                
                // Inner circle
                Circle()
                    .fill(LinearColors.Minimal.recordingActive)
                    .frame(width: 72, height: 72)
                
                // Stop icon (rounded square)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isSaving)
        .opacity(isSaving ? 0.5 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func startRecording() {
        audioManager.startRecording()
    }
    
    private func stopRecordingAndSave() {
        isSaving = true
        audioManager.stopRecording { result in
            DispatchQueue.main.async {
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
                    
                    let entry = Entry(
                        type: .voice,
                        content: trimmed,
                        audioURL: audioURL
                    )
                    Task { @MainActor in
                        EntryManager.shared.addEntry(entry)
                    }
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    audioManager.errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    DarkVoiceRecordingView()
}

