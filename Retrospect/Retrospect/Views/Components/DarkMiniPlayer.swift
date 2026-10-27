//
//  DarkMiniPlayer.swift
//  Retrospect
//
//  Compact mini player bar for the dark UI
//  Persists across all tabs when audio is playing
//

import AVFoundation
import SwiftUI

struct DarkMiniPlayer: View {
    @ObservedObject var audioManager: DarkAudioManager

    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?

    private var progress: Double {
        guard let duration = audioManager.audioPlayer?.duration, duration > 0 else { return 0 }
        return currentTime / duration
    }

    private var podcastMood: PodcastMood {
        guard let moodString = audioManager.currentTranscript?.mood else { return .neutral }
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
            HapticManager.shared.playLightImpact()
            audioManager.showFullPlayer = true
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Album art thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: moodColors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Insights")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .lineLimit(1)

                        Text(podcastMood.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 8) {
                        // Play/Pause
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            audioManager.togglePlayback()
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(LinearColors.Minimal.accent)
                                )
                        }

                        // Close
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            audioManager.stopPlayback()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(LinearColors.Minimal.backgroundCard)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(LinearColors.Minimal.progressTrack)
                            .frame(height: 2)

                        Rectangle()
                            .fill(LinearColors.Minimal.progressFill)
                            .frame(width: geometry.size.width * progress, height: 2)
                            .animation(.easeInOut(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 2)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
                    .shadow(
                        color: LinearColors.Minimal.shadowMedium,
                        radius: 12, x: 0, y: 4
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            currentTime = audioManager.audioPlayer?.currentTime ?? 0
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            DarkMiniPlayer(audioManager: DarkAudioManager.shared)
                .padding()
        }
    }
}
