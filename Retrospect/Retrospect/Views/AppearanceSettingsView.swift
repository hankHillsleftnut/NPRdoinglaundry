import SwiftUI

// === APPEARANCE SETTINGS ===
// Clean view for theme and interface options

struct AppearanceSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showPolaroidView = false
    @Environment(\.dismiss) private var dismiss

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

                        Text("Appearance")
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
                        // Theme Section
                        SettingsGroup(title: "Theme") {
                            SettingsToggleRow(
                                title: "Dark Mode",
                                subtitle: "Charcoal grey theme with terra-cotta accents",
                                icon: themeManager.themeIcon,
                                isOn: $themeManager.isDarkMode
                            )
                        }

                        // Typography Section
                        SettingsGroup(title: "Typography") {
                            FontPreviewTile()
                        }

                        // Interface Options Section
                        SettingsGroup(title: "Interface Options") {
                            SettingsRow(
                                title: "Polaroid View",
                                subtitle: "Alternative podcast interface with vintage styling",
                                icon: "photo.fill",
                                showChevron: true
                            ) {
                                showPolaroidView = true
                            }
                        }

                        // Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Appearance")
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, Spacing.containerMargin)

                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(
                                    title: "Dark Mode",
                                    description: "Switch between the warm terra-cotta cream theme and sophisticated charcoal grey dark theme. Changes apply instantly with smooth animations."
                                )

                                Divider()
                                    .background(LinearColors.cardBorder)

                                InfoRow(
                                    title: "Polaroid View",
                                    description: "Experience your podcasts with a vintage polaroid-inspired interface. Perfect for a more nostalgic and focused listening experience."
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
        .fullScreenCover(isPresented: $showPolaroidView) {
            PolaroidHomeView(devMode: false)
        }
    }
}

#Preview {
    AppearanceSettingsView()
}
