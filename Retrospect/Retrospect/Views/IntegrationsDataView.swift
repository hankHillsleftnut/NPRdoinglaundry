import SwiftUI
import UniformTypeIdentifiers

/// The operational integration surface. Connection state comes from the
/// backend after a verified sync; local permission state is shown as pending
/// until the worker has processed the first device batch.
struct IntegrationsDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var screenTimeService = ScreenTimeService.shared

    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("integration.calendar.connected") private var calendarConnected = false
    @AppStorage("integration.appleMusic.connected") private var appleMusicConnected = false
    @AppStorage("integration.photos.connected") private var photosConnected = false
    @AppStorage("integration.contacts.connected") private var contactsConnected = false

    @State private var remoteByProvider: [String: BackendIntegrationCatalogItem] = [:]
    @State private var busyProviderId: String?
    @State private var errorMessage: String?
    @State private var importSource: IntegrationCatalogItem?
    @State private var showingFileImporter = false
    @State private var deletionTarget: BackendIntegrationConnection?

    var body: some View {
        ZStack {
            FigmaLightTheme.cardSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        summary

                        ForEach(IntegrationCategory.allCases) { category in
                            let sources = IntegrationCatalogItem.all.filter { $0.category == category }

                            VStack(alignment: .leading, spacing: 8) {
                                FigmaLightSectionLabel(text: category.rawValue.uppercased())
                                    .padding(.horizontal, 4)

                                FigmaLightRowCard {
                                    VStack(spacing: 0) {
                                        ForEach(sources) { source in
                                            sourceRow(source)
                                            if source.id != sources.last?.id {
                                                lightDivider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .refreshable { await loadConnections() }
            }
        }
        .navigationBarHidden(true)
        .task { await loadConnections() }
        .onReceive(NotificationCenter.default.publisher(for: .integrationConnectionChanged)) { notification in
            if let status = notification.userInfo?["status"] as? String, status == "error" {
                errorMessage = "The integration could not be connected. Please try again."
            }
            Task { await loadConnections() }
        }
        .alert("Integration Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete all data from this source?",
            isPresented: Binding(
                get: { deletionTarget != nil },
                set: { if !$0 { deletionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete source data", role: .destructive) {
                guard let connection = deletionTarget else { return }
                deletionTarget = nil
                perform(connection.providerId) {
                    try await RetrospectAPIClient.shared.deleteIntegrationData(connectionId: connection.id)
                }
            }
            Button("Cancel", role: .cancel) { deletionTarget = nil }
        } message: {
            Text("This removes raw evidence and any conclusions that no longer have other supporting evidence.")
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
                perform(source.id) {
                    try await RetrospectAPIClient.shared.importIntegrationArchive(providerId: source.id, fileURL: url)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Integrations")
                .font(FigmaLightTheme.mono(13, weight: .medium))
                .foregroundColor(FigmaLightTheme.mutedText)

            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(FigmaLightTheme.controlSurface)
                                .overlay(Circle().strokeBorder(FigmaLightTheme.border, lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Back")

                Spacer()

                Button {
                    Task { await loadConnections() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(FigmaLightTheme.controlSurface)
                                .overlay(Circle().strokeBorder(FigmaLightTheme.border, lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
                        )
                }
                .accessibilityLabel("Refresh integrations")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    private var summary: some View {
        let connected = remoteByProvider.values.filter { $0.connection?.status == "connected" }.count
        let attention = remoteByProvider.values.filter {
            guard let status = $0.connection?.status else { return false }
            return status != "connected" && status != "disconnected"
        }.count

        return HStack(spacing: 12) {
            metric(value: connected, label: "Verified")
            metric(value: attention, label: "Needs attention")
        }
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(FigmaLightTheme.body(28, weight: .semibold))
                .foregroundColor(FigmaLightTheme.primaryText)
            Text(label)
                .font(FigmaLightTheme.mono(12))
                .foregroundColor(FigmaLightTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(FigmaLightTheme.rowSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(FigmaLightTheme.border.opacity(0.75), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
        )
    }

    private func lightDivider() -> some View {
        Rectangle()
            .fill(FigmaLightTheme.border.opacity(0.65))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    private func sourceRow(_ source: IntegrationCatalogItem) -> some View {
        let remote = remoteByProvider[source.id]
        let connection = remote?.connection
        let subtitle = "\(statusText(source, connection: connection)) · \(source.plannedStatus ?? modeLabel(remote?.collectionMode))"

        return HStack(spacing: 14) {
            Image(systemName: source.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FigmaLightTheme.mutedText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(FigmaLightTheme.body(15, weight: .medium))
                    .foregroundColor(FigmaLightTheme.primaryText)
                Text(subtitle)
                    .font(FigmaLightTheme.mono(12))
                    .foregroundColor(statusColor(source, connection: connection))
            }

            Spacer()

            if busyProviderId == source.id {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let connection, connection.status != "disconnected" {
                HStack(spacing: 2) {
                    Button {
                        perform(source.id) {
                            try await RetrospectAPIClient.shared.disconnectIntegration(connectionId: connection.id)
                        }
                    } label: {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(FigmaLightTheme.mutedText)
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Turn off \(source.title)")

                    Menu {
                        Button {
                            perform(source.id) {
                                try await RetrospectAPIClient.shared.syncIntegration(connectionId: connection.id)
                            }
                        } label: {
                            Label("Sync now", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            deletionTarget = connection
                        } label: {
                            Label("Delete source data", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(FigmaLightTheme.mutedText)
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Manage \(source.title)")
                }
            } else if localPermissionGranted(source) {
                Button {
                    disconnectLocal(source)
                } label: {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(FigmaLightTheme.mutedText)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Turn off \(source.title)")
            } else {
                Button {
                    connect(source)
                } label: {
                    Image(systemName: source.connectionKind == .archiveImport ? "square.and.arrow.down" : "plus.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(FigmaLightTheme.primaryText)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Turn on \(source.title)")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func statusText(_ source: IntegrationCatalogItem, connection: BackendIntegrationConnection?) -> String {
        if let status = connection?.status {
            switch status {
            case "connected": return "Verified and connected"
            case "action_required": return "First sync queued"
            case "expired": return "Reconnect required"
            case "error": return "Sync needs attention"
            case "disconnected": return "Disconnected"
            default: return status.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }
        return localPermissionGranted(source) ? "Permission granted, awaiting verification" : "Not connected"
    }

    private func statusColor(_ source: IntegrationCatalogItem, connection: BackendIntegrationConnection?) -> Color {
        if connection?.status == "connected" { return Color.green }
        if connection?.status == "error" || connection?.status == "expired" { return Color.orange }
        return localPermissionGranted(source) ? Color.orange : FigmaLightTheme.mutedText
    }

    private func modeLabel(_ mode: String?) -> String {
        switch mode {
        case "native_ios": return "Device sync"
        case "oauth_api": return "Continuous sync"
        case "data_export": return "Archive import"
        default: return "Data source"
        }
    }

    private func localPermissionGranted(_ source: IntegrationCatalogItem) -> Bool {
        switch source.connectionKind {
        case .healthKit: return healthKitEnabled
        case .screenTime: return screenTimeService.isAuthorized
        case .calendar: return calendarConnected
        case .appleMusic: return appleMusicConnected
        case .photos: return photosConnected
        case .contacts: return contactsConnected
        case .googleDocs, .oauth, .archiveImport, .planned: return false
        }
    }

    private func connect(_ source: IntegrationCatalogItem) {
        switch source.connectionKind {
        case .healthKit:
            busyProviderId = source.id
            HealthKitManager.shared.requestAuthorization { success in
                DispatchQueue.main.async {
                    busyProviderId = nil
                    healthKitEnabled = success
                    if success {
                        IntegrationsSyncService.shared.syncIfNeeded()
                    } else {
                        errorMessage = "Apple Health access was not granted."
                    }
                }
            }
        case .screenTime:
            perform(source.id) {
                await screenTimeService.requestAuthorization()
                guard screenTimeService.isAuthorized else {
                    throw APIError.serverError("Screen Time access was not granted")
                }
                screenTimeService.startRetroactiveBackfill()
            }
        case .calendar, .appleMusic, .photos, .contacts:
            perform(source.id) {
                let connected: Bool
                switch source.connectionKind {
                case .calendar:
                    connected = await NativeSourcesManager.shared.syncCalendar()
                    calendarConnected = connected
                case .appleMusic:
                    connected = await NativeSourcesManager.shared.syncAppleMusic()
                    appleMusicConnected = connected
                case .photos:
                    connected = await NativeSourcesManager.shared.syncPhotos()
                    photosConnected = connected
                case .contacts:
                    connected = await NativeSourcesManager.shared.syncContacts()
                    contactsConnected = connected
                default:
                    connected = false
                }
                guard connected else { throw APIError.serverError("\(source.title) did not return readable data") }
            }
        case .googleDocs, .oauth:
            perform(source.id) {
                let url = try await RetrospectAPIClient.shared.startOAuthConnection(providerId: source.id)
                await MainActor.run { openURL(url) }
            }
        case .archiveImport:
            importSource = source
            showingFileImporter = true
        case .planned:
            errorMessage = "\(source.title) does not have a verified collection path yet."
        }
    }

    private func disconnectLocal(_ source: IntegrationCatalogItem) {
        switch source.connectionKind {
        case .healthKit:
            healthKitEnabled = false
        case .screenTime:
            screenTimeService.revokeAuthorization()
        case .calendar:
            calendarConnected = false
        case .appleMusic:
            appleMusicConnected = false
        case .photos:
            photosConnected = false
        case .contacts:
            contactsConnected = false
        case .googleDocs, .oauth, .archiveImport, .planned:
            break
        }
        HapticManager.shared.playLightImpact()
    }

    private func perform(_ providerId: String, operation: @escaping () async throws -> Void) {
        busyProviderId = providerId
        Task {
            do {
                try await operation()
                await loadConnections()
                busyProviderId = nil
                HapticManager.shared.playSuccessNotification()
            } catch {
                busyProviderId = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadConnections() async {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        do {
            let integrations = try await RetrospectAPIClient.shared.fetchIntegrations()
            remoteByProvider = Dictionary(uniqueKeysWithValues: integrations.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    IntegrationsDataView()
}
