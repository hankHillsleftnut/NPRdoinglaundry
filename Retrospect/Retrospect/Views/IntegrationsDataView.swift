import SwiftUI

// === INTEGRATIONS & DATA SETTINGS ===
// Unified view for connected services and data management

struct IntegrationsDataView: View {
    @State private var showGoogleDocsIntegration = false
    @State private var showDataManagement = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [
                    LinearColors.backgroundLight,
                    LinearColors.background
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
                        
                        Text("Integrations & Data")
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
                        // Connected Services Section
                        SettingsGroup(title: "Connected Services") {
                            SettingsRow(
                                title: "Google Docs Integration",
                                subtitle: "Connect and sync with Google Docs",
                                icon: "doc.text.fill",
                                showChevron: true
                            ) {
                                showGoogleDocsIntegration = true
                            }
                            
                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)
                            
                            SettingsRow(
                                title: "HealthKit Integration",
                                subtitle: "Sync health data for deeper insights",
                                icon: "heart.fill",
                                showChevron: true
                            ) {
                                // Navigate to HealthKit settings
                            }
                        }
                        
                        // Data Management Section
                        SettingsGroup(title: "Data Management") {
                            SettingsRow(
                                title: "Data & Storage",
                                subtitle: "Manage your reflections and data",
                                icon: "externaldrive.fill",
                                showChevron: true
                            ) {
                                showDataManagement = true
                            }
                            
                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)
                            
                            SettingsRow(
                                title: "Export Data",
                                subtitle: "Download your reflections and insights",
                                icon: "square.and.arrow.up.fill",
                                showChevron: true
                            ) {
                                // Handle data export
                            }
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Integrations")
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, Spacing.containerMargin)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(
                                    title: "Google Docs Integration",
                                    description: "Connect your Google account to automatically sync reflections with Google Docs. Your data remains private and secure."
                                )
                                
                                Divider()
                                    .background(LinearColors.cardBorder)
                                
                                InfoRow(
                                    title: "HealthKit Integration",
                                    description: "Optionally connect with Apple Health to provide additional context for your reflections, such as sleep patterns and activity levels."
                                )
                                
                                Divider()
                                    .background(LinearColors.cardBorder)
                                
                                InfoRow(
                                    title: "Data Management",
                                    description: "Control how your data is stored, backed up, and managed. Export your reflections anytime to maintain full ownership of your content."
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
        .sheet(isPresented: $showGoogleDocsIntegration) {
            GoogleDocsIntegrationView(isPresented: $showGoogleDocsIntegration)
        }
        .sheet(isPresented: $showDataManagement) {
            DataManagementSection(
                onResetAllData: {
                    // Handle data reset
                },
                goalsManager: GoalsManager.shared
            )
        }
    }
}

#Preview {
    IntegrationsDataView()
}
