import SwiftUI
import AVFoundation

// Define the data model for a video journal entry
// struct VideoJournalEntry: Identifiable, Codable {
//     let id: UUID
//     var date: Date
//     var videoURL: URL? // Store the URL of the saved video file
//     var transcript: String
//     var includeInReflection: Bool = false // New flag for weekly reflection
// }

struct VideoLogView: View {
    @ObservedObject private var journalManager = VideoJournalManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedEntry: VideoJournalEntry?
    @State private var avPlayer: AVPlayer?
    @State private var showingPlayer = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if journalManager.entries.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(journalManager.entries.sorted(by: { $0.date > $1.date })) { entry in
                            VideoLogEntryCard(entry: entry)
                                .padding(.horizontal)
                                .onTapGesture {
                                    playVideo(entry: entry)
                                }
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .background(LinearColors.background.edgesIgnoringSafeArea(.all))
        .navigationTitle("Video Journal Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .foregroundColor(LinearColors.accent)
            }
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let entry = selectedEntry, let player = avPlayer {
                VideoPlayerView(entry: entry, player: player)
                    .onDisappear {
                        player.pause()
                        avPlayer = nil
                        selectedEntry = nil
                    }
            }
        }
        .alert("Video Playback Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func playVideo(entry: VideoJournalEntry) {
        // Check if video file exists
        guard FileManager.default.fileExists(atPath: entry.videoURL.path) else {
            errorMessage = "Video file not found. It may have been deleted or moved."
            showingError = true
            return
        }
        
        // Create player - don't check status immediately as it loads asynchronously
        let player = AVPlayer(url: entry.videoURL)
        
        // Set the selected entry and player immediately
        selectedEntry = entry
        avPlayer = player
        showingPlayer = true
        
        // Optional: Add observer for player item status if needed for error handling
        if let playerItem = player.currentItem {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                self.errorMessage = "Video playback failed. The file may be corrupted."
                self.showingError = true
                self.showingPlayer = false
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "video.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(LinearColors.secondaryText.opacity(0.7))
            Text("No Video Journals Yet")
                .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                .foregroundColor(LinearColors.primaryText)
            Text("Your recorded video journals will appear here.")
                .font(.serifBody)
                .foregroundColor(LinearColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct VideoLogEntryCard: View {
    let entry: VideoJournalEntry
    @ObservedObject private var journalManager = VideoJournalManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.serifBody).fontWeight(.semibold)
                        .foregroundColor(LinearColors.primaryText)
                    Text(entry.date, style: .time)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                Spacer()
                
                // Video status indicator
                HStack(spacing: 8) {
                    if FileManager.default.fileExists(atPath: entry.videoURL.path) {
                        Image(systemName: "video.circle.fill")
                            .foregroundColor(LinearColors.accent)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(LinearColors.Minimal.warning)
                    }
                    
                    Toggle("Include in Insights", isOn: Binding(
                        get: { entry.isIncludedInInsights },
                        set: { newValue in
                            journalManager.toggleInclusionStatus(for: entry.id)
                        }
                    ))
                    .labelsHidden()
                    .tint(LinearColors.accent)
                }
            }
            
            // Divider
            Rectangle()
                .fill(LinearColors.border.opacity(0.5))
                .frame(height: 1)
            
            // Transcription
            if !entry.transcription.isEmpty {
                Text(entry.transcription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("No transcription available")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.secondaryText)
                    .italic()
            }
            
            // Video file info
            HStack {
                Text("Video File: \(entry.videoURL.lastPathComponent)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(LinearColors.secondaryText)
                
                Spacer()
                
                if FileManager.default.fileExists(atPath: entry.videoURL.path) {
                    Text("Available")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                } else {
                    Text("Missing")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .coStarCard()
    }
}

struct VideoLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VideoLogView()
        }
    }
} 
