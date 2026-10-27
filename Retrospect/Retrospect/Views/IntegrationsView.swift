import SwiftUI
import HealthKit

struct IntegrationsView: View {
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @State private var showGoogleDocsSettings = false
    @State private var showHealthPermissionAlert = false
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @Environment(\.dismiss) private var dismiss
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        ZStack {
            // Background
            LinearColors.backgroundGrey
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(LinearColors.textPrimary)
                        }
                        
                        Text("Integrations")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Document Integration Section
                        SettingsSection(
                            title: "Document Integration",
                            subtitle: "Connect your documents for richer insights",
                            icon: "doc.text.fill"
                        ) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    showGoogleDocsSettings = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            .foregroundColor(LinearColors.accent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Google Docs Connection")
                                                .font(.serifBody)
                                                .foregroundColor(LinearColors.textPrimary)
                                            
                                            Text(googleDocsService.isConnected ? "Connected and syncing" : "Not connected")
                                                .font(.serifLabel)
                                                .foregroundColor(googleDocsService.isConnected ? LinearColors.successGreen : LinearColors.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if googleDocsService.isConnected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(LinearColors.successGreen)
                                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(LinearColors.textSecondary)
                                                .font(.serifLabel)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: BorderRadius.card)
                                            .fill(googleDocsService.isConnected ? LinearColors.successGreen.opacity(0.1) : LinearColors.inputBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: BorderRadius.card)
                                                    .stroke(googleDocsService.isConnected ? LinearColors.successGreen.opacity(0.3) : LinearColors.inputBorder, lineWidth: BorderWidth.standard)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if googleDocsService.isConnected {
                                    Text("Your recent Google Docs are automatically included in reflections for deeper insights")
                                        .font(.serifLabel)
                                        .foregroundColor(LinearColors.textSecondary)
                                        .padding(.horizontal)
                                } else {
                                    Text("Connect to include your documents and writings in AI insights for a more complete life picture")
                                        .font(.serifLabel)
                                        .foregroundColor(LinearColors.textSecondary)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Health Integration Section
                        SettingsSection(
                            title: "Health Integration",
                            subtitle: "Include your wellness data in reflections",
                            icon: "heart.fill"
                        ) {
                            VStack(spacing: 12) {
                                Toggle(isOn: $healthKitEnabled) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "heart.fill")
                                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            .foregroundColor(LinearColors.accent)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Apple Health Integration")
                                                .font(.serifBody)
                                                .foregroundColor(LinearColors.textPrimary)
                                            
                                            Text("Include steps, heart rate, sleep, and mindfulness data")
                                                .font(.serifLabel)
                                                .foregroundColor(LinearColors.textSecondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: LinearColors.accent))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: BorderRadius.card)
                                        .fill(LinearColors.inputBackground)
                                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                                .onChange(of: healthKitEnabled) { _, newValue in
                                    if newValue {
                                        requestHealthKitPermission()
                                    }
                                }
                                
                                if healthKitEnabled {
                                    VStack(spacing: 8) {
                                        Text("Weekly reflections will include your health and wellness data for more comprehensive insights")
                                            .font(.serifLabel)
                                            .foregroundColor(LinearColors.textSecondary)
                                            .padding(.horizontal)
                                        
                                        HStack(spacing: 8) {
                                            HealthDataBadge(icon: "figure.walk", label: "Steps")
                                            HealthDataBadge(icon: "heart.fill", label: "Heart Rate")
                                            HealthDataBadge(icon: "bed.double.fill", label: "Sleep")
                                            HealthDataBadge(icon: "brain.head.profile", label: "Mindfulness")
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        // Future Integrations Section
                        SettingsSection(
                            title: "More Integrations",
                            subtitle: "Additional services coming soon",
                            icon: "plus.circle.fill"
                        ) {
                            VStack(spacing: 12) {
                                ComingSoonIntegration(
                                    icon: "calendar",
                                    title: "Calendar Integration",
                                    description: "Connect your calendar for context-aware reflections"
                                )
                                
                                ComingSoonIntegration(
                                    icon: "location.fill",
                                    title: "Location Services",
                                    description: "Include places visited in your reflection insights"
                                )
                                
                                ComingSoonIntegration(
                                    icon: "music.note",
                                    title: "Music & Podcasts",
                                    description: "Track your listening habits and mood patterns"
                                )
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Check Google Docs authentication status
            Task {
                await googleDocsService.checkAuthenticationStatus()
            }
        }
        .sheet(isPresented: $showGoogleDocsSettings) {
            GoogleDocsSettingsView(isPresented: $showGoogleDocsSettings, googleDocsService: googleDocsService)
        }
        .alert("Health Access Required", isPresented: $showHealthPermissionAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                healthKitEnabled = false
            }
        } message: {
            Text("Please enable Health access in Settings to use this feature.")
        }
    }
    
    // MARK: - Health Kit Methods
    private func requestHealthKitPermission() {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitEnabled = false
            return
        }
        
        // Define the types of data we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Permission granted
                    healthKitEnabled = true
                } else {
                    // Permission denied
                    healthKitEnabled = false
                    showHealthPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct HealthDataBadge: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.serifCaption)
                .foregroundColor(LinearColors.accent)
            
            Text(label)
                .font(.serifCaption)
                .foregroundColor(LinearColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.pill)
                .fill(LinearColors.accent.opacity(0.1))
        )
    }
}

struct ComingSoonIntegration: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.textSecondary.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textSecondary.opacity(0.8))
                
                Text(description)
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.textSecondary.opacity(0.6))
            }
            
            Spacer()
            
            Text("Coming Soon")
                .font(.serifCaption)
                .foregroundColor(LinearColors.accent.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.pill)
                        .fill(LinearColors.accent.opacity(0.1))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(LinearColors.inputBorder.opacity(0.5), lineWidth: BorderWidth.standard)
                )
        )
    }
}

struct IntegrationsView_Previews: PreviewProvider {
    static var previews: some View {
        IntegrationsView()
    }
} 