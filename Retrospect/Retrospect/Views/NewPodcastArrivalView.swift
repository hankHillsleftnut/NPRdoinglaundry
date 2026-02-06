//
//  NewPodcastArrivalView.swift
//  Retrospect
//
//  The view shown when a user receives a new podcast notification
//  Features album art, episode title, and a big play button
//

import SwiftUI

struct NewPodcastArrivalView: View {
    let transcript: TranscriptModel
    let onPlay: () -> Void
    let onDismiss: () -> Void
    
    @State private var isAppearing = false
    @State private var playButtonPressed = false
    
    // Derive title from content or use default
    private var episodeTitle: String {
        // Try to extract from processedTranscript first line
        if let processed = transcript.processedTranscript,
           let firstLine = processed.split(separator: "\n").first {
            let title = String(firstLine).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && title.count < 50 {
                return title
            }
        }
        
        // Generate title from mood if available
        if let mood = transcript.mood {
            return "Weekly Reflection: \(mood)"
        }
        
        // Default title
        return "Weekly Reflection"
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with "New episode" and dismiss
                HStack {
                    Text("New episode")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Centered content
                VStack(spacing: 32) {
                    // Album art placeholder (will be Polaroid eventually)
                    albumArtView
                        .scaleEffect(isAppearing ? 1 : 0.8)
                        .opacity(isAppearing ? 1 : 0)
                    
                    // Episode title
                    VStack(spacing: 8) {
                        Text(episodeTitle)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(formatDate(transcript.createdAt))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 20)
                    
                    // Big play button
                    playButton
                        .scaleEffect(isAppearing ? 1 : 0.9)
                        .opacity(isAppearing ? 1 : 0)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAppearing = true
            }
        }
    }
    
    // MARK: - Album Art
    
    private var albumArtView: some View {
        ZStack {
            // Polaroid-style frame (placeholder for now)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 260, height: 300)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 0) {
                // Album art area
                ZStack {
                    // Gradient background for album art
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.2),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Waveform visualization
                    HStack(spacing: 4) {
                        ForEach(0..<20, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 6, height: CGFloat.random(in: 20...80))
                        }
                    }
                    
                    // Episode number overlay
                    VStack {
                        Spacer()
                        HStack {
                            Text("EP \(episodeNumber)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(12)
                    }
                }
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Polaroid bottom area
                Spacer()
            }
            .frame(width: 260, height: 300)
            .padding(.top, 10)
        }
    }
    
    // MARK: - Play Button
    
    private var playButton: some View {
        Button(action: {
            playButtonPressed = true
            HapticManager.shared.playMediumImpact()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                playButtonPressed = false
                onPlay()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Play")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
            }
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .padding(.horizontal, 48)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    // 1. Base fill
                    Capsule()
                        .fill(LinearColors.Minimal.inputBackground)
                    
                    // 2. Inner stroke (4pt)
                    Capsule()
                        .strokeBorder(
                            Color.white.opacity(0.10),
                            lineWidth: 4
                        )
                        .padding(1)
                    
                    // 3. Inner shadow overlay
                    Capsule()
                        .stroke(Color.black.opacity(0.3), lineWidth: 6)
                        .blur(radius: 3)
                        .offset(y: 2)
                        .mask(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black, Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .padding(1)
                    
                    // 4. Outer stroke - gradient frame
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
            )
            .scaleEffect(playButtonPressed ? 0.96 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helpers
    
    private var episodeNumber: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        return String(format: "%02d", weekOfYear)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

struct NewPodcastArrivalView_Previews: PreviewProvider {
    static var previews: some View {
        NewPodcastArrivalView(
            transcript: TranscriptModel.sample,
            onPlay: {},
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}

