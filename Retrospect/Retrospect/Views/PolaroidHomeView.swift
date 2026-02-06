import SwiftUI

struct PolaroidHomeView: View {
    let devMode: Bool
    @Environment(\.presentationMode) var presentationMode
    
    // Audio and transcript state
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    @ObservedObject private var goalsManager = GoalsManager.shared
    
    // UI State
    @State private var isPlaying = false
    @State private var showingControls = false
    
    // Input text for podcast generation
    @State private var inputText = ""
    @State private var showingInputSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - original cream/grey design
                LinearColors.backgroundGrey
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar with close button
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    if showingControls {
                        // Playing state: Polaroid at top, controls at bottom
                        playingStateView(geometry: geometry)
                    } else {
                        // Initial state: Polaroid centered with play button below
                        initialStateView(geometry: geometry)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Dev mode is already handled by @AppStorage in the ViewModel
            // No need to set it manually since it's private
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            if !isProcessing && viewModel.transcript != nil {
                // Auto-play when generation completes
                startPlayback()
            }
        }
        .sheet(isPresented: $showingInputSheet) {
            InputSheet(
                inputText: $inputText,
                onGenerate: generatePodcast
            )
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(LinearColors.textSecondary)
            }
            
            Spacer()
            
            Text("Polaroid")
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.primaryText)
            
            Spacer()
            
            // Add notebook button (pencil on notebook icon)
            Button(action: {
                showingInputSheet = true
            }) {
                Image(systemName: "square.and.pencil")
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
    }
    
    private func initialStateView(geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Simple Polaroid with clean animation
                    SimplePolaroid()
                    
                    // Text labels below polaroid area
                    VStack(spacing: 8) {
                        Text(getCurrentWeekText())
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(LinearColors.textSecondary)
                            .textCase(.lowercase)
                        
                        Text(getPodcastTitle())
                            .font(.system(size: 22, weight: .medium, design: .default))
                            .foregroundColor(LinearColors.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Play button for podcast generation
                    ClickyButton(
                        text: viewModel.isProcessing ? "Generating..." : "Play",
                        isDisabled: viewModel.isProcessing || inputText.isEmpty
                    ) {
                        generatePodcast()
                    }
                    .frame(width: min(geometry.size.width * 0.7, 250))
                }
                
                Spacer()
            }
        }
    }
    
    private func playingStateView(geometry: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: geometry.size.height * 0.15)
                
                // Large polaroid at top
                PolaroidFrame(geometry: geometry, isPlaying: true)
                
                Spacer()
            }
            
            // Floating controls card positioned below polaroid
            VStack {
                Spacer()
                
                // Controls as floating card
                PolaroidPlayingControls(
                    viewModel: viewModel,
                    geometry: geometry,
                    onStop: stopPlayback
                )
                .padding(.horizontal, 24)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + 40, 60))
            }
        }
    }
    
    private func generatePodcast() {
        let goals = goalsManager.goals // Goals are already strings
        viewModel.generateTranscript(text: inputText, goals: goals)
    }
    
    private func startPlayback() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingControls = true
            isPlaying = true
        }
        
        // Audio playback will be handled by the PolaroidPlayingControls
        // when it appears in the playing state
    }
    
    private func stopPlayback() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingControls = false
            isPlaying = false
        }
    }
    
    // Helper functions for dynamic content
    private func getCurrentWeekText() -> String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        return "week \(weekOfYear)"
    }
    
    private func getPodcastTitle() -> String {
        if !inputText.isEmpty {
            // Try to extract a meaningful title from the input text
            let words = inputText.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
            let meaningfulWords = words.filter { word in
                word.count > 3 && !["this", "that", "with", "have", "been", "were", "they", "them", "from", "what", "when", "where"].contains(word.lowercased())
            }
            
            if meaningfulWords.count >= 2 {
                let title = meaningfulWords.prefix(4).joined(separator: " ")
                return "Your thoughts on \(title.capitalized)"
            }
        }
        
        // Default fallback
        return "Your weekly reflection"
    }
}

// MARK: - Input Sheet
struct InputSheet: View {
    @Binding var inputText: String
    let onGenerate: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("What's on your mind?")
                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                    .foregroundColor(LinearColors.primaryText)
                    .padding(.top)
                
                TextEditor(text: $inputText)
                    .font(.serifBody)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
                    )
                
                ClickyButton(
                    text: "Generate Podcast",
                    isDisabled: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    onGenerate()
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .background(LinearColors.backgroundGrey.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(LinearColors.accent)
                }
            }
        }
    }
}

#Preview {
    PolaroidHomeView(devMode: true)
}
