//
//  DarkFeaturedPodcastCard.swift
//  Retrospect
//
//  Featured podcast card for the dark journal home screen
//  Shows latest/current podcast with mesh gradient artwork
//

import SwiftUI

struct DarkFeaturedPodcastCard: View {
    let transcript: TranscriptModel
    @ObservedObject var audioManager: DarkAudioManager

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
            audioManager.playPodcast(transcript: transcript)
            audioManager.showFullPlayer = true
        }) {
            HStack(spacing: 16) {
                // Album art with gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: moodColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "waveform")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weekly Insights")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)

                    Text(podcastMood.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)

                    Text(formatDate(transcript.createdAt))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }

                Spacer()

                // Play button
                ZStack {
                    Circle()
                        .fill(LinearColors.Minimal.accent)
                        .frame(width: 48, height: 48)

                    Image(systemName: audioManager.isPlaying && audioManager.currentTranscript?.id == transcript.id ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .offset(x: audioManager.isPlaying && audioManager.currentTranscript?.id == transcript.id ? 0 : 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
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

        DarkFeaturedPodcastCard(
            transcript: TranscriptModel.sample,
            audioManager: DarkAudioManager.shared
        )
        .padding()
    }
}
