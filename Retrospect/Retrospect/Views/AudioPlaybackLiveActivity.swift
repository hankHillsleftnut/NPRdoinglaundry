import SwiftUI
import ActivityKit
import WidgetKit

struct AudioPlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioPlaybackAttributes.self) { context in
            // Live Activity UI
            HStack(spacing: 16) {
                // Album art / Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [LinearColors.Minimal.accent, LinearColors.Minimal.accentDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "waveform")
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Reflection")
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(LinearColors.Minimal.progressTrack)
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(LinearColors.Minimal.progressFill)
                                .frame(width: geometry.size.width * CGFloat(context.state.currentTime / context.state.duration), height: 3)
                        }
                    }
                    .frame(height: 3)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(context.state.currentTime))
                            .font(.caption2)
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                        
                        Spacer()
                        
                        Text(formatTime(context.state.duration))
                            .font(.caption2)
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                
                // Play/Pause button
                Button {} label: {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                }
            }
            .padding()
            .activityBackgroundTint(LinearColors.Minimal.backgroundCard)
            .activitySystemActionForegroundColor(LinearColors.Minimal.accent)
            
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Weekly Reflection")
                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                    } icon: {
                        Image(systemName: "waveform")
                    }
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(formatTime(context.state.currentTime))
                    } icon: {
                        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.currentTime, total: context.state.duration)
                        .tint(LinearColors.Minimal.progressFill)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Additional controls or information
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundColor(LinearColors.Minimal.accent)
            } compactTrailing: {
                Text(formatTime(context.state.currentTime))
                    .font(.caption2)
                    .foregroundColor(LinearColors.Minimal.textPrimary)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(LinearColors.Minimal.accent)
            }
            .keylineTint(LinearColors.Minimal.accent)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 