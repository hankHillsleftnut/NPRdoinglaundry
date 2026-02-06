//
//  PodcastFlowPreview.swift
//  Retrospect
//
//  Dev tool to preview the complete podcast flow UI without API calls
//

import SwiftUI

enum PodcastFlowStage: Int, CaseIterable {
    case generating = 0
    case notification = 1
    case player = 2
    case miniPlayer = 3
    
    var title: String {
        switch self {
        case .generating: return "Stage 1: Generating"
        case .notification: return "Stage 2: New Podcast Notification"
        case .player: return "Stage 3: Full Player"
        case .miniPlayer: return "Stage 4: Mini Player"
        }
    }
}

struct PodcastFlowPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStage: PodcastFlowStage = .generating
    @State private var showMiniPlayer = false
    
    // Mock transcript for preview
    private let mockTranscript = TranscriptModel(
        id: UUID(),
        originalText: "Sample journal content for preview purposes.",
        goals: ["Find balance", "Reduce stress", "Be more present"],
        processedTranscript: "Weekly Reflection: Finding Balance\n\nThis week has been about discovering what truly matters...",
        audioFileURL: nil,
        mood: "reflective"
    )
    
    var body: some View {
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Stage indicator
                stageIndicator
                    .padding(.top, 16)
                
                // Content based on stage
                stageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                navigationButtons
                    .padding(.bottom, 32)
            }
            
            // Mini player overlay for stage 4
            if currentStage == .miniPlayer && showMiniPlayer {
                VStack {
                    Spacer()
                    mockMiniPlayer
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: currentStage) { _, newStage in
            if newStage == .miniPlayer {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMiniPlayer = true
                }
            } else {
                showMiniPlayer = false
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(LinearColors.Minimal.backgroundCard)
                            )
                    }
                    
                    Spacer()
                    
                    Text("Podcast Flow Preview")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Spacer()
                    
                    // Spacer for balance
            Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
    }
    
    // MARK: - Stage Indicator
                
    private var stageIndicator: some View {
        VStack(spacing: 8) {
            // Progress dots
                HStack(spacing: 8) {
                    ForEach(PodcastFlowStage.allCases, id: \.rawValue) { stage in
                        Circle()
                        .fill(stage.rawValue <= currentStage.rawValue ? LinearColors.Minimal.accent : LinearColors.Minimal.backgroundCard)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(currentStage.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
        }
    }
    
    // MARK: - Stage Content
    
    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case .generating:
            generatingStage
        case .notification:
            notificationStage
        case .player:
            playerStage
        case .miniPlayer:
            miniPlayerStage
        }
    }
    
    // Stage 1: Generating
    private var generatingStage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Mock loading pill
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                        .scaleEffect(0.8)
                    
                    Text("Generating your podcast...")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            Capsule()
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
                
            VStack(spacing: 8) {
                Text("Processing your journal entries")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                
                Text("This usually takes 30-60 seconds")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // Stage 2: Notification
    private var notificationStage: some View {
        NewPodcastArrivalView(
            transcript: mockTranscript,
            onPlay: {
                // Move to next stage
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStage = .player
                }
            },
            onDismiss: {}
        )
    }
    
    // Stage 3: Player
    private var playerStage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Mock player UI
            VStack(spacing: 20) {
                // Album art
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 280)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Title
                VStack(spacing: 6) {
                    Text("Weekly Reflection")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Text("Reflective • 5 min")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearColors.Minimal.accent)
                                .frame(width: geometry.size.width * 0.35, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text("1:45")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Spacer()
                        Text("5:00")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                .padding(.horizontal, 40)
                
                // Playback controls
                HStack(spacing: 40) {
                    Button(action: {}) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                    
                    Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "goforward.30")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
            }
            }
            
            Spacer()
        }
            .padding(.horizontal, 20)
    }
    
    // Stage 4: Mini Player context
    private var miniPlayerStage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "hand.point.down.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                
                Text("Mini Player Active")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                Text("The mini player appears at the bottom\nwhile you navigate the app")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            Spacer()
            Spacer()
        }
    }
    
    // Mock mini player
    private var mockMiniPlayer: some View {
            HStack(spacing: 12) {
                // Album art
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    )
                
            // Info
                VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Reflection")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .lineLimit(1)
                    
                Text("1:45 / 5:00")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                }
                    
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Previous
            if currentStage.rawValue > 0 {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if let prev = PodcastFlowStage(rawValue: currentStage.rawValue - 1) {
                            currentStage = prev
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Previous")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                Capsule()
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
        }
    }
    
            // Next / Done
            Button(action: {
                if currentStage.rawValue < PodcastFlowStage.allCases.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let next = PodcastFlowStage(rawValue: currentStage.rawValue + 1) {
                currentStage = next
            }
        }
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 8) {
                    Text(currentStage.rawValue < PodcastFlowStage.allCases.count - 1 ? "Next" : "Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    if currentStage.rawValue < PodcastFlowStage.allCases.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearColors.Minimal.accent)
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    PodcastFlowPreview()
}
