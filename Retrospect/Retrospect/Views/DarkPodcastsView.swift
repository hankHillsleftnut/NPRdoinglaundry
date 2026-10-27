//
//  DarkPodcastsView.swift
//  Retrospect
//
//  List of all generated podcasts in dark UI
//

import SwiftUI

struct DarkPodcastsView: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @ObservedObject var audioManager: DarkAudioManager
    @ObservedObject var entryManager: EntryManager = .shared
    @ObservedObject var goalsManager: GoalsManager = .shared

    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("mockAPICalls") private var mockAPICalls: Bool = false
    @State private var headerOpacity: Double = 0
    @State private var isGenerating: Bool = false
    @State private var showPodcastArrival: Bool = false
    @State private var generationError: String?
    @State private var showErrorAlert: Bool = false
    @State private var mockTranscript: TranscriptModel?

    /// Header styling
    private let headerHeight: CGFloat = 50

    /// Show all saved podcasts
    private var podcasts: [TranscriptModel] {
        return viewModel.savedPodcasts
    }

    var body: some View {
        FigmaLightPageScaffold(title: "Episodes") {
            VStack(spacing: 8) {
                if devMode {
                    devRows
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }

                if podcasts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(podcasts) { transcript in
                                DarkPodcastCard(
                                    transcript: transcript,
                                    audioManager: audioManager,
                                    isCurrentlyPlaying: audioManager.currentTranscript?.id == transcript.id && audioManager.isPlaying
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deletePodcast(transcript)
                                        HapticManager.shared.playMediumImpact()
                                    } label: {
                                        Label("Delete Podcast", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.3), location: 0.3),
                                    .init(color: .black.opacity(0.7), location: 0.6),
                                    .init(color: .black, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 16)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 50)
                        }
                    )
                }
            }
            .opacity(headerOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerOpacity = 1
            }
        }
        .onChange(of: viewModel.transcript) { _, newTranscript in
            // When transcript is generated and we were waiting for it, show arrival view
            if isGenerating, newTranscript != nil {
                isGenerating = false
                HapticManager.shared.playSuccessNotification()
                showPodcastArrival = true
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newError in
            // Handle generation errors
            if isGenerating, newError != nil {
                isGenerating = false
                generationError = newError
                showErrorAlert = true
            }
        }
        .fullScreenCover(isPresented: $showPodcastArrival) {
            if let transcript = viewModel.transcript {
                NewPodcastArrivalView(
                    transcript: transcript,
                    onPlay: {
                        // Start playback via audio manager
                        audioManager.currentTranscript = transcript
                        audioManager.showMiniPlayer = true
                        audioManager.isPlaying = true
                        // Dismiss arrival view
                        showPodcastArrival = false
                        // Show the full player
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            audioManager.showFullPlayer = true
                        }
                    },
                    onDismiss: {
                        showPodcastArrival = false
                    }
                )
            }
        }
        .alert("Podcast Generation Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                generationError = nil
            }
        } message: {
            Text(generationError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Dev rows (rendered below scaffold header in dev mode only)

    @ViewBuilder private var devRows: some View {
        if viewModel.isProcessing {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                    .scaleEffect(0.7)

                Text(viewModel.processingStatus.isEmpty ? "Processing..." : viewModel.processingStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.accent)

                Spacer()

                Text("\(Int(viewModel.currentProgress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LinearColors.Minimal.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }

        if let error = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)

                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(2)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearColors.Minimal.errorSubtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LinearColors.Minimal.error.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            if isGenerating {
                // Show generation progress
                VStack(spacing: 24) {
                    // Animated waveform
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.accent.opacity(0.15))
                            .frame(width: 120, height: 120)

                        HStack(spacing: 6) {
                            ForEach(0 ..< 5, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearColors.Minimal.accent)
                                    .frame(width: 8, height: CGFloat.random(in: 20 ... 50))
                                    .animation(
                                        Animation.easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(Double(index) * 0.1),
                                        value: isGenerating
                                    )
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Text(mockAPICalls ? "Creating Mock Podcast" : "Generating Your Podcast")
                            .font(FigmaLightTheme.title(30))
                            .foregroundColor(FigmaLightTheme.primaryText.opacity(0.72))

                        Text(mockAPICalls ? "Using sample data..." : (viewModel.processingStatus.isEmpty ? "Initializing..." : viewModel.processingStatus))
                            .font(FigmaLightTheme.mono(15))
                            .foregroundColor(FigmaLightTheme.mutedText)
                            .animation(.easeInOut, value: viewModel.processingStatus)

                        // Progress bar (only show for real API calls)
                        if !mockAPICalls {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearColors.Minimal.backgroundCard)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearColors.Minimal.accent)
                                        .frame(width: geometry.size.width * viewModel.currentProgress, height: 8)
                                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentProgress)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 40)

                            Text("\(Int(viewModel.currentProgress * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                }
            } else {
                // Normal empty state
                ZStack {
                    Circle()
                        .fill(FigmaLightTheme.rowSurface)
                        .frame(width: 100, height: 100)

                    Image(systemName: "waveform")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(FigmaLightTheme.mutedText)
                }

                VStack(spacing: 8) {
                    Text("No Podcasts Yet")
                        .font(FigmaLightTheme.title(30))
                        .foregroundColor(FigmaLightTheme.primaryText.opacity(0.72))

                    Text("Write in your journal and generate\nyour first personalized podcast")
                        .font(FigmaLightTheme.body(15))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .multilineTextAlignment(.center)
                }

                // Dev mode: Generate Test Podcast button
                if devMode {
                    Button(action: generateTestPodcast) {
                        HStack(spacing: 10) {
                            Image(systemName: mockAPICalls ? "play.circle.fill" : "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text(mockAPICalls ? "Generate Mock Podcast" : "Generate Real Podcast")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(LinearColors.Minimal.accent)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                        .shadow(color: LinearColors.Minimal.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 12)

                    // Info text
                    VStack(spacing: 4) {
                        Text("Dev Mode")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textTertiary)

                        Text(mockAPICalls ? "Uses sample data (no API calls)" :
                            "Uses \(entryManager.getEntriesForWeek().count) entries • \(goalsManager.goals.count) goals")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textTertiary.opacity(0.7))
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func generateTestPodcast() {
        HapticManager.shared.playMediumImpact()
        isGenerating = true
        generationError = nil

        // If Mock API Calls is enabled, use sample data without real API calls
        if mockAPICalls {
            print("🔧 Mock API Calls enabled - using sample data")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let sampleTranscript = TranscriptModel(
                    id: UUID(),
                    originalText: "Sample journal entries for podcast generation.",
                    goals: ["Personal growth", "Work-life balance", "Self-reflection"],
                    processedTranscript: """
                    This week has been quite a journey for you. Looking at everything you've shared, there's a clear pattern emerging—one that speaks to your growth and the challenges you're facing.

                    Let's start with what's been on your mind the most. You've been thinking a lot about balance—between work and personal life, between ambition and contentment. And here's the thing: that tension isn't a bug, it's a feature. It means you care about both sides.

                    What I noticed in your entries is a shift in how you're talking about your goals. Early in the week, there was hesitation. By Thursday, something clicked. You started writing with more certainty, more ownership of your direction.

                    The pattern I want to highlight: every time you wrote about feeling stuck, it was followed within 24 hours by a breakthrough insight. Your brain is working on these problems even when you think you're not making progress.

                    For next week, consider this: what if the uncertainty you're feeling isn't a problem to solve, but information to listen to? Sometimes our discomfort is pointing us exactly where we need to look.

                    Until next time, keep writing. Keep reflecting. The clarity is coming.
                    """,
                    audioFileURL: nil,
                    mood: "reflective",
                    generationType: .goodListener,
                    googleDocsInfo: nil,
                    isDeepResearch: false,
                    citations: nil,
                    researchQueries: nil,
                    createdAt: Date()
                )

                mockTranscript = sampleTranscript
                viewModel.transcript = sampleTranscript
                isGenerating = false
                HapticManager.shared.playSuccessNotification()
                showPodcastArrival = true
            }
            return
        }

        // Real API calls - Get real entries from the past week
        let weekEntries = entryManager.getEntriesForWeek()
        let goals = goalsManager.goalContextForGeneration

        // Build combined text from entries
        var combinedText = ""

        if weekEntries.isEmpty {
            // If no entries, use sample data for testing
            combinedText = """
            Today I've been thinking about my goals and how to make progress on them.
            I feel motivated to improve my habits and build better routines.
            Work has been challenging but I'm learning to manage stress better.
            I want to focus on personal growth and being more present in my daily life.
            """
        } else {
            // Combine all entries from the week
            let sortedEntries = weekEntries.sorted { $0.date < $1.date }

            for entry in sortedEntries {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short

                let entryHeader = "[\(dateFormatter.string(from: entry.date)) - \(entry.type.rawValue.capitalized)]"
                combinedText += "\(entryHeader)\n\(entry.content)\n\n"
            }
        }

        // Use default goals if none exist
        let finalGoals = goals.isEmpty ? ["Personal growth", "Self-reflection", "Well-being"] : goals

        print("🎙️ Generating podcast with \(weekEntries.count) entries and \(finalGoals.count) goals")
        print("📝 Combined text length: \(combinedText.count) characters")

        // Call the actual transcript generation
        viewModel.generateTranscript(
            text: combinedText,
            goals: finalGoals,
            generationSource: .weeklyRecurring
        )
    }
}

// MARK: - Podcast Card

struct DarkPodcastCard: View {
    let transcript: TranscriptModel
    @ObservedObject var audioManager: DarkAudioManager
    let isCurrentlyPlaying: Bool

    private var hasAudio: Bool {
        transcript.audioFileURL != nil
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
        Button(action: {
            HapticManager.shared.playMediumImpact()
            print("🎵 Podcast card tapped")
            print("   - Transcript ID: \(transcript.id)")
            print("   - Has audio: \(hasAudio)")
            print("   - Has transcript text: \(transcript.processedTranscript != nil)")

            // Use showTranscript which handles both audio and no-audio cases
            audioManager.showTranscript(transcript: transcript)
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(FigmaLightTheme.controlSurface)
                        .frame(width: 42, height: 42)
                        .overlay(Circle().strokeBorder(FigmaLightTheme.border, lineWidth: 1))

                    if isCurrentlyPlaying {
                        HStack(spacing: 3) {
                            ForEach(0 ..< 3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(FigmaLightTheme.mutedText)
                                    .frame(width: 3, height: CGFloat(12 + index * 4))
                            }
                        }
                    } else if !hasAudio {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(FigmaLightTheme.mutedText)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FigmaLightTheme.mutedText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Weekly Insights")
                            .font(FigmaLightTheme.body(18, weight: .semibold))
                            .foregroundColor(FigmaLightTheme.primaryText)

                        if !hasAudio {
                            Text("Text")
                                .font(FigmaLightTheme.mono(10, weight: .semibold))
                                .foregroundColor(FigmaLightTheme.mutedText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(FigmaLightTheme.controlSurface)
                                )
                        }
                    }

                    Text("\(podcastMood.displayName.lowercased()) • \(formatDate(transcript.createdAt))")
                        .font(FigmaLightTheme.mono(14))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isCurrentlyPlaying ? "speaker.wave.2.fill" : (hasAudio ? "play.fill" : "chevron.right"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FigmaLightTheme.faintText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(FigmaLightTheme.rowSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(FigmaLightTheme.border.opacity(isCurrentlyPlaying ? 1 : 0.75), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isCurrentlyPlaying ? 0.09 : 0.045), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()

        DarkPodcastsView(
            viewModel: TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared),
            audioManager: DarkAudioManager.shared
        )
    }
}
