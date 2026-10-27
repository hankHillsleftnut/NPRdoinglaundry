import AVFoundation
import SwiftUI

struct VoiceEntryPlayerView: View {
    let audioURL: URL

    @StateObject private var player = AudioPlayer()
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            // Waveform Icon
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(LinearColors.Minimal.iconPurple)
                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                .padding(.top, 20)

            // Time Display
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(LinearColors.textSecondary)

                Spacer()

                Text(formatTime(player.duration))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(LinearColors.textSecondary)
            }

            // Progress Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(LinearColors.cardBorder.opacity(0.3))
                        .frame(height: 4)

                    // Progress Track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [LinearColors.Minimal.iconPurple, LinearColors.Minimal.iconPurple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)

                    // Thumb
                    Circle()
                        .fill(LinearColors.Minimal.iconPurple)
                        .frame(width: 16, height: 16)
                        .shadow(color: LinearColors.Minimal.iconPurple.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: progressWidth(in: geometry.size.width) - 8)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            player.seek(to: progress)
                        }
                )
            }
            .frame(height: 16)

            // Controls
            HStack(spacing: 40) {
                // Rewind 15s
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    player.skip(by: -15)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(LinearColors.textPrimary)
                }

                // Play/Pause
                Button(action: {
                    HapticManager.shared.playMediumImpact()
                    player.togglePlayPause()
                }) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.iconPurple)
                        .symbolEffect(.bounce, value: player.isPlaying)
                }

                // Forward 15s
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    player.skip(by: 15)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(LinearColors.textPrimary)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.Minimal.iconPurple.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.Minimal.iconPurple.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            player.load(url: audioURL)
        }
        .onDisappear {
            player.pause()
        }
        .alert("Playback Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unable to play this audio file.")
        }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard player.duration > 0 else { return 0 }
        return totalWidth * CGFloat(player.currentTime / player.duration)
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Player Manager

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            print("🎵 Audio loaded: \(duration)s")
        } catch {
            print("❌ Failed to load audio: \(error)")
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func seek(to progress: Double) {
        guard let audioPlayer else { return }
        let targetTime = duration * progress
        audioPlayer.currentTime = targetTime
        currentTime = targetTime
    }

    func skip(by seconds: Double) {
        guard let audioPlayer else { return }
        let newTime = min(max(0, audioPlayer.currentTime + seconds), duration)
        audioPlayer.currentTime = newTime
        currentTime = newTime
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = self.audioPlayer?.currentTime ?? 0

                // Auto-stop at end
                if self.currentTime >= self.duration {
                    self.pause()
                    self.seek(to: 0)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
        audioPlayer?.stop()
    }
}

#Preview {
    VoiceEntryPlayerView(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"))
        .padding()
        .background(LinearColors.backgroundGrey)
}
