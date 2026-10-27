import AVFoundation
import SwiftUI

struct AudioSettingsView: View {
    @AppStorage("backgroundAudioEnabled") private var backgroundAudioEnabled: Bool = true
    @AppStorage("audioTestMode") private var audioTestMode: Bool = false
    @AppStorage("audioQuality") private var audioQuality: String = "high"
    @AppStorage("autoPlayEnabled") private var autoPlayEnabled: Bool = true
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @Environment(\.dismiss) private var dismiss

    private let audioQualities = ["low", "medium", "high"]
    private let playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [
                    LinearColors.backgroundLight,
                    LinearColors.background,
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 1.5
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(LinearColors.textPrimary)
                        }

                        Spacer()

                        Text("Audio & Playback")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(LinearColors.background)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

                ScrollView {
                    VStack(spacing: 24) {
                        // Playback Controls Section
                        SettingsGroup(title: "Playback Controls") {
                            SettingsToggleRow(
                                title: "Auto-Play",
                                subtitle: "Start playing reflections automatically",
                                icon: "play.circle.fill",
                                isOn: $autoPlayEnabled
                            )

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            SettingsToggleRow(
                                title: "Background Audio",
                                subtitle: "Continue playing when app is backgrounded",
                                icon: "music.note",
                                isOn: $backgroundAudioEnabled
                            )
                        }

                        // Quality Settings Section
                        SettingsGroup(title: "Quality Settings") {
                            SettingsRow(
                                title: "Audio Quality",
                                subtitle: audioQualityDescription(for: audioQuality)
                            ) {
                                // Quality picker would go here
                            }

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            SettingsToggleRow(
                                title: "Test Mode",
                                subtitle: "Enable for audio testing",
                                icon: "waveform.circle",
                                isOn: $audioTestMode
                            )
                        }

                        // Playback Speed Section
                        SettingsGroup(title: "Playback Speed") {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(LinearColors.accent)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Current Speed")
                                            .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                                            .foregroundColor(LinearColors.textPrimary)

                                        Text("\(String(format: "%.2fx", playbackSpeed))")
                                            .font(.serifCaption)
                                            .foregroundColor(LinearColors.textSecondary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, Spacing.cardPadding)
                                .padding(.vertical, 14)

                                Divider()
                                    .background(LinearColors.cardBorder)
                                    .padding(.horizontal, Spacing.cardPadding)

                                VStack(spacing: 8) {
                                    Slider(value: $playbackSpeed, in: 0.5 ... 2.0, step: 0.25) {
                                        Text("Playback Speed")
                                    } minimumValueLabel: {
                                        Text("0.5x")
                                            .font(.serifCaption)
                                            .foregroundColor(LinearColors.textSecondary)
                                    } maximumValueLabel: {
                                        Text("2.0x")
                                            .font(.serifCaption)
                                            .foregroundColor(LinearColors.textSecondary)
                                    }
                                    .accentColor(LinearColors.accent)
                                }
                                .padding(.horizontal, Spacing.cardPadding)
                                .padding(.bottom, 14)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Helper Methods

    private func audioQualityDescription(for quality: String) -> String {
        switch quality {
        case "low":
            return "Fastest generation, smaller file size"
        case "medium":
            return "Balanced quality and speed"
        case "high":
            return "Best audio quality, slower generation"
        default:
            return ""
        }
    }
}

#Preview {
    AudioSettingsView()
}
