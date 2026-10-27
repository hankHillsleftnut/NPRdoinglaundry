import SwiftUI
import AVFoundation

struct PolaroidPlayingControls: View {
    @ObservedObject var viewModel: TranscriptViewModel
    let geometry: GeometryProxy
    let onStop: () -> Void
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    
    // Card corner radius that's concentric to iPhone screen
    private var cardCornerRadius: CGFloat {
        // iPhone 15 Pro Max has ~47px corner radius
        // Scale proportionally to screen size
        return min(geometry.size.width, geometry.size.height) * 0.08
    }
    
    var body: some View {
        // Floating controls card
        VStack(spacing: 20) {
            // Progress indicator
            if duration > 0 {
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.border)
                                .frame(height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.accent)
                                .frame(
                                    width: progressGeometry.size.width * (currentTime / duration),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LinearColors.textSecondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LinearColors.textSecondary)
                    }
                }
                .padding(.horizontal, 32)
            }
            
            // Media controls
            HStack(spacing: 40) {
                // Rewind 15s
                Button(action: rewind15) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(LinearColors.primaryText)
                }
                .disabled(audioPlayer == nil)
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(LinearColors.accent)
                                .shadow(
                                    color: LinearColors.accent.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .scaleEffect(isPlaying ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.1), value: isPlaying)
                
                // Forward 15s
                Button(action: forward15) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(LinearColors.primaryText)
                }
                .disabled(audioPlayer == nil)
            }
            .padding(.bottom, 8)
            
            // Stop button
            Button(action: {
                stopPlayback()
                onStop()
            }) {
                Text("Stop")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LinearColors.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearColors.Minimal.backgroundCard)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopPlayback()
        }
        .onChange(of: viewModel.transcript?.audioFileURL) { _, _ in
            setupAudioPlayer()
        }
    }
    
    // MARK: - Audio Control Methods
    
    private func setupAudioPlayer() {
        guard let audioURL = viewModel.transcript?.audioFileURL else {
            print("❌ No audio URL available")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            
            // Auto-start playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                togglePlayback()
            }
            
            print("✅ Audio player setup complete. Duration: \(duration)s")
        } catch {
            print("❌ Failed to setup audio player: \(error)")
        }
    }
    
    private func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        
        isPlaying.toggle()
    }
    
    private func rewind15() {
        guard let player = audioPlayer else { return }
        let newTime = max(0, player.currentTime - 15)
        player.currentTime = newTime
        currentTime = newTime
    }
    
    private func forward15() {
        guard let player = audioPlayer else { return }
        let newTime = min(duration, player.currentTime + 15)
        player.currentTime = newTime
        currentTime = newTime
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        stopTimer()
        isPlaying = false
        currentTime = 0
    }
    
    private func startTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer else { return }
            currentTime = player.currentTime
            
            // Auto-stop when finished
            if !player.isPlaying && currentTime >= duration - 0.1 {
                isPlaying = false
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    GeometryReader { geometry in
        ZStack {
            LinearColors.backgroundGrey
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                PolaroidPlayingControls(
                    viewModel: TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared),
                    geometry: geometry,
                    onStop: {}
                )
                .frame(height: geometry.size.height * 0.3)
            }
        }
    }
}
