import SwiftUI

// === ADVANCED SETTINGS ===
// Developer, experimental features, and support options

struct AdvancedSettingsView: View {
    @AppStorage("experimentalViewEnabled") private var experimentalViewEnabled: Bool = false
    @AppStorage("devMode") private var devMode: Bool = false
    @State private var showSupportAndData = false
    @State private var showPaywall = false
    @State private var showMinimalHomePreview = false
    @State private var showLegacyUI = false
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

                        Text("Advanced")
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
                        // Experimental Features Section
                        SettingsGroup(title: "Experimental Features") {
                            SettingsToggleRow(
                                title: "Experimental View",
                                subtitle: "New podcast-focused interface",
                                icon: "flask",
                                isOn: $experimentalViewEnabled
                            )

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            SettingsRow(
                                title: "Minimal Home",
                                subtitle: "Preview the dark minimal interface",
                                icon: "moon.fill",
                                showChevron: true
                            ) {
                                showMinimalHomePreview = true
                            }

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            SettingsRow(
                                title: "Legacy UI (UI1)",
                                subtitle: "Original warm cream interface",
                                icon: "clock.arrow.circlepath",
                                showChevron: true
                            ) {
                                showLegacyUI = true
                            }
                        }

                        // Developer Options Section
                        SettingsGroup(title: "Developer Options") {
                            SettingsToggleRow(
                                title: "Dev Mode",
                                subtitle: "UI without API calls",
                                icon: "hammer.fill",
                                isOn: $devMode
                            )
                        }

                        // Support & Services Section
                        SettingsGroup(title: "Support & Services") {
                            SettingsRow(
                                title: "Support & Data",
                                subtitle: "Help, tutorials, and data management",
                                icon: "questionmark.circle.fill",
                                showChevron: true
                            ) {
                                showSupportAndData = true
                            }

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            SettingsRow(
                                title: "Subscription",
                                subtitle: "Manage your Retrospect subscription",
                                icon: "crown.fill",
                                showChevron: true
                            ) {
                                showPaywall = true
                            }
                        }

                        // Logo Section
                        VStack(spacing: 8) {
                            SquircleLogo.small()

                            Text("Retrospect")
                                .geistCaption()
                                .opacity(0.6)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 100)
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSupportAndData) {
            SupportAndDataView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showMinimalHomePreview) {
            MinimalHomeScreen()
        }
        .fullScreenCover(isPresented: $showLegacyUI) {
            LegacyHomeScreen()
        }
    }
}

#Preview {
    AdvancedSettingsView()
}
