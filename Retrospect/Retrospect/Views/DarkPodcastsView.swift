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
    @ObservedObject var entryManager: EntryManager = EntryManager.shared
    @ObservedObject var goalsManager: GoalsManager = GoalsManager.shared
    
    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("mockAPICalls") private var mockAPICalls: Bool = false
    @State private var headerOpacity: Double = 0
    @State private var isGenerating: Bool = false
    @State private var showPodcastArrival: Bool = false
    @State private var generationError: String?
    @State private var showErrorAlert: Bool = false
    @State private var mockTranscript: TranscriptModel?
    
    // Header styling
    private let headerHeight: CGFloat = 50
    
    // Show all saved podcasts
    private var podcasts: [TranscriptModel] {
        return viewModel.savedPodcasts
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .opacity(headerOpacity)
            
            // Content
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
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.3), location: 0.3),
                                .init(color: .black.opacity(0.7), location: 0.6),
                                .init(color: .black, location: 1.0)
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerOpacity = 1
            }
        }
        .onChange(of: viewModel.transcript) { _, newTranscript in
            // When transcript is generated and we were waiting for it, show arrival view
            if isGenerating && newTranscript != nil {
                isGenerating = false
                HapticManager.shared.playSuccessNotification()
                showPodcastArrival = true
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newError in
            // Handle generation errors
            if isGenerating && newError != nil {
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
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                // Title
                Text("Podcasts")
                    .font(.custom("EBGaramond12-Italic", size: 46))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                // Podcast count pill
                Text("\(podcasts.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                Capsule()
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                
                Spacer()
            }
            
            // Dev mode debug info
            if devMode && viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                        .scaleEffect(0.7)
                    
                    Text(viewModel.processingStatus.isEmpty ? "Processing..." : viewModel.processingStatus)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
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
            
            // Show error if any
            if let error = viewModel.errorMessage, devMode {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
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
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
                            ForEach(0..<5, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearColors.Minimal.accent)
                                    .frame(width: 8, height: CGFloat.random(in: 20...50))
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
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        Text(mockAPICalls ? "Using sample data..." : (viewModel.processingStatus.isEmpty ? "Initializing..." : viewModel.processingStatus))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
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
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                }
            } else {
                // Normal empty state
                ZStack {
                    Circle()
                        .fill(LinearColors.Minimal.backgroundCard)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                
                VStack(spacing: 8) {
                    Text("No Podcasts Yet")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Text("Write in your journal and generate\nyour first personalized podcast")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Dev mode: Generate Test Podcast button
                if devMode {
                    Button(action: generateTestPodcast) {
                        HStack(spacing: 10) {
                            Image(systemName: mockAPICalls ? "play.circle.fill" : "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text(mockAPICalls ? "Generate Mock Podcast" : "Generate Real Podcast")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Text(mockAPICalls ? "Uses sample data (no API calls)" : "Uses \(entryManager.getEntriesForWeek().count) entries • \(goalsManager.goals.count) goals")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
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
                
                self.mockTranscript = sampleTranscript
                self.viewModel.transcript = sampleTranscript
                self.isGenerating = false
                HapticManager.shared.playSuccessNotification()
                self.showPodcastArrival = true
            }
            return
        }
        
        // Real API calls - Get real entries from the past week
        let weekEntries = entryManager.getEntriesForWeek()
        let goals = goalsManager.goals
        
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
        viewModel.generateTranscript(text: combinedText, goals: finalGoals)
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
            HStack(spacing: 16) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: moodColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    if isCurrentlyPlaying {
                        // Animated bars for playing state
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearColors.Minimal.pureWhite)
                                    .frame(width: 4, height: CGFloat.random(in: 12...24))
                            }
                        }
                    } else if !hasAudio {
                        // No audio indicator
                        Image(systemName: "doc.text")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Weekly Insights")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        // Show "Text Only" badge if no audio
                        if !hasAudio {
                            Text("Text")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(LinearColors.Minimal.backgroundCardHover)
                                )
                        }
                    }
                    
                    Text(podcastMood.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.accent)
                    
                    Text(formatDate(transcript.createdAt))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                
                Spacer()
                
                // Play indicator or chevron
                Image(systemName: isCurrentlyPlaying ? "speaker.wave.2.fill" : (hasAudio ? "play.circle.fill" : "chevron.right"))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isCurrentlyPlaying ? LinearColors.Minimal.accent : (hasAudio ? LinearColors.Minimal.accent : LinearColors.Minimal.textTertiary))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isCurrentlyPlaying ? LinearColors.Minimal.accent.opacity(0.5) : LinearColors.Minimal.border,
                                lineWidth: 1
                            )
                    )
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


