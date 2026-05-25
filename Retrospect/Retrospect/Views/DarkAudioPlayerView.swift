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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if transcriptSegments.isEmpty {
                        Text(transcript.processedTranscript ?? "No transcript available.")
                            .font(.custom("HedvigLettersSerif-24ptRegular", size: 30))
                            .foregroundColor(playbackMuted)
                            .lineSpacing(4)
                    } else {
                        ForEach(transcriptSegments) { segment in
                            PodcastTranscriptLine(
                                segment: segment,
                                currentIndex: currentSegmentIndex,
                                ink: playbackInk,
                                muted: playbackMuted
                            )
                            .id(segment.id)
                        }
                    }
                }
                .padding(.horizontal, 38)
                .padding(.top, 72)
                .padding(.bottom, 260)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                edgeBlurOverlay(startOpaque: true)
                    .frame(height: 138)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                edgeBlurOverlay(startOpaque: false)
                    .frame(height: 278)
                    .allowsHitTesting(false)
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 76)

                    Color.black

                    LinearGradient(
                        colors: [.black, .black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                }
            )
            .onAppear { scrollProxy = proxy }
            .onChange(of: currentSegmentIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.7)) {
                    proxy.scrollTo("segment-\(newIndex)", anchor: .top)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func edgeBlurOverlay(startOpaque: Bool) -> some View {
        let gradient = LinearGradient(
            colors: startOpaque
                ? [playbackSurface, playbackSurface.opacity(0.92), playbackSurface.opacity(0)]
                : [playbackSurface.opacity(0), playbackSurface.opacity(0.86), playbackSurface],
            startPoint: .top,
            endPoint: .bottom
        )

        return ZStack {
            gradient
            gradient.blur(radius: 18)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(playbackMuted.opacity(0.22))
                            .frame(height: 3)

                        Capsule()
                            .fill(playbackMuted.opacity(0.86))
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
                .frame(height: 18)

                HStack {
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

                    Spacer()

                    Text(formatTime(max(0, duration - currentTime)))
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(playbackMuted)
                }
            }

            HStack(spacing: 20) {
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    if hasAudio {
                        let newTime = max(currentTime - 15, 0)
                        audioManager.audioPlayer?.currentTime = newTime
                        currentTime = newTime
                    }
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .disabled(!hasAudio)

                Button(action: {
                    HapticManager.shared.playMediumImpact()
                    if hasAudio {
                        audioManager.togglePlayback()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .offset(x: audioManager.isPlaying ? 0 : 1.5)
                        .frame(width: 28, height: 28)
                }
                .disabled(!hasAudio)

                Button(action: {
                    HapticManager.shared.playLightImpact()
                    if hasAudio {
                        let newTime = min(currentTime + 15, duration)
                        audioManager.audioPlayer?.currentTime = newTime
                        currentTime = newTime
                    }
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .disabled(!hasAudio)
            }
            .foregroundColor(playbackMuted)
            .opacity(hasAudio ? 1 : 0.42)
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(playbackControl)
            )
        }
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

private struct PodcastTranscriptLine: View {
    let segment: PodcastTranscriptSegment
    let currentIndex: Int
    let ink: Color
    let muted: Color

    private var distance: Int {
        segment.index - currentIndex
    }

    private var absoluteDistance: Int {
        abs(distance)
    }

    private var foreground: Color {
        if distance == 0 { return ink }
        if distance < 0 {
            return ink.opacity(max(0.0, 0.42 - Double(min(absoluteDistance, 5)) * 0.08))
        }
        return muted.opacity(max(0.18, 0.62 - Double(min(absoluteDistance, 6)) * 0.08))
    }

    private var blurRadius: CGFloat {
        if distance == 0 { return 0 }
        if distance < 0 { return min(18, CGFloat(absoluteDistance) * 4.4) }
        return min(10, CGFloat(absoluteDistance) * 2.1)
    }

    private var verticalOffset: CGFloat {
        if distance == 0 { return 0 }
        return distance < 0 ? -CGFloat(min(absoluteDistance, 3)) * 2 : CGFloat(min(absoluteDistance, 3)) * 1.2
    }

    var body: some View {
        Text(segment.text)
            .font(.custom("HedvigLettersSerif-24ptRegular", size: distance == 0 ? 31 : 30))
            .foregroundColor(foreground)
            .lineSpacing(3)
            .tracking(-0.6)
            .multilineTextAlignment(.leading)
            .blur(radius: blurRadius)
            .opacity(absoluteDistance > 8 ? 0.06 : 1)
            .offset(y: verticalOffset)
            .padding(.bottom, distance == 0 ? 8 : 2)
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
