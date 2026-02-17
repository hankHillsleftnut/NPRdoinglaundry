//
//  DarkSettingsView.swift
//  Retrospect
//
//  Settings hub in dark UI
//

import SwiftUI
import LocalAuthentication

struct DarkSettingsView: View {
    @State private var showProfilePersonalization = false
    @State private var showAppearance = false
    @State private var showAudioPlayback = false
    @State private var showPrivacySecurity = false
    @State private var showIntegrationsData = false
    @State private var showAdvanced = false
    @State private var showLogoutConfirmation = false
    
    @ObservedObject private var apiClient = RetrospectAPIClient.shared
    @State private var headerOpacity: Double = 0
    
    // Header styling
    private let headerHeight: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.custom("EBGaramond12-Italic", size: 46))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                Spacer()
            }
            .frame(height: headerHeight)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .opacity(headerOpacity)
            
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Account Section
                    HStack {
                        Text("Account")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    GroupedSettingsContainer {
                        GroupedSettingsRow(
                            title: "Profile & Personalization",
                            subtitle: "AI style and preferences",
                            icon: "person.crop.circle.fill",
                            iconColor: LinearColors.Minimal.accent
                        ) {
                            showProfilePersonalization = true
                        }
                    }
                    
                    // MARK: - App Experience Section
                    HStack {
                        Text("App Experience")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    GroupedSettingsContainer {
                        GroupedSettingsRow(
                            title: "Appearance",
                            subtitle: "Theme and display",
                            icon: "paintbrush.fill",
                            iconColor: LinearColors.Minimal.iconPurple
                        ) {
                            showAppearance = true
                        }
                        
                        SettingsDivider()
                        
                        GroupedSettingsRow(
                            title: "Audio & Playback",
                            subtitle: "Sound and voice settings",
                            icon: "speaker.wave.3.fill",
                            iconColor: LinearColors.Minimal.iconBlue
                        ) {
                            showAudioPlayback = true
                        }
                    }
                    
                    // MARK: - Privacy Section
                    HStack {
                        Text("Privacy & Data")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    GroupedSettingsContainer {
                        GroupedSettingsRow(
                            title: "Privacy & Security",
                            subtitle: "Face ID and permissions",
                            icon: "lock.shield.fill",
                            iconColor: LinearColors.Minimal.iconGreen
                        ) {
                            showPrivacySecurity = true
                        }
                        
                        SettingsDivider()
                        
                        GroupedSettingsRow(
                            title: "Integrations & Data",
                            subtitle: "Connected services",
                            icon: "link.circle.fill",
                            iconColor: LinearColors.Minimal.iconOrange
                        ) {
                            showIntegrationsData = true
                        }
                    }
                    
                    // MARK: - Developer Section
                    HStack {
                        Text("Developer")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    GroupedSettingsContainer {
                        GroupedSettingsRow(
                            title: "Advanced",
                            subtitle: "Dev tools and experiments",
                            icon: "wrench.and.screwdriver.fill",
                            iconColor: LinearColors.Minimal.textSecondary
                        ) {
                            showAdvanced = true
                        }
                    }
                    
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Text("Retrospect")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                        
                        Text("Version 1.0")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.placeholderText)
                    }
                    .padding(.top, 32)
                    
                    // Log Out Button (at the very bottom)
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.deleteRed)
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.deleteRedSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.deleteRed.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.3), location: 0.3),
                            .init(color: .black.opacity(0.7), location: 0.6),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)
                    LinearColors.Minimal.pureBlack
                    LinearGradient(colors: [LinearColors.Minimal.pureBlack, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 50)
                }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerOpacity = 1
            }
        }
        .sheet(isPresented: $showProfilePersonalization) {
            DarkProfilePersonalizationView()
        }
        .sheet(isPresented: $showAppearance) {
            DarkAppearanceSettingsView()
        }
        .sheet(isPresented: $showAudioPlayback) {
            DarkAudioSettingsView()
        }
        .sheet(isPresented: $showPrivacySecurity) {
            DarkPrivacyAndSecurityView()
        }
        .sheet(isPresented: $showIntegrationsData) {
            DarkIntegrationsDataView()
        }
        .sheet(isPresented: $showAdvanced) {
            DarkAdvancedSettingsView()
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Log Out", role: .destructive) {
                apiClient.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out? You'll need to sign in again to access your data and podcasts.")
        }
    }
}

