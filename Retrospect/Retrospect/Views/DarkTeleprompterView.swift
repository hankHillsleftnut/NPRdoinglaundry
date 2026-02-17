//
//  DarkTeleprompterView.swift
//  Retrospect
//
//  Teleprompter-style follow-along view for podcast playback.
//  Words highlight from white to gray as the podcast plays.
//

import SwiftUI

struct DarkTeleprompterView: View {
    let transcript: TranscriptModel
    @ObservedObject var audioManager: DarkAudioManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isDragging = false
    @State private var scrollProxy: ScrollViewProxy?
    
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
    
    // Split script into sentences for the teleprompter
    private var sentences: [String] {
        guard let script = transcript.processedTranscript else { return [] }
        // Clean audio tags like [laughs], [sighs], etc. for display
        let cleaned = script.replacingOccurrences(
            of: "\\[\\w+(?:\\s\\w+)*\\]",
            with: "",
            options: .regularExpression
        )
        // Split into sentences
        var results: [String] = []
        cleaned.enumerateSubstrings(in: cleaned.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                results.append(s)
            }
        }
        return results
    }
    
    // Which sentence index corresponds to the current playback position
    private var currentSentenceIndex: Int {
        guard !sentences.isEmpty, duration > 0 else { return 0 }
        let index = Int(progress * Double(sentences.count))
        return min(index, sentences.count - 1)
    }
    
    var body: some View {
        ZStack {
            // Solid dark background
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(LinearColors.Minimal.border)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Teleprompter text area
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Top padding to center the active text
                            Spacer()
                                .frame(height: 40)
                            
                            ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                Text(sentence + " ")
                                    .font(.custom("EBGaramond12-Regular", size: 34))
                                    .lineSpacing(10)
                                    .foregroundColor(colorForSentence(at: index))
                                    .multilineTextAlignment(.leading)
                                    .id(index)
                                    .animation(.easeInOut(duration: 0.4), value: currentSentenceIndex)
                            }
                            
                            // Bottom padding
                            Spacer()
                                .frame(height: 300)
                        }
                        .padding(.horizontal, 28)
                    }
                    .mask(
                        // Fade edges for that cinematic scroll feel
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, LinearColors.Minimal.pureWhite],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                            
                            LinearColors.Minimal.pureWhite
                            
                            LinearGradient(
                                colors: [LinearColors.Minimal.pureWhite, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                        }
                    )
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: currentSentenceIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo(max(0, newIndex - 1), anchor: .top)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom section: episode card + controls
                VStack(spacing: 16) {
                    // Episode card
                    episodeCard
                    
                    // Progress bar
                    if hasAudio {
                        VStack(spacing: 6) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(LinearColors.Minimal.progressTrack)
                                        .frame(height: 3)
                                    
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(LinearColors.Minimal.textPrimary)
                                        .frame(width: geometry.size.width * progress, height: 3)
                                }
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
                            .frame(height: 12)
                            
                            HStack {
                                Spacer()
                                Text(formatTime(hasAudio ? duration : estimatedDuration))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                    
                    // Playback controls
                    if hasAudio {
                        HStack(spacing: 44) {
                            Button(action: {
                                HapticManager.shared.playLightImpact()
                                let newTime = max(currentTime - 15, 0)
                                audioManager.audioPlayer?.currentTime = newTime
                                currentTime = newTime
                            }) {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Button(action: {
                                HapticManager.shared.playMediumImpact()
                                audioManager.togglePlayback()
                            }) {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                    .offset(x: audioManager.isPlaying ? 0 : 2)
                            }
                            
                            Button(action: {
                                HapticManager.shared.playLightImpact()
                                let newTime = min(currentTime + 15, duration)
                                audioManager.audioPlayer?.currentTime = newTime
                                currentTime = newTime
                            }) {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { setupTimer() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Episode Card
    
    private var episodeCard: some View {
        HStack(spacing: 14) {
            // Polaroid-style album art
            ZStack {
                // White polaroid border
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearColors.Minimal.pureWhite)
                    .frame(width: 68, height: 76)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Mood gradient art
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: moodColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 52)
                    .offset(y: -5)
            }
            .rotationEffect(.degrees(-3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episodeLabel)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(transcript.processedTranscript != nil
                     ? extractTitle(from: transcript.processedTranscript!)
                     : "This week's episode")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 28)
    }
    
    // MARK: - Helpers
    
    private func colorForSentence(at index: Int) -> Color {
        let distance = index - currentSentenceIndex
        
        if distance < 0 {
            // Already spoken — bright white
            return .white
        } else if distance == 0 {
            // Currently being spoken — bright white
            return .white
        } else if distance <= 2 {
            // Next 1-2 sentences — medium gray
            return .white.opacity(0.35)
        } else {
            // Further ahead — faded gray
            return .white.opacity(0.15)
        }
    }
    
    private var episodeLabel: String {
        if let mood = transcript.mood {
            return mood.lowercased()
        }
        return "episode"
    }
    
    private var estimatedDuration: TimeInterval {
        guard let script = transcript.processedTranscript else { return 0 }
        let wordCount = script.split(separator: " ").count
        return Double(wordCount) / 2.5 // ~150 words per minute
    }
    
    private func extractTitle(from script: String) -> String {
        // Take first sentence as a rough title
        let firstSentence = script.prefix(100)
        if let endIndex = firstSentence.firstIndex(where: { ".!?".contains($0) }) {
            let title = String(firstSentence[...endIndex])
            // Clean audio tags
            return title.replacingOccurrences(
                of: "\\[\\w+(?:\\s\\w+)*\\]",
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(firstSentence).trimmingCharacters(in: .whitespacesAndNewlines)
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

#Preview {
    DarkTeleprompterView(
        transcript: TranscriptModel.sample,
        audioManager: DarkAudioManager.shared
    )
}
