//
//  BottomMiniPlayer.swift
//  Retrospect
//
//  Created by Assistant on 1/30/25.
//

import SwiftUI
import AVFoundation

struct BottomMiniPlayer: View {
    let transcript: TranscriptModel
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private var progress: Double {
        guard let duration = audioPlayer?.duration, duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private var podcastMood: PodcastMood {
        guard let moodString = transcript.mood else { return .neutral }
        return PodcastMood(rawValue: moodString.lowercased()) ?? .neutral
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: BorderRadius.small)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: podcastMood.colors.prefix(3).map { $0 }),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "waveform")
                        .font(.geistHeadline)
                        .foregroundColor(.white)
                }
                
                // Info and controls
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Insights")
                                .font(.geistBody)
                                .fontWeight(.semibold)
                                .foregroundColor(LinearColors.textPrimary)
                                .lineLimit(1)
                            
                            Text(transcript.generationType?.displayName ?? "Neutral")
                                .font(.geistCaption)
                                .foregroundColor(LinearColors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: Spacing.sm) {
                            // Play/pause button
                            Button(action: togglePlayback) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.geistBody)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(LinearColors.accent)
                                    )
                            }
                            .onTapGesture {
                                // Prevent button tap from triggering the card tap
                            }
                            
                            // Dismiss button
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(LinearColors.textSecondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(LinearColors.cardBackground)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .onTapGesture {
                                // Prevent button tap from triggering the card tap
                            }
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { progressGeometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(LinearColors.accent.opacity(0.15))
                                .frame(height: 2)
                                .cornerRadius(1)
                            
                            Rectangle()
                                .fill(LinearColors.accent)
                                .frame(width: progressGeometry.size.width * progress, height: 2)
                                .cornerRadius(1)
                                .animation(.easeInOut(duration: 0.1), value: progress)
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.cardBackground)
                    .shadow(
                        color: Shadows.cardShadow.color,
                        radius: Shadows.cardShadow.radius,
                        x: Shadows.cardShadow.x,
                        y: Shadows.cardShadow.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, Spacing.containerMargin)
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
    
    // MARK: - Helper Methods
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = audioPlayer?.currentTime ?? 0
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func togglePlayback() {
        if isPlaying {
            HapticManager.shared.playMediumImpact()
            audioPlayer?.pause()
        } else {
            HapticManager.shared.playAudioPlayback()
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
}