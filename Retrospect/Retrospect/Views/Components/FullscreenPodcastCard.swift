//
//  FullscreenPodcastCard.swift
//  Retrospect
//
//  Created by Assistant on 1/30/25.
//

import SwiftUI
import AVFoundation

struct FullscreenPodcastCard: View {
    let transcript: String
    let mood: String?
    let generationType: GenerationType?
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    let onDismiss: () -> Void
    
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isDragging = false
    @State private var draggedProgress: Double = 0
    @State private var showTranscript = false
    
    private var progress: Double {
        guard let duration = audioPlayer?.duration, duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private var podcastMood: PodcastMood {
        guard let moodString = mood else { return .neutral }
        return PodcastMood(rawValue: moodString.lowercased()) ?? .neutral
    }
    
    var body: some View {
        GeometryReader { geometry in
            mainPodcastCard(geometry: geometry)
                .padding(.top, 60)    // Space from top for status bar + breathing room
                .padding(.bottom, 120) // Space from bottom nav + safe area
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    // Dismiss on downward swipe
                    if gesture.translation.height > 100 {
                        HapticManager.shared.playMediumImpact()
                        onDismiss()
                    }
                }
        )
        .onAppear {
            setupTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptModalView(transcript: transcript)
        }
    }
    
    // MARK: - Sub Views
    

    
    private func mainPodcastCard(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            cardHeader
            cardContent(geometry: geometry)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .background(cardBackground)
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, 12)
    }
    
    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Insights")
                    .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                    .foregroundColor(LinearColors.textPrimary)
                
                Text("AI-Generated Summary")
                    .font(.geistCaption)
                    .foregroundColor(LinearColors.textSecondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                    .foregroundColor(LinearColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
    
    private func cardContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                artworkSection(geometry: geometry)
                    .padding(.bottom, Spacing.xl)
                
                // Progress and controls grouped together
                VStack(spacing: Spacing.lg) {
                    progressSection
                    controlsSection
                }
                .padding(.bottom, Spacing.xl)
                
                actionsSection
            }
            .padding(.vertical, Spacing.md)
        }
    }
    
    private func artworkSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BorderRadius.large)
                    .fill(artworkGradient)
                    .frame(width: min(geometry.size.width * 0.6, 200), height: min(geometry.size.width * 0.6, 200))
                    .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
                
                Image(systemName: "waveform")
                    .font(.geistHeadline)
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            moodAndTypeInfo
        }
        .padding(.top, Spacing.sm)
    }
    
    private var artworkGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: podcastMood.colors.prefix(3).map { $0 }),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var moodAndTypeInfo: some View {
        HStack(spacing: Spacing.md) {
            Text(podcastMood.displayName)
                .font(.geistBody)
                .fontWeight(.semibold)
                .foregroundColor(LinearColors.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.small)
                        .fill(LinearColors.accent.opacity(0.1))
                )
            
            Text(generationType?.displayName ?? "Standard")
                .font(.geistBody)
                .fontWeight(.medium)
                .foregroundColor(LinearColors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.small)
                        .fill(LinearColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.small)
                                .strokeBorder(LinearColors.cardBorder.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: Spacing.md) {
            timeDisplay
            progressBar
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
    
    private var timeDisplay: some View {
        HStack {
            Text(formatTime(currentTime))
                .font(.monospacedDigit(.geistCaption)())
                .fontWeight(.medium)
                .foregroundColor(LinearColors.textPrimary)
            
            Spacer()
            
            Text(formatTime(audioPlayer?.duration ?? 0))
                .font(.monospacedDigit(.geistCaption)())
                .fontWeight(.medium)
                .foregroundColor(LinearColors.textSecondary)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { progressGeometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearColors.accent.opacity(0.15))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearColors.accent)
                    .frame(width: progressGeometry.size.width * (isDragging ? draggedProgress : progress), height: 6)
                    .animation(.easeInOut(duration: 0.1), value: isDragging ? draggedProgress : progress)
                
                progressHandle(progressGeometry: progressGeometry)
            }
        }
        .frame(height: 30)
    }
    
    private func progressHandle(progressGeometry: GeometryProxy) -> some View {
        Circle()
            .fill(LinearColors.accent)
            .frame(width: 20, height: 20)
            .shadow(color: LinearColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
            .offset(x: max(0, min(progressGeometry.size.width - 20, progressGeometry.size.width * (isDragging ? draggedProgress : progress) - 10)))
            .scaleEffect(isDragging ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .gesture(progressDragGesture)
    }
    
    private var progressDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                let newProgress = max(0, min(1, gesture.location.x / UIScreen.main.bounds.width))
                draggedProgress = newProgress
                
                let progressPercent = Int(newProgress * 10)
                let oldProgressPercent = Int(progress * 10)
                if progressPercent != oldProgressPercent {
                    HapticManager.shared.playProgressMilestone()
                }
            }
            .onEnded { _ in
                isDragging = false
                seekToProgress(draggedProgress)
            }
    }
    
    private var controlsSection: some View {
        HStack(spacing: Spacing.lg) {
            Button(action: rewind15) {
                Image(systemName: "gobackward.15")
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
            
            playPauseButton
            
            Button(action: forward15) {
                Image(systemName: "goforward.15")
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
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
    
    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.geistHeadline)
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(LinearColors.accent)
                        .shadow(color: LinearColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                )
        }
        .scaleEffect(isPlaying ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
    }
    
    private var actionsSection: some View {
        VStack(spacing: Spacing.md) {
            transcriptButton
            generationInfo
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
    
    private var transcriptButton: some View {
        Button(action: { showTranscript.toggle() }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.geistBody)
                Text("Show Transcript")
                    .font(.geistBody)
                    .fontWeight(.semibold)
            }
            .foregroundColor(LinearColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(transcriptButtonBackground)
        }
    }
    
    private var transcriptButtonBackground: some View {
        RoundedRectangle(cornerRadius: BorderRadius.button)
            .stroke(LinearColors.accent.opacity(0.3), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.button)
                    .fill(LinearColors.accent.opacity(0.05))
            )
    }
    
    private var generationInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Generated")
                    .font(.geistCaption)
                    .foregroundColor(LinearColors.textSecondary)
                Text("just now")
                    .font(.geistCaption)
                    .fontWeight(.medium)
                    .foregroundColor(LinearColors.textPrimary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text("Duration")
                    .font(.geistCaption)
                    .foregroundColor(LinearColors.textSecondary)
                Text(formatDuration(audioPlayer?.duration ?? 0))
                    .font(.geistCaption)
                    .fontWeight(.medium)
                    .foregroundColor(LinearColors.textPrimary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.small)
                .fill(LinearColors.cardBackground.opacity(0.5))
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BorderRadius.large)
            .fill(LinearColors.cardBackground)
            .shadow(
                color: Shadows.cardShadow.color,
                radius: Shadows.cardShadow.radius,
                x: Shadows.cardShadow.x,
                y: Shadows.cardShadow.y
            )
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.large)
                    .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
            )
    }
    
    // MARK: - Helper Methods
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func togglePlayback() {
        if isPlaying {
            HapticManager.shared.playMediumImpact()
            audioPlayer?.pause()
        } else {
            HapticManager.shared.playAudioPlayback()
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
    
    private func rewind15() {
        HapticManager.shared.playLightImpact()
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, player.currentTime - 15)
        currentTime = player.currentTime
    }
    
    private func forward15() {
        HapticManager.shared.playLightImpact()
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.duration, player.currentTime + 15)
        currentTime = player.currentTime
    }
    
    private func seekToProgress(_ progress: Double) {
        guard let player = audioPlayer else { return }
        let newTime = progress * player.duration
        player.currentTime = newTime
        currentTime = newTime
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Large Media Control Style

struct LargeMediaControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(LinearColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .overlay(
                Circle()
                    .strokeBorder(LinearColors.cardBorder.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Transcript Modal View

struct TranscriptModalView: View {
    let transcript: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(transcript)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .lineSpacing(6)
                }
                .padding(Spacing.containerMargin)
            }
            .navigationTitle("Weekly Insights")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(LinearColors.accent)
            )
        }
    }
}