// MARK: - Grouped Settings Container
struct GroupedSettingsContainer<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearColors.Minimal.backgroundCardLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Divider
struct SettingsDivider: View {
    var body: some View {
        HStack {
            Spacer()
                .frame(width: 60) // Offset from left (icon width + padding)
            Rectangle()
                .fill(LinearColors.Minimal.border)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Grouped Settings Row
struct GroupedSettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            action()
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Card
struct DarkSettingsCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Dark Settings Sub-Views (Simplified versions)

// MARK: - Podcast Cadence Options
enum PodcastCadence: String, CaseIterable {
    case daily = "Daily"
    case everyOtherDay = "Every Other Day"
    case twiceWeekly = "Twice a Week"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    
    var description: String {
        switch self {
        case .daily: return "Every morning"
        case .everyOtherDay: return "Mon, Wed, Fri, Sun"
        case .twiceWeekly: return "Wednesday & Saturday"
        case .weekly: return "Saturday morning"
        case .biweekly: return "Every other Saturday"
        }
    }
}

struct DarkProfilePersonalizationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("deepResearchMode") private var deepResearchMode: Bool = false
    @AppStorage("podcastCadence") private var podcastCadence: String = PodcastCadence.weekly.rawValue
    
    var body: some View {
        darkSettingsSheet(title: "Profile & Personalization") {
            VStack(spacing: 16) {
                // Name input
                DarkSettingsInputRow(
                    title: "Your Name",
                    placeholder: "Enter your name",
                    text: $userName
                )
                
                // Podcast Cadence
                VStack(alignment: .leading, spacing: 12) {
                    Text("Podcast Cadence")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    
                    Text("How often do you want to receive podcasts?")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                    
                    VStack(spacing: 8) {
                        ForEach(PodcastCadence.allCases, id: \.self) { cadence in
                            DarkCadenceOption(
                                cadence: cadence,
                                isSelected: podcastCadence == cadence.rawValue,
                                onSelect: {
                                    HapticManager.shared.playSelectionChanged()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        podcastCadence = cadence.rawValue
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Deep Research Toggle
                DarkSettingsToggleRow(
                    title: "Deep Research Mode",
                    subtitle: "More thorough analysis of your entries",
                    isOn: $deepResearchMode
                )
            }
        }
    }
}

// MARK: - Cadence Option Row
struct DarkCadenceOption: View {
    let cadence: PodcastCadence
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.border,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(cadence.rawValue)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    
                    Text(cadence.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? LinearColors.Minimal.accentSubtle : LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? LinearColors.Minimal.accent.opacity(0.5) : LinearColors.Minimal.border,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DarkAppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        darkSettingsSheet(title: "Appearance") {
            VStack(spacing: 16) {
                DarkSettingsInfoRow(
                    title: "Theme",
                    value: "Dark (Always)"
                )
                
                DarkSettingsInfoRow(
                    title: "Accent Color",
                    value: "Terra Cotta"
                )
            }
        }
    }
}

struct DarkAudioSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("audioTestMode") private var audioTestMode: Bool = false
    
    var body: some View {
        darkSettingsSheet(title: "Audio & Playback") {
            VStack(spacing: 16) {
                DarkSettingsToggleRow(
                    title: "Audio Test Mode",
                    subtitle: "Truncate audio for testing",
                    isOn: $audioTestMode
                )
            }
        }
    }
}

struct DarkPrivacyAndSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    @State private var showBiometricUnavailableAlert = false
    
    var body: some View {
        darkSettingsSheet(title: "Privacy & Security") {
            VStack(spacing: 16) {
                // Face ID Toggle
                VStack(spacing: 0) {
                    DarkSettingsToggleRow(
                        title: "Face ID",
                        subtitle: "Require Face ID to access app",
                        isOn: $faceIDEnabled
                    )
                    .onChange(of: faceIDEnabled) { _, newValue in
                        if newValue {
                            checkBiometricAvailability()
                        }
                    }
                    
                    if faceIDEnabled {
                        Divider()
                            .background(LinearColors.Minimal.border)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                            
                            Text("Face ID will be required when opening the app")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
                
                // Privacy info
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.success)
                        
                        Text("Your Data is Protected")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                    }
                    
                    Text("All your journal entries and reflections are stored locally on your device. Nothing is sent to external servers without your explicit action.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
            }
        }
        .alert("Face ID Unavailable", isPresented: $showBiometricUnavailableAlert) {
            Button("OK", role: .cancel) {
                faceIDEnabled = false
            }
        } message: {
            Text("Face ID is not available on this device or is not configured. Please set up Face ID in Settings.")
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            showBiometricUnavailableAlert = true
            faceIDEnabled = false
        } else {
            switch context.biometryType {
            case .faceID:
                // Face ID is available
                break
            case .touchID, .none, .opticID:
                showBiometricUnavailableAlert = true
                faceIDEnabled = false
            @unknown default:
                break
            }
        }
    }
}

struct DarkIntegrationsDataView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @State private var isConnectingGoogle = false
    @State private var isConnectingHealth = false
    @State private var isConnectingScreenTime = false
    @State private var showGoogleError = false
    @State private var showHealthError = false
    @State private var healthErrorMessage = ""
    
    var body: some View {
        darkSettingsSheet(title: "Integrations & Data") {
            VStack(spacing: 20) {
                // Google Docs Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.iconBlue)
                        
                        Text("Google Docs")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        Spacer()
                        
                        if googleDocsService.isConnected {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(LinearColors.Minimal.success)
                                Text("Connected")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.success)
                            }
                        }
                    }
                    
                    Text("Include your Google Docs in reflections for richer insights.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    
                    if googleDocsService.isConnected {
                        Button(action: disconnectGoogle) {
                            Text("Disconnect")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearColors.Minimal.error.opacity(0.15))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: connectGoogle) {
                            HStack(spacing: 8) {
                                if isConnectingGoogle {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "link")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Text(isConnectingGoogle ? "Connecting..." : "Connect Account")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearColors.Minimal.accent)
                            )
                        }
                        .disabled(isConnectingGoogle)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
                
                // Apple Health Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.iconPink)
                        
                        Text("Apple Health")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        Spacer()
                        
                        if healthKitEnabled {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(LinearColors.Minimal.success)
                                Text("Enabled")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.success)
                            }
                        }
                    }
                    
                    Text("Include sleep, activity, and mindfulness data in your reflections.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    
                    if healthKitEnabled {
                        Button(action: { healthKitEnabled = false }) {
                            Text("Disable")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearColors.Minimal.error.opacity(0.15))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: connectHealth) {
                            HStack(spacing: 8) {
                                if isConnectingHealth {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Text(isConnectingHealth ? "Requesting..." : "Enable Access")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearColors.Minimal.accent)
                            )
                        }
                        .disabled(isConnectingHealth)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
                
                // Screen Time Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.iconPurple)
                        
                        Text("Screen Time")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        Spacer()
                        
                        if screenTimeService.isAuthorized {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(LinearColors.Minimal.success)
                                Text("Enabled")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.success)
                            }
                        }
                    }
                    
