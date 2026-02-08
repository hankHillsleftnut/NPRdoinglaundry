//
//  DarkAudioPlayerView.swift
//  Retrospect
//
//  Full screen audio player for the dark UI
//  Animated gradient background based on mood, full playback controls
//

import SwiftUI
import AVFoundation

struct DarkAudioPlayerView: View {
    let transcript: TranscriptModel
    @ObservedObject var audioManager: DarkAudioManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isDragging = false
    @State private var showTranscript = false
    @State private var animateGradient = false
    @State private var showInsights = false
    @State private var insights: [BackendInsight] = []
    @State private var isLoadingInsights = false
    
    private var hasAudio: Bool {
        transcript.audioFileURL != nil && audioManager.audioPlayer != nil
    }
    
    private var duration: TimeInterval {
        audioManager.audioPlayer?.duration ?? 0
    }
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private var podcastMood: PodcastMood {
        guard let moodString = transcript.mood else { return .neutral }
        return PodcastMood(rawValue: moodString.lowercased()) ?? .neutral
    }
    
    private var moodColors: [Color] {
        switch podcastMood {
        case .positive: return LinearColors.Minimal.Mood.positive
        case .neutral: return LinearColors.Minimal.Mood.neutral
        case .reflective: return LinearColors.Minimal.Mood.reflective
        case .energetic: return LinearColors.Minimal.Mood.energetic
        case .calm: return LinearColors.Minimal.Mood.calm
        case .mysterious: return LinearColors.Minimal.Mood.mysterious
        case .happy: return LinearColors.Minimal.Mood.happy
        case .melancholic: return LinearColors.Minimal.Mood.melancholic
        }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Now Playing")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        // Insights button
                        if transcript.insightIds != nil && !(transcript.insightIds?.isEmpty ?? true) {
                            Button(action: {
                                HapticManager.shared.playLightImpact()
                                showInsights = true
                                if insights.isEmpty { loadInsights() }
                            }) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            showTranscript = true
                        }) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // Album artwork
                ZStack {
                    // Glowing background
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    moodColors[0].opacity(0.5),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 80,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .blur(radius: 40)
                    
                    // Main artwork
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: moodColors + moodColors.reversed()),
                                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                                endPoint: animateGradient ? .bottomTrailing : .topLeading
                            )
                        )
                        .frame(width: 280, height: 280)
                        .overlay(
                            Image(systemName: "waveform")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.white.opacity(0.9))
                        )
                        .shadow(color: moodColors[0].opacity(0.5), radius: 40, x: 0, y: 20)
                }
                .padding(.vertical, 40)
                
                Spacer()
                
                // Track info
                VStack(spacing: 8) {
                    Text("Weekly Insights")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(podcastMood.displayName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 32)
                
                // Progress bar (only if audio is available)
                if hasAudio {
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * progress, height: 4)
                                
                                // Scrubber
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                                    .offset(x: (geometry.size.width * progress) - (isDragging ? 8 : 6))
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                isDragging = true
                                                let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                                currentTime = duration * newProgress
                                                audioManager.seekTo(progress: newProgress)
                                            }
                                            .onEnded { _ in
                                                isDragging = false
                                            }
                                    )
                            }
                        }
                        .frame(height: 16)
                        
                        // Time labels
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                } else {
                    // No audio - show transcript preview
                    VStack(spacing: 8) {
                        Text("Transcript Preview")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(transcript.processedTranscript?.prefix(200).description ?? "No transcript available")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                        
                        Text("...")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
                
                // Error message if any
                if let error = audioManager.lastError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 14, weight: .medium))
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }
                
                // Playback controls (only if audio is available)
                if hasAudio {
                    HStack(spacing: 48) {
                        // Rewind 15s
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            let newTime = max(currentTime - 15, 0)
                            audioManager.audioPlayer?.currentTime = newTime
                            currentTime = newTime
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        // Play/Pause
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            audioManager.togglePlayback()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 72, height: 72)
                                
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(moodColors[0])
                                    .offset(x: audioManager.isPlaying ? 0 : 2)
                            }
                        }
                        
                        // Forward 15s
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            let newTime = min(currentTime + 15, duration)
                            audioManager.audioPlayer?.currentTime = newTime
                            currentTime = newTime
                        }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 60)
                } else {
                    // No audio - show "Read Transcript" button instead
                    VStack(spacing: 16) {
                        Text("Audio not available")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            showTranscript = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Read Transcript")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(moodColors[0])
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupTimer()
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .sheet(isPresented: $showTranscript) {
            DarkTranscriptSheet(transcript: transcript)
        }
        .sheet(isPresented: $showInsights) {
            DarkInsightsSheet(insights: insights, isLoading: isLoadingInsights)
        }
    }
    
    private func loadInsights() {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        isLoadingInsights = true
        Task {
            do {
                let allInsights = try await RetrospectAPIClient.shared.fetchInsights()
                let episodeInsightIds = Set(transcript.insightIds ?? [])
                let filtered = allInsights.filter { episodeInsightIds.contains($0.id) }
                await MainActor.run {
                    self.insights = filtered.isEmpty ? allInsights : filtered
                    self.isLoadingInsights = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingInsights = false
                }
            }
        }
    }
    
    private var animatedBackground: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            // Animated gradient orbs
            Circle()
                .fill(moodColors[0].opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: animateGradient ? 50 : -50,
                    y: animateGradient ? -100 : 100
                )
            
            Circle()
                .fill(moodColors[1].opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(
                    x: animateGradient ? -80 : 80,
                    y: animateGradient ? 150 : -50
                )
            
            if moodColors.count > 2 {
                Circle()
                    .fill(moodColors[2].opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(
                        x: animateGradient ? 100 : -100,
                        y: animateGradient ? 50 : -150
                    )
            }
        }
        .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateGradient)
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !isDragging {
                currentTime = audioManager.audioPlayer?.currentTime ?? 0
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Transcript Sheet
struct DarkTranscriptSheet: View {
    let transcript: TranscriptModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.textTertiary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    Text("Transcript")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Content
                ScrollView {
                    Text(transcript.processedTranscript ?? "No transcript available")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(8)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Insights Sheet
struct DarkInsightsSheet: View {
    let insights: [BackendInsight]
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.textTertiary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insights")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        Text("\(insights.count) insights behind this episode")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                    Text("Loading insights...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        .padding(.top, 8)
                    Spacer()
                } else if insights.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Text("No insights available")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(insights) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: BackendInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow.opacity(0.9))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    // Confidence pill
                    HStack(spacing: 6) {
                        Text("\(Int(insight.confidenceScore * 100))% confidence")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Text(formatDate(insight.updatedAt))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
            
            // Content (always visible)
            Text(insight.content)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
                .lineLimit(isExpanded ? nil : 3)
            
            // Evidence (expanded only)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Evidence")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.accent)
                    
                    Text(insight.evidenceSummary)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    DarkAudioPlayerView(
        transcript: TranscriptModel.sample,
        audioManager: DarkAudioManager.shared
    )
}

