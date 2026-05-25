//
//  IntegrationsSetupPage.swift
//  Retrospect
//
//  Full-screen integrations setup page. Shows all 3 data sources as
//  tappable cards. Tapping each triggers its native permission flow.
//  Continue is always available -- integrations are optional.
//

import SwiftUI

struct IntegrationsSetupPage: View {
    @ObservedObject var state: OnboardingState

    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false

    @State private var isConnectingGoogle = false
    @State private var isRequestingHealth = false
    @State private var isConnectingScreenTime = false
    @State private var connectionError: String?

    @State private var contentOpacity: Double = 0

    var body: some View {
        OnboardingScaffold(
            iconName: "link",
            title: "Connect your sources",
            subtitle: "Pick what matters to you. You can skip anything now and add more later in Settings."
        ) {
            VStack(spacing: 12) {
                integrationCard(
                    icon: "doc.text.fill",
                    title: "Google Docs",
                    subtitle: "Notes and documents you want Retrospect to understand.",
                    connected: googleDocsService.isConnected,
                    loading: isConnectingGoogle,
                    action: connectGoogle
                )
                integrationCard(
                    icon: "heart.fill",
                    title: "Apple Health",
                    subtitle: "Sleep, activity, and mindfulness patterns.",
                    connected: healthKitEnabled,
                    loading: isRequestingHealth,
                    action: connectHealth
                )
                integrationCard(
                    icon: "chart.bar.fill",
                    title: "Screen Time",
                    subtitle: "App usage patterns that can add context.",
                    connected: screenTimeService.isAuthorized,
                    loading: isConnectingScreenTime,
                    action: connectScreenTime
                )

                if let error = connectionError {
                    Text(error)
                        .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
                        .foregroundColor(OnboardingStyle.danger)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .opacity(contentOpacity)
        } bottom: {
            OnboardingPrimaryButton(title: "Continue", action: advance)

            Button("Skip for now") {
                advance()
            }
            .font(OnboardingStyle.bodyFont(size: 14))
            .foregroundColor(OnboardingStyle.tertiaryText)
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
        }
        .alert("Connection Error", isPresented: Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )) {
            Button("OK") { connectionError = nil }
        } message: {
            if let err = connectionError { Text(err) }
        }
    }

    // MARK: - Card

    private func integrationCard(
        icon: String,
        title: String,
        subtitle: String,
        connected: Bool,
        loading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        OnboardingOptionRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            status: connected ? "Connected" : nil,
            isSelected: connected,
            isLoading: loading,
            isDisabled: connected,
            action: action
        )
    }

    // MARK: - Actions

    private func advance() {
        HapticManager.shared.playMediumImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            state.markIntegrationsCompleted()
        }
    }

    private func connectGoogle() {
        isConnectingGoogle = true
        connectionError = nil
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    isConnectingGoogle = false
                    HapticManager.shared.playSuccessNotification()
                }
            } catch {
                await MainActor.run {
                    isConnectingGoogle = false
                    connectionError = "Failed to connect Google Docs. Try again."
                }
            }
        }
    }

    private func connectHealth() {
        isRequestingHealth = true
        connectionError = nil
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                isRequestingHealth = false
                if success {
                    healthKitEnabled = true
                    HapticManager.shared.playSuccessNotification()
                }
            }
        }
    }

    private func connectScreenTime() {
        isConnectingScreenTime = true
        connectionError = nil
        Task {
            await screenTimeService.requestAuthorization()
            await MainActor.run {
                isConnectingScreenTime = false
                if screenTimeService.isAuthorized {
                    HapticManager.shared.playSuccessNotification()
                    screenTimeService.startRetroactiveBackfill()
                }
            }
        }
    }
}