                    Text("Track app usage, pickups, and digital habits to surface patterns in how you spend your time on-screen.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                    
                    if screenTimeService.isAuthorized {
                        // Show latest summary if available
                        if let summary = screenTimeService.latestSummary {
                            HStack(spacing: 16) {
                                VStack(spacing: 2) {
                                    Text("\(summary.totalScreenTimeMinutes / 60)h \(summary.totalScreenTimeMinutes % 60)m")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textPrimary)
                                    Text("Screen Time")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textTertiary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(summary.totalPickups)")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textPrimary)
                                    Text("Pickups")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textTertiary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(summary.appUsage.count)")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textPrimary)
                                    Text("Apps")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textTertiary)
                                }
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearColors.Minimal.backgroundCardHover)
                            )
                        }
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                screenTimeService.syncToBackend()
                                HapticManager.shared.playLightImpact()
                            }) {
                                HStack(spacing: 6) {
                                    if screenTimeService.isSyncing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textPrimary))
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    Text(screenTimeService.isSyncing ? "Syncing..." : "Sync Now")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(LinearColors.Minimal.accent)
                                )
                            }
                            .disabled(screenTimeService.isSyncing)
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                screenTimeService.revokeAuthorization()
                            }) {
                                Text("Disable")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.error)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LinearColors.Minimal.error.opacity(0.12))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        Button(action: {
                            isConnectingScreenTime = true
                            Task {
                                await screenTimeService.requestAuthorization()
                                isConnectingScreenTime = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isConnectingScreenTime {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textPrimary))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Text(isConnectingScreenTime ? "Requesting..." : "Enable Screen Time")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearColors.Minimal.accent)
                            )
                        }
                        .disabled(isConnectingScreenTime)
                        .buttonStyle(PlainButtonStyle())
                        
                        if let error = screenTimeService.authorizationError {
                            Text(error)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.error)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
                
                // Data Management
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                        
                        Text("Data Management")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                    }
                    
                    Text("Your data is stored locally on your device. Export or delete your data at any time.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
            }
        }
        .alert("Connection Error", isPresented: $showGoogleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Failed to connect to Google. Please try again.")
        }
        .alert("Apple Health", isPresented: $showHealthError) {
            Button("Open Health App") {
                // Open the Health app directly
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthErrorMessage)
        }
    }
    
    private func connectGoogle() {
        isConnectingGoogle = true
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    isConnectingGoogle = false
                }
            } catch {
                await MainActor.run {
                    isConnectingGoogle = false
                    showGoogleError = true
                }
            }
        }
    }
    
    private func disconnectGoogle() {
        googleDocsService.signOut()
    }
    
    private func connectHealth() {
        // Check if HealthKit is available (only on physical devices, not simulator)
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            healthErrorMessage = "Health data is not available on this device. HealthKit requires a physical iPhone."
            showHealthError = true
            return
        }
        
        isConnectingHealth = true
        HapticManager.shared.playLightImpact()
        
        print("🏥 DarkSettingsView: Requesting HealthKit authorization...")
        
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                isConnectingHealth = false
                print("🏥 DarkSettingsView: Authorization callback received. Success: \(success)")
                
                if success {
                    healthKitEnabled = true
                    HapticManager.shared.playSuccessNotification()
                    // Show guidance after enabling
                    healthErrorMessage = "Health access requested! If you don't see Retrospect in Health settings yet:\n\n1. Open the Health app\n2. Go to Sharing → Apps\n3. Find Retrospect and enable the data types you want to share"
                    showHealthError = true
                } else {
                    healthErrorMessage = "Unable to request Health access. Please try again or check Settings > Privacy & Security > Health."
                    showHealthError = true
                }
            }
        }
    }
}

