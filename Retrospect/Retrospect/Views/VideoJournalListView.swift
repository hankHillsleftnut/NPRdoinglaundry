import SwiftUI
import AVKit

struct VideoJournalListView: View {
    @StateObject private var journalManager = VideoJournalManager.shared
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("devMode") private var devMode: Bool = false
    @State private var selectedEntry: VideoJournalEntry?
    @State private var avPlayer: AVPlayer?
    @State private var showingPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            VStack(spacing: 16) {
                HStack {
                    Text("Video Journal")
                        .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                        .foregroundColor(LinearColors.primaryText)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 16)
            .background(LinearColors.background)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            
            if journalManager.entries.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    // Stats and entries content
                    VStack(spacing: 16) {
                        // Stats Cards
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Total Journals",
                                value: "\(journalManager.entries.count)",
                                icon: "video.circle.fill"
                            )
                            
                            StatCard(
                                title: "This Week",
                                value: "\(journalManager.getEntriesForWeek().count)",
                                icon: "calendar.circle.fill"
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        
                        // Section Title
                        HStack {
                            Text("Recent Entries")
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(LinearColors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Journal Entries List
                        LazyVStack(spacing: 12) {
                            ForEach(journalManager.entries.sorted(by: { $0.date > $1.date })) { entry in
                                JournalEntryCard(entry: entry)
                                    .onTapGesture {
                                        playVideo(entry: entry)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)

                    }
                }
            }
        }
        .background(
            RadialGradient(
                gradient: Gradient(colors: [
                    LinearColors.backgroundLight,
                    LinearColors.background
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 1.5
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .foregroundColor(LinearColors.accent)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LinearColors.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(LinearColors.accent.opacity(0.15))
                        )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showingPlayer) {
            if let entry = selectedEntry {
                VideoPlayerView(entry: entry, player: avPlayer ?? AVPlayer(url: entry.videoURL))
                    .onDisappear {
                        avPlayer?.pause()
                        avPlayer = nil
                    }
            }
        }
        .onAppear {
            // Debug: Print current entries and enable debugging
            print("🎬 VideoJournalListView appeared with \(journalManager.entries.count) entries")
            journalManager.debugPrintEntries()
        }
    }
    
    private func playVideo(entry: VideoJournalEntry) {
        // Debug: Print video file path and check existence
        print("🎬 Attempting to play video: \(entry.videoURL.path)")
        print("🎬 File exists: \(FileManager.default.fileExists(atPath: entry.videoURL.path))")
        
        // Check if video file exists
        guard FileManager.default.fileExists(atPath: entry.videoURL.path) else {
            print("❌ Video file not found at: \(entry.videoURL.path)")
            return
        }
        
        print("✅ Video file found, creating player...")
        selectedEntry = entry
        avPlayer = AVPlayer(url: entry.videoURL)
        showingPlayer = true
        print("✅ Player created and showing player view")
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "video.slash.fill")
                .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                .foregroundColor(LinearColors.secondaryText.opacity(0.7))
            Text("No Video Journals Yet")
                .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                .foregroundColor(LinearColors.primaryText)
            Text("Start recording your video journals, and they will appear here.")
                .font(.serifBody)
                .foregroundColor(LinearColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(LinearColors.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LinearColors.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.secondaryText)
                Text(value)
                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                    .foregroundColor(LinearColors.primaryText)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.Minimal.pureWhite)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
        )
    }
}

struct JournalEntryCard: View {
    let entry: VideoJournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and date
            HStack(spacing: 15) {
                // Video icon with gradient background
                ZStack {
                    Circle()
                        .fill(LinearColors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(LinearColors.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.serifBody).fontWeight(.semibold)
                        .foregroundColor(LinearColors.primaryText)
                    Text(entry.date, style: .time)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(LinearColors.accent)
            }
            
            // Divider
            Rectangle()
                .fill(LinearColors.border.opacity(0.5))
                .frame(height: 1)
            
            // Transcription preview
            if !entry.transcription.isEmpty {
                Text(entry.transcription)
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                Text("No transcription available")
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.secondaryText)
                    .italic()
            }
            
            // Footer with insights toggle
            HStack {
                Text("Include in Insights")
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.secondaryText)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { entry.isIncludedInInsights },
                    set: { _ in
                        VideoJournalManager.shared.toggleInclusionStatus(for: entry.id)
                    }
                ))
                .labelsHidden()
                .tint(LinearColors.accent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.Minimal.pureWhite)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
        )
    }
}

struct VideoPlayerView: View {
    let entry: VideoJournalEntry
    @State var player: AVPlayer
    @Environment(\.presentationMode) var presentationMode

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Journal")
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    Text(entry.date, formatter: Self.dateFormatter)
                        .font(.serifLabel)
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.8))
                }
                
                Spacer()
                
                Button {
                    player.pause()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.8))
                }
            }
            .padding()
            .background(LinearColors.Minimal.background)
            
            // Video Player
            AVPlayerViewControllerRepresentable(player: player)
                .onAppear {
                    print("🎬 VideoPlayerView appeared, starting playback...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        player.play()
                        print("🎬 Player.play() called")
                    }
                }
                .onDisappear {
                    print("🎬 VideoPlayerView disappeared, pausing...")
                    player.pause()
                }
            
            // Transcription Section
            if !entry.transcription.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transcription")
                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        Text(entry.transcription)
                            .font(.serifBody)
                            .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.9))
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(LinearColors.Minimal.background)
                .frame(maxHeight: 200)
            }
        }
        .background(LinearColors.Minimal.background.ignoresSafeArea(.all))
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("🎬 Creating AVPlayerViewController...")
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        print("🎬 AVPlayerViewController created with player: \(player)")
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        print("🎬 Updating AVPlayerViewController with player: \(player)")
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}

struct VideoJournalListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VideoJournalListView()
        }
    }
} 