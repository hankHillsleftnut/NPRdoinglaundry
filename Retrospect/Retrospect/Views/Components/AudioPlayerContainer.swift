import SwiftUI
import AVFoundation

// MARK: - Audio Player State Management
class AudioPlayerState: ObservableObject {
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isShowingAudioPlayer = false
    @Published var isAudioPlaying = false
    
    func playAudio(from url: URL) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isAudioPlaying = true
            isShowingAudioPlayer = true
            
            configureAudioSession()
        } catch {
            print("❌ Error playing audio: \(error)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        isAudioPlaying = false
        isShowingAudioPlayer = false
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
}

// MARK: - Audio Player Container Component
struct AudioPlayerContainer: View {
    @StateObject private var audioState = AudioPlayerState()
    @ObservedObject var viewModel: TranscriptViewModel
    
    var body: some View {
        ZStack {
            // Audio Player Overlay
            if audioState.isShowingAudioPlayer, 
               let transcript = viewModel.transcript?.processedTranscript {
                AudioPlayerView(
                    transcript: transcript,
                    mood: viewModel.transcript?.mood,
                    generationType: viewModel.transcript?.generationType,
                    audioPlayer: $audioState.audioPlayer,
                    isPlaying: $audioState.isAudioPlaying,
                    isExpanded: $audioState.isShowingAudioPlayer
                )
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: audioState.isShowingAudioPlayer)
            }
        }
        .onChange(of: viewModel.transcript?.audioFileURL) { audioURL in
            if let url = audioURL {
                audioState.playAudio(from: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            audioState.isAudioPlaying = false
        }
    }
    
    // Public interface for controlling audio
    func playTranscript() {
        guard let audioURL = viewModel.transcript?.audioFileURL else { return }
        audioState.playAudio(from: audioURL)
    }
    
    func stopPlayback() {
        audioState.stopAudio()
    }
}

// MARK: - Audio Control Button Component
struct AudioControlButton: View {
    @ObservedObject var audioState: AudioPlayerState
    let transcript: TranscriptModel?
    
    var body: some View {
        if let transcript = transcript, transcript.audioFileURL != nil {
            Button(action: {
                if audioState.isAudioPlaying {
                    audioState.stopAudio()
                } else if let url = transcript.audioFileURL {
                    audioState.playAudio(from: url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: audioState.isAudioPlaying ? "pause.fill" : "play.fill")
                        .font(.serifLabel)
                    Text(audioState.isAudioPlaying ? "Pause" : "Play Audio")
                        .font(.serifLabel).fontWeight(.medium)
                }
                .foregroundColor(LinearColors.Minimal.textPrimary)
            }
            .coStarPrimaryButton()
            .animation(.easeInOut(duration: 0.2), value: audioState.isAudioPlaying)
        }
    }
}