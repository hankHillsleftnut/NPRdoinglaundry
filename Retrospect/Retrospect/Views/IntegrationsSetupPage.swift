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
        ZStack {
            LinearColors.Minimal.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Connect your sources")
                        .font(.custom("EBGaramond12-Italic", size: 36))
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))

                    Text("Pick what matters to you.\nYou can add more anytime in Settings.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer()
                    .frame(height: 40)

                VStack(spacing: 12) {
                    integrationCard(
                        icon: "doc.text.fill",
                        title: "Google Docs",
                        subtitle: "Your notes and docs",
                        connected: googleDocsService.isConnected,
                        loading: isConnectingGoogle,
                        action: connectGoogle
                    )
                    integrationCard(
                        icon: "heart.fill",
                        title: "Apple Health",
                        subtitle: "Sleep, activity, mindfulness",
                        connected: healthKitEnabled,
                        loading: isRequestingHealth,
                        action: connectHealth
                    )
                    integrationCard(
                        icon: "chart.bar.fill",
                        title: "Screen Time",
                        subtitle: "App usage patterns",
                        connected: screenTimeService.isAuthorized,
                        loading: isConnectingScreenTime,
                        action: connectScreenTime
                    )
                }
                .padding(.horizontal, 28)

                if let error = connectionError {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: advance) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(LinearColors.Minimal.accent)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button("Skip for now") {
                        advance()
                    }
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
        }
        .preferredColorScheme(.dark)
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
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                }

                Spacer()

                if loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textTertiary))
                        .scaleEffect(0.85)
                } else if connected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.success)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                connected ? LinearColors.Minimal.success.opacity(0.3) : LinearColors.Minimal.border.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(loading || connected)
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
