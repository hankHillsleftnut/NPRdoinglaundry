//
//  IntegrationsSetupPage.swift
//  Retrospect
//
//  Full-screen integrations setup page. Shows the complete source catalog and
//  connects every source that currently has a production collection path.
//  Continue is always available -- integrations are optional.
//

import SwiftUI
import UniformTypeIdentifiers

struct IntegrationsSetupPage: View {
    @ObservedObject var state: OnboardingState

    @StateObject private var screenTimeService = ScreenTimeService.shared
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("integration.calendar.connected") private var calendarConnected = false
    @AppStorage("integration.appleMusic.connected") private var appleMusicConnected = false
    @AppStorage("integration.photos.connected") private var photosConnected = false
    @AppStorage("integration.contacts.connected") private var contactsConnected = false

    @State private var connectingSourceId: String?
    @State private var connectionError: String?
    @State private var selectedPlannedSource: IntegrationCatalogItem?
    @State private var importSource: IntegrationCatalogItem?
    @State private var showingFileImporter = false
    @State private var remoteConnectionStatus: [String: String] = [:]
    @Environment(\.openURL) private var openURL

    @State private var contentOpacity: Double = 0

    var body: some View {
        OnboardingScaffold(
            iconName: "sparkles",
            title: state.userName.isEmpty
                ? "Here's what would help me know you best."
                : "\(state.userName), here's what would help me know you best.",
            subtitle: "These tell me what words can't. Connect what feels right — each one makes your first podcast sharper."
        ) {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(IntegrationCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.rawValue.uppercased())
                            .font(OnboardingStyle.bodyFont(size: 12, weight: .semibold))
                            .foregroundColor(OnboardingStyle.tertiaryText)

                        ForEach(IntegrationCatalogItem.all.filter { $0.category == category }) { source in
                            integrationCard(source)
                        }
                    }
                }

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
            OnboardingPrimaryButton(title: "Make my podcast", action: advance)

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
        .task { await loadConnectionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: .integrationConnectionChanged)) { notification in
            if let status = notification.userInfo?["status"] as? String, status == "error" {
                connectionError = "The integration could not be connected. Please try again."
            }
            Task { await loadConnectionStatus() }
        }
        .alert("Connection Error", isPresented: Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )) {
            Button("OK") { connectionError = nil }
        } message: {
            if let err = connectionError { Text(err) }
        }
        .alert(item: $selectedPlannedSource) { source in
            Alert(
                title: Text(source.title),
                message: Text("\(source.subtitle)\n\n\(source.plannedStatus ?? "Connection is being built"). This source is visible now so it can be connected here as soon as its verified collection path is ready."),
                dismissButton: .default(Text("Got it"))
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .zip, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            guard let source = importSource else { return }
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                connectingSourceId = source.id
                Task {
                    do {
                        try await RetrospectAPIClient.shared.importIntegrationArchive(providerId: source.id, fileURL: url)
                        await loadConnectionStatus()
                        connectingSourceId = nil
                        HapticManager.shared.playSuccessNotification()
                    } catch {
                        connectingSourceId = nil
                        connectionError = error.localizedDescription
                    }
                }
            case .failure(let error):
                connectionError = error.localizedDescription
            }
        }
    }

    // MARK: - Card

    private func integrationCard(_ source: IntegrationCatalogItem) -> some View {
        let connected = isConnected(source)
        return OnboardingOptionRow(
            icon: source.icon,
            title: source.title,
            subtitle: source.subtitle,
            status: connectionStatusLabel(source, connected: connected),
            isSelected: connected,
            isLoading: connectingSourceId == source.id,
            isDisabled: connected,
            action: { connect(source) }
        )
    }

    private func isConnected(_ source: IntegrationCatalogItem) -> Bool {
        if remoteConnectionStatus[source.id] == "connected" {
            return true
        }
        switch source.connectionKind {
        case .healthKit: return healthKitEnabled
        case .screenTime: return screenTimeService.isAuthorized
        case .googleDocs: return false
        case .calendar: return calendarConnected
        case .appleMusic: return appleMusicConnected
        case .photos: return photosConnected
        case .contacts: return contactsConnected
        case .oauth, .archiveImport: return false
        case .planned: return false
        }
    }

    private func connectionStatusLabel(_ source: IntegrationCatalogItem, connected: Bool) -> String? {
        if connected { return "Verified and connected" }
        switch remoteConnectionStatus[source.id] {
        case "action_required": return "First sync queued"
        case "expired": return "Reconnect required"
        case "error": return "Sync needs attention"
        case "disconnected": return "Disconnected"
        default: return source.plannedStatus
        }
    }

    private func loadConnectionStatus() async {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        do {
            let integrations = try await RetrospectAPIClient.shared.fetchIntegrations()
            remoteConnectionStatus = Dictionary(
                uniqueKeysWithValues: integrations.compactMap { item in
                    item.connection.map { (item.id, $0.status) }
                }
            )
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private func connect(_ source: IntegrationCatalogItem) {
        connectionError = nil
        switch source.connectionKind {
        case .healthKit: connectHealth()
        case .screenTime: connectScreenTime()
        case .googleDocs: connectOAuth(source)
        case .calendar, .appleMusic, .photos, .contacts: connectNative(source)
        case .oauth: connectOAuth(source)
        case .archiveImport:
            importSource = source
            showingFileImporter = true
        case .planned: selectedPlannedSource = source
        }
    }

    // MARK: - Actions

    private func advance() {
        HapticManager.shared.playMediumImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            state.markIntegrationsCompleted()
        }
    }

    private func connectHealth() {
        connectingSourceId = "healthkit"
        connectionError = nil
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                connectingSourceId = nil
                if success {
                    healthKitEnabled = true
                    HapticManager.shared.playSuccessNotification()
                } else {
                    connectionError = "Apple Health access was not granted."
                }
            }
        }
    }

    private func connectScreenTime() {
        connectingSourceId = "screen_time"
        connectionError = nil
        Task {
            await screenTimeService.requestAuthorization()
            await MainActor.run {
                connectingSourceId = nil
                if screenTimeService.isAuthorized {
                    HapticManager.shared.playSuccessNotification()
                    screenTimeService.startRetroactiveBackfill()
                } else {
                    connectionError = "Screen Time access was not granted."
                }
            }
        }
    }

    private func connectNative(_ source: IntegrationCatalogItem) {
        connectingSourceId = source.id
        Task {
            let succeeded: Bool
            switch source.connectionKind {
            case .calendar:
                succeeded = await NativeSourcesManager.shared.syncCalendar()
                calendarConnected = succeeded
            case .appleMusic:
                succeeded = await NativeSourcesManager.shared.syncAppleMusic()
                appleMusicConnected = succeeded
            case .photos:
                succeeded = await NativeSourcesManager.shared.syncPhotos()
                photosConnected = succeeded
            case .contacts:
                succeeded = await NativeSourcesManager.shared.syncContacts()
                contactsConnected = succeeded
            default:
                succeeded = false
            }

            connectingSourceId = nil
            if succeeded {
                HapticManager.shared.playSuccessNotification()
            } else {
                connectionError = "\(source.title) could not be connected or did not return readable data."
            }
        }
    }

    private func connectOAuth(_ source: IntegrationCatalogItem) {
        connectingSourceId = source.id
        Task {
            do {
                let url = try await RetrospectAPIClient.shared.startOAuthConnection(providerId: source.id)
                connectingSourceId = nil
                openURL(url)
            } catch {
                connectingSourceId = nil
                connectionError = error.localizedDescription
            }
        }
    }
}
