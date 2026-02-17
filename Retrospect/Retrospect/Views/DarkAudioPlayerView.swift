//
//  DarkAudioPlayerView.swift
//  Retrospect
//
//  Full screen podcast detail with teleprompter-style auto-scrolling transcript.
//  Matches the reference UI: artwork top-left, metadata, large title, scrolling body,
//  progress bar, and bottom playback controls.
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
    @State private var showInsights = false
    @State private var insights: [BackendInsight] = []
    @State private var isLoadingInsights = false
    @State private var playbackSpeed: Float = 1.0
    @State private var scrollProxy: ScrollViewProxy?
    
    private let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    private var hasAudio: Bool {
        transcript.audioFileURL != nil && audioManager.audioPlayer != nil
    }
    
    private var duration: TimeInterval {
        audioManager.audioPlayer?.duration ?? estimatedDuration
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
    
    // Split transcript into sentences for teleprompter
    private var sentences: [String] {
        guard let script = transcript.processedTranscript else { return [] }
        let cleaned = script.replacingOccurrences(
            of: "\\[\\w+(?:\\s\\w+)*\\]",
            with: "",
            options: .regularExpression
        )
        var results: [String] = []
        cleaned.enumerateSubstrings(in: cleaned.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                results.append(s)
            }
        }
        return results
    }
    
    private var currentSentenceIndex: Int {
        guard !sentences.isEmpty, duration > 0 else { return 0 }
        let index = Int(progress * Double(sentences.count))
        return min(index, sentences.count - 1)
    }
    
    private var estimatedDuration: TimeInterval {
        guard let script = transcript.processedTranscript else { return 0 }
        let wordCount = script.split(separator: " ").count
        return Double(wordCount) / 2.5
    }
    
    private var episodeTitle: String {
        guard let script = transcript.processedTranscript else { return "This Week's Episode" }
        let firstChunk = script.prefix(150)
        if let endIdx = firstChunk.firstIndex(where: { ".!?".contains($0) }) {
            let title = String(firstChunk[...endIdx])
            return title.replacingOccurrences(
                of: "\\[\\w+(?:\\s\\w+)*\\]",
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(firstChunk).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar: back chevron
                topBar
                
                // Scrollable content: artwork, metadata, title, transcript
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Artwork + action buttons
                            artworkRow
                                .padding(.top, 8)
                            
                            // Metadata line
                            metadataLine
                                .padding(.top, 16)
                            
                            // Large title
                            Text(episodeTitle)
                                .font(.custom("EBGaramond12-Regular", size: 34))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .lineSpacing(6)
                                .padding(.top, 20)
                                .padding(.trailing, 16)
                            
                            // Divider
                            Rectangle()
                                .fill(LinearColors.Minimal.border.opacity(0.5))
                                .frame(height: 0.5)
                                .padding(.top, 28)
                                .padding(.trailing, 16)
                            
                            // Transcript body (teleprompter)
                            teleprompterBody
                                .padding(.top, 24)
                            
                            Spacer(minLength: 220)
                        }
                        .padding(.horizontal, 24)
                    }
                    .mask(
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(
                                colors: [.black, .black.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 80)
                        }
                    )
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: currentSentenceIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.8)) {
                            proxy.scrollTo("sentence-\(max(0, newIndex - 1))", anchor: .top)
                        }
                    }
                }
                
                // Bottom section: progress + controls
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .sheet(isPresented: $showInsights) {
            DarkInsightsSheet(insights: insights, isLoading: isLoadingInsights)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: {
                HapticManager.shared.playLightImpact()
                dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Artwork Row
    
    private var artworkRow: some View {
        HStack(alignment: .top) {
            // Album artwork (mood gradient)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: moodColors + moodColors.reversed()),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(LinearColors.Minimal.pureWhite.opacity(0.9))
            }
            .shadow(color: moodColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                if transcript.insightIds != nil && !(transcript.insightIds?.isEmpty ?? true) {
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        showInsights = true
                        if insights.isEmpty { loadInsights() }
                    }) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    shareTranscript()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                
                Button(action: {
                    HapticManager.shared.playLightImpact()
                }) {
                    Image(systemName: "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Metadata Line
    
    private var metadataLine: some View {
        HStack(spacing: 6) {
            Text("Retrospect")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
            
            Text("·")
                .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.6))
            
            Text(formatFullDate(transcript.createdAt))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textTertiary)
            
            if transcript.isDeepResearch {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(LinearColors.Minimal.accent)
            }
        }
    }
    
    // MARK: - Teleprompter Body
    
    private var teleprompterBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sentences.isEmpty {
                Text(transcript.processedTranscript ?? "No transcript available.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .lineSpacing(10)
            } else {
                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                    Text(sentence)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .lineSpacing(10)
                        .foregroundColor(colorForSentence(at: index))
                        .multilineTextAlignment(.leading)
                        .id("sentence-\(index)")
                        .animation(.easeInOut(duration: 0.5), value: currentSentenceIndex)
                }
            }
        }
        .textSelection(.enabled)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Subtle separator
            Rectangle()
                .fill(LinearColors.Minimal.border)
                .frame(height: 0.5)
            
            VStack(spacing: 16) {
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.progressTrack)
                                .frame(height: 3)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.accent)
                                .frame(width: geometry.size.width * progress, height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                    currentTime = duration * newProgress
                                    if hasAudio {
                                        audioManager.seekTo(progress: newProgress)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                    .frame(height: 14)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Spacer()
                        
                        Text("-" + formatTime(max(0, duration - currentTime)))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                
                // Playback controls row
                HStack(alignment: .center) {
                    // More menu
                    Menu {
                        if transcript.insightIds != nil && !(transcript.insightIds?.isEmpty ?? true) {
                            Button(action: {
                                showInsights = true
                                if insights.isEmpty { loadInsights() }
                            }) {
                                Label("View Insights", systemImage: "lightbulb")
                            }
                        }
                        
                        Button(action: { shareTranscript() }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .frame(width: 40, height: 40)
                    }
                    
                    Spacer()
                    
                    // Center transport: rewind, play, forward
                    HStack(spacing: 32) {
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            if hasAudio {
                                let newTime = max(currentTime - 15, 0)
                                audioManager.audioPlayer?.currentTime = newTime
                                currentTime = newTime
                            }
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .frame(width: 40, height: 40)
                        }
                        .disabled(!hasAudio)
                        .opacity(hasAudio ? 1 : 0.35)
                        
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            if hasAudio {
                                audioManager.togglePlayback()
                            }
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .offset(x: audioManager.isPlaying ? 0 : 2)
                                .frame(width: 48, height: 48)
                        }
                        .disabled(!hasAudio)
                        .opacity(hasAudio ? 1 : 0.35)
                        
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            if hasAudio {
                                let newTime = min(currentTime + 30, duration)
                                audioManager.audioPlayer?.currentTime = newTime
                                currentTime = newTime
                            }
                        }) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .frame(width: 40, height: 40)
                        }
                        .disabled(!hasAudio)
                        .opacity(hasAudio ? 1 : 0.35)
                    }
                    
                    Spacer()
                    
                    // Speed control
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        cycleSpeed()
                    }) {
                        Text(formatSpeed(playbackSpeed))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearColors.Minimal.backgroundCard)
                            )
                    }
                    .frame(width: 40, alignment: .center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .background(LinearColors.Minimal.background)
        }
    }
    
    // MARK: - Helpers
    
    private func colorForSentence(at index: Int) -> Color {
        guard hasAudio, audioManager.isPlaying || currentTime > 0 else {
            return LinearColors.Minimal.textSecondary
        }
        
        let distance = index - currentSentenceIndex
        
        if distance < 0 {
            return LinearColors.Minimal.textPrimary
        } else if distance == 0 {
            return LinearColors.Minimal.textPrimary
        } else if distance <= 2 {
            return LinearColors.Minimal.textTertiary
        } else {
            return LinearColors.Minimal.textTertiary.opacity(0.4)
        }
    }
    
    private func cycleSpeed() {
        guard let currentIdx = availableSpeeds.firstIndex(of: playbackSpeed) else {
            playbackSpeed = 1.0
            audioManager.audioPlayer?.rate = 1.0
            return
        }
        let nextIdx = (currentIdx + 1) % availableSpeeds.count
        playbackSpeed = availableSpeeds[nextIdx]
        audioManager.audioPlayer?.enableRate = true
        audioManager.audioPlayer?.rate = playbackSpeed
    }
    
    private func formatSpeed(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return String(format: "%.1f", speed)
        }
        return String(format: "%.2g", speed)
    }
    
    private func shareTranscript() {
        guard let text = transcript.processedTranscript else { return }
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
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
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !isDragging {
                currentTime = audioManager.audioPlayer?.currentTime ?? 0
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.textTertiary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
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
                
                ScrollView {
                    Text(transcript.processedTranscript ?? "No transcript available")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(8)
                        .textSelection(.enabled)
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.textTertiary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
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
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
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
            
            Text(insight.content)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
                .lineLimit(isExpanded ? nil : 3)
            
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
