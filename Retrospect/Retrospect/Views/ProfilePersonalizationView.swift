import SwiftUI

// === PROFILE & PERSONALIZATION SETTINGS ===
// Clean, focused view for AI style and research preferences

struct ProfilePersonalizationView: View {
    @AppStorage("generationType") private var generationTypeRaw: String = GenerationType.goodListener.rawValue
    @AppStorage("deepResearchMode") private var deepResearchMode: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var generationType: GenerationType {
        GenerationType(rawValue: generationTypeRaw) ?? .goodListener
    }

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

                        Text("Profile & Personalization")
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
                        // AI Reflection Style Section
                        SettingsGroup(title: "AI Reflection Style") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    title: "Current Style: \(generationType.displayName)",
                                    subtitle: "Tap to change how AI analyzes your reflections"
                                ) {
                                    // This will show the picker
                                }

                                Divider()
                                    .background(LinearColors.cardBorder)
                                    .padding(.horizontal, Spacing.cardPadding)

                                // Picker embedded in the group
                                AIReflectionStylePicker(selectedType: Binding(
                                    get: { generationType },
                                    set: { generationTypeRaw = $0.rawValue }
                                ))
                                .padding(.horizontal, Spacing.cardPadding)
                                .padding(.vertical, 12)
                            }
                        }

                        // Research Mode Section
                        SettingsGroup(title: "Research Mode") {
                            SettingsToggleRow(
                                title: "Supercharge Mode",
                                subtitle: "Enhanced research for deeper insights",
                                icon: "brain.head.profile",
                                isOn: $deepResearchMode
                            )
                        }

                        // Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About These Settings")
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, Spacing.containerMargin)

                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(
                                    title: "AI Reflection Style",
                                    description: "Choose how the AI analyzes and responds to your reflections. Each style offers a different perspective on your thoughts and experiences."
                                )

                                Divider()
                                    .background(LinearColors.cardBorder)

                                InfoRow(
                                    title: "Supercharge Mode",
                                    description: "When enabled, the AI performs deeper research and analysis, providing more comprehensive insights but taking slightly longer to process."
                                )
                            }
                            .padding(Spacing.cardPadding)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.card)
                                    .fill(LinearColors.cardBackground)
                                    .shadow(
                                        color: Shadows.cardShadow.color,
                                        radius: Shadows.cardShadow.radius,
                                        x: Shadows.cardShadow.x,
                                        y: Shadows.cardShadow.y
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BorderRadius.card)
                                            .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                                    )
                            )
                            .padding(.horizontal, Spacing.containerMargin)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                .foregroundColor(LinearColors.textPrimary)

            Text(description)
                .font(.serifCaption)
                .foregroundColor(LinearColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ProfilePersonalizationView()
}
