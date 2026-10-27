import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget (minimal, non-intrusive)

@available(iOS 16.2, *)
struct VoiceRecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceRecordingAttributes.self) { context in
            VoiceRecordingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.accent)
                        Text("Recording")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.recordingDuration))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: URL(string: "retrospect://stop-recording")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Stop")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(LinearColors.Minimal.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.accent)
            } compactTrailing: {
                Text(formatTime(context.state.recordingDuration))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.accent)
            }
            .keylineTint(LinearColors.Minimal.accent)
        }
    }
}

// MARK: - Lock Screen View (simple one line + Stop)

@available(iOS 16.2, *)
struct VoiceRecordingLockScreenView: View {
    let context: ActivityViewContext<VoiceRecordingAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(LinearColors.Minimal.accent)

            Text("Recording · \(formatTime(context.state.recordingDuration))")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .monospacedDigit()

            Spacer()

            Link(destination: URL(string: "retrospect://stop-recording")!) {
                Text("Stop")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.accent.opacity(0.2))
                    )
            }
        }
        .padding(16)
        .activityBackgroundTint(LinearColors.Minimal.backgroundCard)
        .activitySystemActionForegroundColor(LinearColors.Minimal.accent)
    }
}

// MARK: - Helper

private func formatTime(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
