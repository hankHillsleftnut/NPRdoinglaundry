import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget
@available(iOS 16.2, *)
struct VoiceRecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceRecordingAttributes.self) { context in
            // Lock Screen / Banner UI
            VoiceRecordingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when user long-presses)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.recordingActive)
                            .symbolEffect(.variableColor.iterative.reversing, isActive: context.state.isRecording)
                        
                        Text("Recording")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.recordingDuration))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .monospacedDigit()
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 16) {
                        // Animated Waveform
                        HStack(spacing: 3) {
                            ForEach(0..<25, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [LinearColors.Minimal.accent.opacity(0.8), LinearColors.Minimal.accentLight.opacity(0.6)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    ))
                                    .frame(width: 4)
                                    .frame(height: waveformHeight(for: index, isRecording: context.state.isRecording))
                                    .animation(
                                        .easeInOut(duration: Double.random(in: 0.3...0.6))
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.05),
                                        value: context.state.isRecording
                                    )
                            }
                        }
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        
                        // Stop Button
                        Link(destination: URL(string: "retrospect://stop-recording")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Stop Recording")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(LinearColors.Minimal.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                // Compact Leading (Left pill)
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.accent)
                    .symbolEffect(.variableColor.iterative.reversing, isActive: context.state.isRecording)
            } compactTrailing: {
                // Compact Trailing (Right pill)
                Text(formatTime(context.state.recordingDuration))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .monospacedDigit()
            } minimal: {
                // Minimal (When multiple activities)
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.accent)
            }
            .keylineTint(LinearColors.Minimal.accent)
        }
    }
    
    private func waveformHeight(for index: Int, isRecording: Bool) -> CGFloat {
        if !isRecording {
            return 8
        }
        
        let baseHeight: CGFloat = 12
        let maxHeight: CGFloat = 50
        
        // Create varied heights for visual interest
        let pattern = [0.4, 0.7, 1.0, 0.6, 0.9, 0.5, 0.8, 0.3, 0.95, 0.45]
        let multiplier = pattern[index % pattern.count]
        
        return baseHeight + (maxHeight - baseHeight) * multiplier
    }
}

// MARK: - Lock Screen View
@available(iOS 16.2, *)
struct VoiceRecordingLockScreenView: View {
    let context: ActivityViewContext<VoiceRecordingAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Animated Waveform
            HStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [LinearColors.Minimal.accent, LinearColors.Minimal.accentLight],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 3)
                        .frame(height: waveformHeight(for: index, isRecording: context.state.isRecording))
                        .animation(
                            .easeInOut(duration: Double.random(in: 0.4...0.7))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                            value: context.state.isRecording
                        )
                }
            }
            .frame(height: 40)
            
            Spacer()
            
            // Timer
            Text(formatTime(context.state.recordingDuration))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .monospacedDigit()
            
            Spacer()
            
            // Stop Button
            Link(destination: URL(string: "retrospect://stop-recording")!) {
                ZStack {
                    Circle()
                        .fill(LinearColors.Minimal.backgroundCard)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .strokeBorder(LinearColors.Minimal.accent, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearColors.Minimal.accent)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(LinearColors.Minimal.backgroundCard)
        .activitySystemActionForegroundColor(LinearColors.Minimal.accent)
    }
    
    private func waveformHeight(for index: Int, isRecording: Bool) -> CGFloat {
        if !isRecording {
            return 6
        }
        
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 40
        
        let pattern = [0.5, 0.8, 1.0, 0.7, 0.9, 0.6, 0.85, 0.4, 0.95, 0.55, 0.75, 0.65]
        let multiplier = pattern[index % pattern.count]
        
        return baseHeight + (maxHeight - baseHeight) * multiplier
    }
}

// MARK: - Helper Functions
private func formatTime(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

