import SwiftUI
import AVFoundation

struct MiniPlayerView: View {
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    let onTap: () -> Void
    
    private var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(LinearColors.accent.opacity(0.3))
                    .frame(width: geometry.size.width)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(LinearColors.accent)
                            .frame(width: geometry.size.width * CGFloat(currentTime / duration))
                    }
            }
            .frame(height: 2)
            
            // Mini player content
            HStack(spacing: 16) {
                // Waveform icon with animation
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearColors.inputBackground)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                        .foregroundColor(LinearColors.accent)
                        .opacity(isPlaying ? 1 : 0.7)
                        .scaleEffect(isPlaying ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPlaying)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Reflection")
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.primaryText)
                    
                    Text("Your Personal Insights")
                        .font(.geistBodyEmphasis).kerning(TypographyKerning.bodyEmphasisKerning)
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                Spacer()
                
                // Play/Pause button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(LinearColors.primaryText)
                }
                .padding(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearColors.background
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
            )
        }
        .contentShape(Rectangle()) // Make entire view tappable
        .onTapGesture {
            onTap()
        }
        .onAppear {
            setupTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func togglePlayPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
} 