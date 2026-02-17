//
//  DarkEntryDetailView.swift
//  Retrospect
//
//  Full entry detail view in dark UI
//  Supports voice playback for voice entries
//

import SwiftUI
import AVFoundation

struct DarkEntryDetailView: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.Minimal.textTertiary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            // Type badge
                            HStack(spacing: 4) {
                                Image(systemName: entry.type == .voice ? "waveform" : "doc.text")
                                    .font(.system(size: 12, weight: .medium))
                                Text(entry.type == .voice ? "Voice" : "Written")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(entry.type == .voice ? LinearColors.Minimal.accent : LinearColors.Minimal.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(entry.type == .voice ? LinearColors.Minimal.accentSubtle : LinearColors.Minimal.backgroundCard)
                            )
                            
                            Text(formatDate(entry.date))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Voice player (if voice entry)
                if entry.type == .voice, entry.audioURL != nil {
                    voicePlayer
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
                
                // Content
                ScrollView {
                    Text(entry.content)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            timer?.invalidate()
            audioPlayer?.stop()
        }
    }
    
    private var voicePlayer: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearColors.Minimal.progressTrack)
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearColors.Minimal.accent)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            
            HStack {
                // Time
                Text(formatTime(currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                
                Spacer()
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(LinearColors.Minimal.accent)
                        )
                }
                
                Spacer()
                
                // Duration
                Text(formatTime(duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
    
    private func setupAudioPlayer() {
        guard let audioURL = entry.audioURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = audioPlayer?.currentTime ?? 0
                
                // Auto-stop at end
                if let player = audioPlayer, !player.isPlaying && currentTime > 0 && currentTime >= duration - 0.1 {
                    isPlaying = false
                }
            }
            RunLoop.current.add(timer!, forMode: .common)
        } catch {
            print("Failed to setup audio player: \(error.localizedDescription)")
        }
    }
    
    private func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        HapticManager.shared.playMediumImpact()
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    DarkEntryDetailView(
        entry: Entry(
            type: .text,
            content: "This is a sample journal entry with some thoughtful content about the day's events and reflections...",
            aiGeneratedTitle: "Sample Entry"
        )
    )
}

