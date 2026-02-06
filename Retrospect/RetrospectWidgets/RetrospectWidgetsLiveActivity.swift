import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents


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
                    // Recording indicator pill (matches main app)
                    HStack(spacing: 12) {
                        // Red recording dot (pulsing)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(context.state.isRecording ? 1.0 : 0.3)

                        // Duration counter
                        Text(formatTime(context.state.recordingDuration))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(LinearColors.Minimal.textPrimary)

                        // Animated waveform
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(LinearColors.Minimal.accent)
                                    .frame(width: 3, height: waveformHeight(for: index, time: context.state.recordingDuration))
                                    .animation(
                                        .easeInOut(duration: 0.35)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.08),
                                        value: context.state.recordingDuration
                                    )
                            }
                        }
                        .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.top, 6)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(context.state.recordingDuration))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .monospacedDigit()
                        
                        Text("MIN")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                            .tracking(0.8)
                    }
                    .padding(.top, 6)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Stop Button with Dynamic Island-matching corner radius
                    Link(destination: URL(string: "retrospect://stop-recording")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Stop & Save")
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(0.2)
                        }
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            LinearGradient(
                                colors: [LinearColors.Minimal.accent, LinearColors.Minimal.accentDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
            } compactLeading: {
                // Compact Leading - Recording indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(context.state.isRecording ? 1.0 : 0.3)

                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.accent)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: context.state.isRecording)
                }
            } compactTrailing: {
                // Compact Trailing (Right pill)
                Text(formatTime(context.state.recordingDuration))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .monospacedDigit()
            } minimal: {
                // Minimal (When multiple activities)
                Circle()
                    .fill(LinearColors.Minimal.accent)
                    .frame(width: 10, height: 10)
            }
            .keylineTint(LinearColors.Minimal.accent)
        }
    }
}

// MARK: - Lock Screen View (Matches main app recording indicator)
@available(iOS 16.2, *)
struct VoiceRecordingLockScreenView: View {
    let context: ActivityViewContext<VoiceRecordingAttributes>

    var body: some View {
        VStack(spacing: 20) {
            // Recording indicator pill (top)
            HStack(spacing: 12) {
                // Red recording dot (pulsing)
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(context.state.isRecording ? 1.0 : 0.3)

                // Duration counter
                Text(formatDuration(context.state.recordingDuration))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(LinearColors.Minimal.textPrimary)

                Spacer()

                // Animated waveform
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: 3, height: waveformHeight(for: index, time: context.state.recordingDuration))
                            .animation(
                                .easeInOut(duration: 0.35)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.08),
                                value: context.state.recordingDuration
                            )
                    }
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )

            // Save button (bottom)
            Link(destination: URL(string: "retrospect://stop-recording")!) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Save Recording")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [LinearColors.Minimal.accent, LinearColors.Minimal.accentDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .activityBackgroundTint(LinearColors.Minimal.background)
        .activitySystemActionForegroundColor(LinearColors.Minimal.accent)
    }
}

// MARK: - Helper Functions
private func formatTime(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
    return String(format: "%d:%02d.%d", minutes, seconds, tenths)
}

// Waveform height functions (file-level for ViewBuilder accessibility)
private func waveformHeight(for index: Int, time: TimeInterval) -> CGFloat {
    let heights: [CGFloat] = [8, 14, 20, 14, 8]
    let animatedHeights: [CGFloat] = [14, 20, 10, 20, 14]
    let isAnimating = Int(time) % 2 == 0
    return isAnimating ? animatedHeights[index] : heights[index]
}

private func animatedWaveformHeight(for index: Int, isRecording: Bool, time: TimeInterval) -> CGFloat {
    if !isRecording { return 10 }
    let baseHeight: CGFloat = 14
    let maxHeight: CGFloat = 56
    let phase = sin(time * 2.5 + Double(index) * 0.25)
    let pattern: [CGFloat] = [0.35, 0.5, 0.7, 0.85, 1.0, 0.9, 0.75, 0.55, 0.65, 0.8, 0.95, 0.8, 0.6, 0.45, 0.7, 0.9, 0.75]
    let baseMultiplier = pattern[index % pattern.count]
    let multiplier = baseMultiplier * CGFloat(0.6 + (phase + 1.0) / 2.0 * 0.7)
    return baseHeight + (maxHeight - baseHeight) * multiplier
}

private func compactWaveHeight(for index: Int, time: TimeInterval) -> CGFloat {
    let baseHeight: CGFloat = 6
    let maxHeight: CGFloat = 20
    let phase = sin(time * 3.0 + Double(index) * 0.4)
    let pattern: [CGFloat] = [0.4, 0.7, 1.0, 0.8, 0.6, 0.9, 0.75, 0.5]
    let baseMultiplier = pattern[index % pattern.count]
    let multiplier = baseMultiplier * CGFloat(0.5 + (phase + 1.0) / 2.0 * 0.8)
    return baseHeight + (maxHeight - baseHeight) * multiplier
}