struct DarkAdvancedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("mockAPICalls") private var mockAPICalls: Bool = false
    @AppStorage("experimentalViewEnabled") private var experimentalViewEnabled: Bool = false
    @State private var showOnboarding = false
    @State private var onboardingReplayId = 0
    @State private var showLegacyUI = false
    @State private var showPodcastFlowPreview = false
    @State private var isGeneratingTestPodcast = false
    @State private var showNewPodcastArrival = false
    @State private var testTranscript: TranscriptModel?
    @State private var generationError: String?
    @State private var showErrorAlert = false
    @StateObject private var notificationService = PodcastNotificationService.shared
    @StateObject private var entryManager = EntryManager.shared
    @StateObject private var goalsManager = GoalsManager.shared
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    
    var body: some View {
        darkSettingsSheet(title: "Advanced") {
            VStack(spacing: 16) {
                DarkSettingsToggleRow(
                    title: "Dev Mode",
                    subtitle: "Enable developer options",
                    isOn: $devMode
                )
                
                // Mock API Calls - only visible when Dev Mode is on
                if devMode {
                    DarkSettingsToggleRow(
                        title: "Mock API Calls",
                        subtitle: "Use sample data instead of real API calls",
                        isOn: $mockAPICalls
                    )
                    .padding(.leading, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                DarkSettingsToggleRow(
                    title: "Experimental View",
                    subtitle: "New podcast-focused interface",
                    isOn: $experimentalViewEnabled
                )
                
                // Test Notification
                Button(action: testNotification) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Podcast Notification")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Send a test notification with your content")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Spacer()
                        
                        if isGeneratingTestPodcast {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.accent)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isGeneratingTestPodcast)
                
                // Resync Entries to Backend
                if devMode {
                    Button(action: {
                        HapticManager.shared.playMediumImpact()
                        EntryManager.shared.resyncAllEntriesToBackend()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resync Entries to Backend")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                
                                Text("\(entryManager.entries.count) entries will be pushed to Supabase")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.accent)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Create Test Podcast (only when devMode is on)
                if devMode {
                    Button(action: createTestPodcast) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isGeneratingTestPodcast ? "Generating Podcast..." : (mockAPICalls ? "Generate Mock Podcast" : "Generate Real Podcast"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                
                                if isGeneratingTestPodcast {
                                    Text(mockAPICalls ? "Creating sample podcast..." : (viewModel.processingStatus.isEmpty ? "Initializing..." : viewModel.processingStatus))
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.accent)
                                } else {
                                    Text(mockAPICalls ? "Uses sample data (no API calls)" : "Uses \(entryManager.getEntriesForWeek().count) entries • \(goalsManager.goals.count) goals")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if isGeneratingTestPodcast {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: mockAPICalls ? "play.circle.fill" : "sparkles")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.accent)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isGeneratingTestPodcast)
                }
                
                // Replay Onboarding
                Button(action: {
                    onboardingReplayId += 1
                    UserDefaults.standard.set(1, forKey: "onboardingCurrentStep")
                    showOnboarding = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replay Onboarding")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Go through the setup flow again")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Preview Podcast Flow
                Button(action: { showPodcastFlowPreview = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Preview Podcast Flow")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Test the complete podcast UI flow")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.accent)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Legacy UI
                Button(action: { showLegacyUI = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Legacy UI (UI1)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Original warm cream interface")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Podcast Flow Preview
                Button(action: { showPodcastFlowPreview = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Preview Podcast Flow")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Walk through the complete podcast UI")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.accent)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Create Test Podcast - Only visible when Dev Mode is on
                if devMode {
                    Button(action: createTestPodcast) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isGeneratingTestPodcast ? "Generating Podcast..." : (mockAPICalls ? "Generate Mock Podcast" : "Generate Real Podcast"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                
                                if isGeneratingTestPodcast {
                                    Text(mockAPICalls ? "Creating sample podcast..." : (viewModel.processingStatus.isEmpty ? "Initializing..." : viewModel.processingStatus))
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.accent)
                                } else {
                                    Text(mockAPICalls ? "Uses sample data (no API calls)" : "Uses \(entryManager.getEntriesForWeek().count) entries • \(goalsManager.goals.count) goals")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(LinearColors.Minimal.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if isGeneratingTestPodcast {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.accent))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: mockAPICalls ? "play.circle.fill" : "sparkles")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.accent)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isGeneratingTestPodcast)
                }
            }
        }
        .fullScreenCover(isPresented: $showPodcastFlowPreview) {
            PodcastFlowPreview()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            DarkOnboardingFlow(onComplete: {
                showOnboarding = false
            })
            .id(onboardingReplayId)
        }
        .fullScreenCover(isPresented: $showLegacyUI) {
            LegacyHomeScreen()
        }
        .fullScreenCover(isPresented: $showPodcastFlowPreview) {
            PodcastFlowPreview()
        }
        .fullScreenCover(isPresented: $showNewPodcastArrival) {
            if let transcript = testTranscript ?? viewModel.transcript {
                NewPodcastArrivalView(
                    transcript: transcript,
                    onPlay: {
                        showNewPodcastArrival = false
                        // In real implementation, this would start playback
                    },
                    onDismiss: {
                        showNewPodcastArrival = false
                    }
                )
            }
        }
        .onChange(of: viewModel.transcript) { _, newTranscript in
            // When transcript is generated via createTestPodcast, show arrival view
            if isGeneratingTestPodcast && newTranscript != nil {
                testTranscript = newTranscript
                isGeneratingTestPodcast = false
                HapticManager.shared.playSuccessNotification()
                showNewPodcastArrival = true
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newError in
            // Handle generation errors
            if isGeneratingTestPodcast && newError != nil {
                isGeneratingTestPodcast = false
                generationError = newError
                showErrorAlert = true
            }
        }
        .alert("Podcast Generation Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                generationError = nil
            }
        } message: {
            Text(generationError ?? "An unknown error occurred.")
        }
        .onAppear {
            Task {
                await notificationService.requestAuthorization()
            }
        }
    }
    
    private func testNotification() {
        isGeneratingTestPodcast = true
        HapticManager.shared.playLightImpact()
        
        // Generate a personalized hook based on existing entries
        let entries = entryManager.entries
        var cheekyHook = "This week told a story you haven't admitted to yourself yet."
        
        if !entries.isEmpty {
            // Analyze recent entries for personalization - punchy single sentences
            let recentContent = entries.prefix(5).map { $0.content }.joined(separator: " ")
            let lowercased = recentContent.lowercased()
            
            // Look for personal topics - one punchy sentence each
            if lowercased.contains("broke up") || lowercased.contains("breakup") || lowercased.contains("ex ") {
                cheekyHook = "We found the real reason it didn't work out."
            } else if lowercased.contains("stress") || lowercased.contains("anxious") || lowercased.contains("overwhelm") {
                cheekyHook = "The anxiety isn't random—here's where it's coming from."
            } else if lowercased.contains("work") || lowercased.contains("job") || lowercased.contains("boss") {
                cheekyHook = "That thing at work is more about you than them."
            } else if lowercased.contains("relationship") || lowercased.contains("dating") {
                cheekyHook = "That person you keep thinking about? We need to talk."
            } else if lowercased.contains("mom") || lowercased.contains("dad") || lowercased.contains("parent") {
                cheekyHook = "Your parents shaped more than you realize."
            } else if lowercased.contains("friend") {
                cheekyHook = "That friendship might be changing for a reason."
            } else if lowercased.contains("goal") || lowercased.contains("dream") {
                cheekyHook = "That dream you keep postponing? Time to face it."
            } else if lowercased.contains("scared") || lowercased.contains("afraid") || lowercased.contains("fear") {
                cheekyHook = "The fear is pointing exactly where you need to go."
            } else if lowercased.contains("sad") || lowercased.contains("crying") || lowercased.contains("depressed") {
                cheekyHook = "There's a reason you've been feeling this way."
            } else if lowercased.contains("love") {
                cheekyHook = "You're afraid of the thing you want most."
            } else if !recentContent.isEmpty {
                cheekyHook = "We found the pattern you've been ignoring."
            }
        }
        
        // Create a test transcript
        let combinedText = entries.prefix(3).map { $0.content }.joined(separator: "\n\n")
        let testTranscript = TranscriptModel(
            id: UUID(),
            originalText: combinedText.isEmpty ? "This is a test podcast notification." : combinedText,
            goals: GoalsManager.shared.goals,
            processedTranscript: "# Weekly Reflection: What's On Your Mind\n\nThis is a test podcast generated from your journal entries.",
            audioFileURL: nil,
            mood: "Positive",
            generationType: .goodListener,
            googleDocsInfo: nil,
            isDeepResearch: false,
            citations: nil,
            researchQueries: nil,
            createdAt: Date()
        )
        
        self.testTranscript = testTranscript
        
        // Send the notification
        notificationService.sendPodcastNotification(
            cheekyHook: cheekyHook,
            podcastId: testTranscript.id.uuidString
        )
        
        // Show the arrival view after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isGeneratingTestPodcast = false
            showNewPodcastArrival = true
            HapticManager.shared.playSuccessNotification()
        }
    }
    
    private func createTestPodcast() {
        HapticManager.shared.playMediumImpact()
        isGeneratingTestPodcast = true
        generationError = nil
        
        // If Mock API Calls is enabled, use sample data without real API calls
        if mockAPICalls {
            print("🔧 Mock API Calls enabled - using sample data")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let sampleTranscript = TranscriptModel(
                    id: UUID(),
                    originalText: "Sample journal entries for podcast generation.",
                    goals: ["Personal growth", "Work-life balance", "Self-reflection"],
                    processedTranscript: """
                    This week has been quite a journey for you. Looking at everything you've shared, there's a clear pattern emerging—one that speaks to your growth and the challenges you're facing.
                    
                    Let's start with what's been on your mind the most. You've been thinking a lot about balance—between work and personal life, between ambition and contentment. And here's the thing: that tension isn't a bug, it's a feature. It means you care about both sides.
                    
                    What I noticed in your entries is a shift in how you're talking about your goals. Early in the week, there was hesitation. By Thursday, something clicked. You started writing with more certainty, more ownership of your direction.
                    
                    The pattern I want to highlight: every time you wrote about feeling stuck, it was followed within 24 hours by a breakthrough insight. Your brain is working on these problems even when you think you're not making progress.
                    
                    For next week, consider this: what if the uncertainty you're feeling isn't a problem to solve, but information to listen to? Sometimes our discomfort is pointing us exactly where we need to look.
                    
                    Until next time, keep writing. Keep reflecting. The clarity is coming.
                    """,
                    audioFileURL: nil,
                    mood: "reflective",
                    generationType: .goodListener,
                    googleDocsInfo: nil,
                    isDeepResearch: false,
                    citations: nil,
                    researchQueries: nil,
                    createdAt: Date()
                )
                
                self.testTranscript = sampleTranscript
                self.isGeneratingTestPodcast = false
                HapticManager.shared.playSuccessNotification()
                self.showNewPodcastArrival = true
            }
            return
        }
        
        // Real API calls - Get real entries from the past week
        let weekEntries = entryManager.getEntriesForWeek()
        let goals = goalsManager.goals
        
        // Build combined text from entries
        var combinedText = ""
        
        if weekEntries.isEmpty {
            // If no entries, use sample data for testing
            combinedText = """
            Today I've been thinking about my goals and how to make progress on them.
            I feel motivated to improve my habits and build better routines.
            Work has been challenging but I'm learning to manage stress better.
            I want to focus on personal growth and being more present in my daily life.
            """
        } else {
            // Combine all entries from the week
            let sortedEntries = weekEntries.sorted { $0.date < $1.date }
            
            for entry in sortedEntries {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                
                let entryHeader = "[\(dateFormatter.string(from: entry.date)) - \(entry.type.rawValue.capitalized)]"
                combinedText += "\(entryHeader)\n\(entry.content)\n\n"
            }
        }
        
        // Use default goals if none exist
        let finalGoals = goals.isEmpty ? ["Personal growth", "Self-reflection", "Well-being"] : goals
        
        print("🎙️ Settings: Generating podcast with \(weekEntries.count) entries and \(finalGoals.count) goals")
        print("📝 Combined text length: \(combinedText.count) characters")
        
        // Call the actual transcript generation
        viewModel.generateTranscript(text: combinedText, goals: finalGoals)
    }
}

// MARK: - Settings Sheet Template
@ViewBuilder
func darkSettingsSheet(title: String, @ViewBuilder content: () -> some View) -> some View {
    ZStack {
        LinearColors.Minimal.sheetBackground
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearColors.Minimal.textTertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            
            // Header
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 24)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    .preferredColorScheme(.dark)
}

// MARK: - Settings Row Components
struct DarkSettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(LinearColors.Minimal.accent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
}

struct DarkSettingsInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearColors.Minimal.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
}

struct DarkSettingsInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .focused($isFocused)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearColors.Minimal.inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isFocused ? LinearColors.Minimal.borderFocus : LinearColors.Minimal.border,
                                    lineWidth: isFocused ? 2 : 1
                                )
                        )
                )
        }
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        DarkSettingsView()
    }
}


