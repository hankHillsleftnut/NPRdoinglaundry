//
//  DarkAudioPlayerView.swift
//  Retrospect
//
//  Full screen podcast detail with a Figma-led read-along transcript.
//  The current spoken segment stays sharp while surrounding transcript text
//  scrolls upward into a strong blur/fade.
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
    private let playbackSurface = Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255)
    private let playbackBackground = Color(red: 228 / 255, green: 228 / 255, blue: 226 / 255)
    private let playbackControl = Color(red: 234 / 255, green: 231 / 255, blue: 227 / 255)
    private let playbackMuted = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    private let playbackInk = Color.black

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

    private var transcriptSegments: [PodcastTranscriptSegment] {
        guard let script = transcript.processedTranscript else { return [] }
        let cleaned = script.replacingOccurrences(
            of: "(?m)^\\s*#+\\s*|\\[\\w+(?:\\s\\w+)*\\]|^\\s*[-•]\\s*|^\\s*\\d+\\.\\s*",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "\n\n+", with: "\n", options: .regularExpression)

        var results: [String] = []
        cleaned.enumerateSubstrings(in: cleaned.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                results.append(s)
            }
        }

        if results.isEmpty {
            results = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let totalWords = max(results.reduce(0) { $0 + $1.wordCount }, 1)
        var cursor: TimeInterval = 0

        return results.enumerated().map { index, text in
            let segmentDuration = max(1.6, duration * (Double(max(text.wordCount, 1)) / Double(totalWords)))
            let segment = PodcastTranscriptSegment(
                index: index,
                text: text,
                startTime: cursor,
                endTime: cursor + segmentDuration
            )
            cursor += segmentDuration
            return segment
        }
    }

    private var currentSegmentIndex: Int {
        guard !transcriptSegments.isEmpty, duration > 0 else { return 0 }
        if let match = transcriptSegments.first(where: { currentTime >= $0.startTime && currentTime < $0.endTime }) {
            return match.index
        }
        let fallback = Int(progress * Double(transcriptSegments.count))
        return min(max(fallback, 0), transcriptSegments.count - 1)
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
            playbackBackground
                .ignoresSafeArea()

            playbackSurface
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 4)

            VStack(spacing: 0) {
                topBar

                transcriptReader
                    .padding(.top, 52)

                Spacer(minLength: 18)

                bottomControls
            }
        }
        .preferredColorScheme(.light)
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
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(playbackMuted)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color(red: 247 / 255, green: 243 / 255, blue: 238 / 255))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                    )
            }
            .accessibilityLabel("Close podcast")

            Spacer()
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(LinearColors.Minimal.textTertiary)

            Text("·")
                .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.6))

            Text(formatFullDate(transcript.createdAt))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textTertiary)

            if transcript.isDeepResearch {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(LinearColors.Minimal.accent)
            }
        }
    }

    // MARK: - Transcript Reader

    private var transcriptReader: some View {
        PodcastTranscriptReader(
            transcript: transcript.processedTranscript,
            currentTime: currentTime,
            duration: duration,
            theme: .light,
            fontSize: 30,
            horizontalPadding: 38,
            alignment: .leading,
            topInset: 96,
            bottomInset: 220
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        PodcastTransport(
            currentTime: currentTime,
            duration: duration,
            isPlaying: audioManager.isPlaying,
            enabled: hasAudio,
            theme: .light,
            onSeek: { newProgress in
                currentTime = duration * newProgress
                if hasAudio { audioManager.seekTo(progress: newProgress) }
            },
            onSkip: { seconds in
                HapticManager.shared.playLightImpact()
                guard hasAudio else { return }
                let newTime = min(max(currentTime + seconds, 0), duration)
                audioManager.audioPlayer?.currentTime = newTime
                currentTime = newTime
            },
            onToggle: {
                HapticManager.shared.playMediumImpact()
                if hasAudio { audioManager.togglePlayback() }
            },
            leadingAccessory: { transportMenu }
        )
        .padding(.horizontal, 46)
        .padding(.bottom, 38)
        .background(
            LinearGradient(
                colors: [playbackSurface.opacity(0), playbackSurface, playbackSurface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var transportMenu: some View {
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

            Button(action: {
                HapticManager.shared.playLightImpact()
                cycleSpeed()
            }) {
                Label("\(formatSpeed(playbackSpeed))x Speed", systemImage: "speedometer")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(playbackMuted)
                .frame(width: 32, height: 24)
        }
    }

    // MARK: - Helpers

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

private struct PodcastTranscriptSegment: Identifiable {
    let index: Int
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var id: String { "segment-\(index)" }
}

// MARK: - Transcript Line

private struct PodcastTranscriptLine: View {
    let segment: PodcastTranscriptSegment
    let currentIndex: Int
    let ink: Color
    let muted: Color

    private var distance: Int { segment.index - currentIndex }

    var body: some View {
        Text(segment.text)
            .font(.custom("HedvigLettersSerif-24ptRegular", size: 30))
            .foregroundColor(distance == 0 ? ink : muted.opacity(0.48))
            .lineSpacing(3)
            .tracking(-0.6)
            .multilineTextAlignment(.leading)
            .blur(radius: distance == 0 ? 0 : 1.8)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.45), value: currentIndex)
    }
}

private extension String {
    var wordCount: Int {
        split { $0.isWhitespace || $0.isNewline }.count
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
                        .font(.system(size: 20, weight: .bold))
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
                        .font(.system(size: 16, weight: .regular))
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
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        Text("\(insights.count) insights behind this episode")
                            .font(.system(size: 13, weight: .regular))
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
                        .font(.system(size: 14, weight: .medium))
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
                            .font(.system(size: 16, weight: .medium))
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)

                    HStack(spacing: 6) {
                        Text("\(Int(insight.confidenceScore * 100))% confidence")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textTertiary)

                        Text(formatDate(insight.updatedAt))
                            .font(.system(size: 11, weight: .regular))
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
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(LinearColors.Minimal.textSecondary)
                .lineLimit(isExpanded ? nil : 3)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Evidence")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.accent)

                    Text(insight.evidenceSummary)
                        .font(.system(size: 13, weight: .regular))
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
