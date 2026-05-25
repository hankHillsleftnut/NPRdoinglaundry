import SwiftUI
import UniformTypeIdentifiers
import GoogleSignIn

struct DataManagementSection: View {
    let onResetAllData: () -> Void
    let goalsManager: GoalsManager
    
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var exportData: Data?
    @State private var exportFileName = ""
    @State private var showGoogleDocsDetails = false
    @State private var showStorageInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Management")
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.primaryText)
            
            // Data Statistics
            DataStatisticsView(goalsManager: goalsManager)
            
            // Google Docs Integration Section - CHANGE: Use different name to avoid conflicts
            GoogleDocsDataSection(showDetails: $showGoogleDocsDetails)
            
            // Data Export Section
            VStack(spacing: 12) {
                DataActionButton(
                    icon: "externaldrive.fill",
                    title: "Storage Information",
                    subtitle: "View where your data is stored",
                    action: { showStorageInfo = true },
                    style: .primary
                )
                
                DataActionButton(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    subtitle: "Save your data as a backup file",
                    action: exportAppData,
                    style: .secondary
                )
                
                DataActionButton(
                    icon: "square.and.arrow.down",
                    title: "Import Data", 
                    subtitle: "Restore from a backup file",
                    action: { showImportSheet = true },
                    style: .secondary
                )
            }
            
            // Data Management Actions
            VStack(spacing: 12) {
                DataActionButton(
                    icon: "trash.circle",
                    title: "Clear Goals",
                    subtitle: "Remove all your goals",
                    action: clearGoals,
                    style: .warning
                )
                
                DataActionButton(
                    icon: "doc.text.fill.badge.minus",
                    title: "Clear Journals",
                    subtitle: "Remove all video journal entries",
                    action: clearJournals,
                    style: .warning
                )
            }
            
            // Reset All Data - Destructive Action
            VStack(spacing: 8) {
                Button(action: onResetAllData) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Data")
                                .font(.serifBody).fontWeight(.semibold)
                                .foregroundColor(LinearColors.Minimal.textPrimary)
                            
                            Text("Permanently delete all app data")
                                .font(.serifCaption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(LinearColors.Minimal.deleteRed)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("This action cannot be undone. Consider exporting your data first.")
                    .font(.serifCaption)
                    .foregroundColor(LinearColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let data = exportData {
                ShareSheet(activityItems: [data])
            }
        }
        .sheet(isPresented: $showImportSheet) {
            DocumentPicker(
                supportedTypes: [.json],
                onDocumentPicked: importAppData
            )
        }
        .sheet(isPresented: $showGoogleDocsDetails) { 
            GoogleDocsDetailView(isPresented: $showGoogleDocsDetails)
        }
        .sheet(isPresented: $showStorageInfo) {
            StorageInfoView()
        }
    }
    
    private func exportAppData() {
        Task { @MainActor in 
            let exportData = AppDataExporter.exportAllData(goalsManager: goalsManager)
            
            guard let jsonData = try? JSONEncoder().encode(exportData) else {
                // Handle error
                return
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            
            self.exportData = jsonData
            self.exportFileName = "retrospect_backup_\(timestamp).json"
            self.showExportSheet = true
        }
    }
    
    private func importAppData(url: URL) {
        Task { @MainActor in 
            do {
                let data = try Data(contentsOf: url)
                let importData = try JSONDecoder().decode(AppExportData.self, from: data)
                
                // Import the data
                AppDataImporter.importData(importData, goalsManager: goalsManager)
                
                // Show success message (you might want to add a state for this)
                
            } catch {
                // Handle import error
                print("Import failed: \(error)")
            }
        }
    }
    
    private func clearGoals() {
        goalsManager.clearAllGoals()
        // Show success feedback
    }
    
    private func clearJournals() {
        VideoJournalManager.shared.clearAllEntries()
        // Show success feedback
    }
}

struct DataStatisticsView: View {
    let goalsManager: GoalsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Overview")
                .font(.serifBody).fontWeight(.semibold)
                .foregroundColor(LinearColors.primaryText)
            
            HStack(spacing: 16) {
                DataStatCard(
                    title: "Goals",
                    value: "\(goalsManager.goals.count)",
                    icon: "target",
                    color: LinearColors.accent
                )
                
                DataStatCard(
                    title: "Journals",
                    value: "\(VideoJournalManager.shared.getAllEntries().count)",
                    icon: "video.fill",
                    color: LinearColors.deepAccent
                )
            }
            
            HStack(spacing: 16) {
                DataStatCard(
                    title: "Active Goals",
                    value: "\(goalsManager.getGoalsCount())",
                    icon: "checkmark.circle.fill",
                    color: LinearColors.successGreen
                )
                
                DataStatCard(
                    title: "Storage",
                    value: getStorageUsage(),
                    icon: "externaldrive.fill",
                    color: LinearColors.secondaryText
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func getStorageUsage() -> String {
        // Calculate approximate storage usage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let size = try? FileManager.default.sizeOfDirectory(at: documentsPath)
        
        if let sizeInBytes = size {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(sizeInBytes))
        }
        
        return "Unknown"
    }
}

struct DataStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.serifBody)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.primaryText)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(LinearColors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct DataActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    let style: ActionStyle
    
    enum ActionStyle {
        case primary
        case secondary
        case warning
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return LinearColors.accent.opacity(0.1)
            case .secondary:
                return LinearColors.inputBackground
            case .warning:
                return LinearColors.warningYellow.opacity(0.1)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary:
                return LinearColors.accent.opacity(0.3)
            case .secondary:
                return LinearColors.border
            case .warning:
                return LinearColors.warningYellow.opacity(0.3)
            }
        }
        
        var iconColor: Color {
            switch self {
            case .primary:
                return LinearColors.accent
            case .secondary:
                return LinearColors.secondaryText
            case .warning:
                return LinearColors.warningYellow
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                    .foregroundColor(style.iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.primaryText)
                    
                    Text(subtitle)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.secondaryText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .stroke(style.borderColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppExportData: Codable {
    let exportDate: Date
    let version: String
    let goals: [String]
    let userSettings: UserSettings
    let videoJournals: [VideoJournalEntry]
    
    struct UserSettings: Codable {
        let userName: String
        let backgroundAudioEnabled: Bool
        let faceIDEnabled: Bool
        let healthKitEnabled: Bool
        let generationType: String
        let audioTestMode: Bool
    }
}

struct AppDataExporter {
    @MainActor 
    static func exportAllData(goalsManager: GoalsManager) -> AppExportData {
        let userSettings = AppExportData.UserSettings(
            userName: UserDefaults.standard.string(forKey: "userName") ?? "",
            backgroundAudioEnabled: UserDefaults.standard.bool(forKey: "backgroundAudioEnabled"),
            faceIDEnabled: UserDefaults.standard.bool(forKey: "faceIDEnabled"),
            healthKitEnabled: UserDefaults.standard.bool(forKey: "healthKitEnabled"),
            generationType: UserDefaults.standard.string(forKey: "generationType") ?? GenerationType.goodListener.rawValue,
            audioTestMode: UserDefaults.standard.bool(forKey: "audioTestMode")
        )
        
        return AppExportData(
            exportDate: Date(),
            version: "1.0",
            goals: goalsManager.goals,
            userSettings: userSettings,
            videoJournals: VideoJournalManager.shared.getAllEntries()
        )
    }
}

struct AppDataImporter {
    @MainActor 
    static func importData(_ data: AppExportData, goalsManager: GoalsManager) {
        // Import goals
        goalsManager.importGoals(data.goals)
        
        // Import user settings
        UserDefaults.standard.set(data.userSettings.userName, forKey: "userName")
        UserDefaults.standard.set(data.userSettings.backgroundAudioEnabled, forKey: "backgroundAudioEnabled")
        UserDefaults.standard.set(data.userSettings.faceIDEnabled, forKey: "faceIDEnabled")
        UserDefaults.standard.set(data.userSettings.healthKitEnabled, forKey: "healthKitEnabled")
        UserDefaults.standard.set(data.userSettings.generationType, forKey: "generationType")
        UserDefaults.standard.set(data.userSettings.audioTestMode, forKey: "audioTestMode")
        
        // Import video journals
        VideoJournalManager.shared.importEntries(data.videoJournals)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}

extension FileManager {
    func sizeOfDirectory(at url: URL) throws -> UInt64 {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        let enumerator = self.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys))!
        
        var totalSize: UInt64 = 0
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                continue
            }
            
            if let fileSize = resourceValues.fileSize {
                totalSize += UInt64(fileSize)
            }
        }
        
        return totalSize
    }
}

// MARK: - Google Docs Integration View
struct GoogleDocsDataSection: View { 
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @Binding var showDetails: Bool
    @State private var showAuthSheet = false
    @State private var documentCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Google Docs Data")
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.primaryText)
            
            // Connection Status Card
            VStack(spacing: 12) {
                DataActionButton(
                    icon: googleDocsService.isConnected ? "checkmark.circle.fill" : "link.circle",
                    title: googleDocsService.isConnected ? "Google Docs Connected" : "Connect Google Docs",
                    subtitle: googleDocsService.isConnected ? 
                        "Connected • \(documentCount) documents available" : 
                        "Connect to enhance your reflections with your latest documents",
                    action: {
                        if googleDocsService.isConnected {
                            showDetails = true
                        } else {
                            showAuthSheet = true
                        }
                    },
                    style: googleDocsService.isConnected ? .primary : .secondary
                )
                
                if googleDocsService.isConnected {
                    // Quick Actions Row
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await refreshGoogleDocs()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.serifLabel)
                                Text("Refresh")
                                    .font(.serifLabel)
                            }
                            .foregroundColor(LinearColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearColors.accent.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(LinearColors.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(googleDocsService.isLoading)
                        
                        Button(action: {
                            showDetails = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.serifLabel)
                                Text("Browse")
                                    .font(.serifLabel)
                            }
                            .foregroundColor(LinearColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearColors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(LinearColors.border, lineWidth: 1)
                                    )
                            )
                        }
                        
                        Spacer()
                        
                        if googleDocsService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(LinearColors.accent)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            // Configuration Note
            if !isGoogleConfigured() {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.serifLabel)
                            .foregroundColor(LinearColors.warningYellow)
                        
                        Text("Setup Required")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(LinearColors.warningYellow)
                    }
                    
                    Text("Google integration requires configuration. Please add your Google Client ID to enable this feature.")
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.secondaryText)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .fill(LinearColors.warningYellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .stroke(LinearColors.warningYellow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            updateDocumentCount()
            Task {
                await googleDocsService.checkAuthenticationStatus()
            }
        }
        .onChange(of: googleDocsService.documents) { _, _ in
            updateDocumentCount()
        }
        .sheet(isPresented: $showAuthSheet) {
            GoogleAuthView(isPresented: $showAuthSheet)
        }
    }
    
    private func isGoogleConfigured() -> Bool {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return false
        }
        return !clientID.isEmpty && clientID != "YOUR_GOOGLE_CLIENT_ID_HERE"
    }
    
    private func updateDocumentCount() {
        documentCount = googleDocsService.documents.count
    }
    
    private func refreshGoogleDocs() async {
        do {
            _ = try await googleDocsService.fetchLastTwoWeeksDocuments()
        } catch {
            print("Failed to refresh Google Docs: \(error)")
        }
    }
}

// MARK: - Google Docs Detail View
struct GoogleDocsDetailView: View {
    @Binding var isPresented: Bool
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @State private var searchText = ""
    @State private var sortBy: SortOption = .dateModified
    @State private var selectedDocument: GoogleDocsModel?
    @State private var showDocumentContent = false
    
    enum SortOption: String, CaseIterable {
        case dateModified = "Recent"
        case dateCreated = "Created"
        case name = "Name"
        
        var systemImage: String {
            switch self {
            case .dateModified: return "clock.fill"
            case .dateCreated: return "calendar.badge.plus"
            case .name: return "textformat.abc"
            }
        }
    }
    
    private var filteredDocuments: [GoogleDocsModel] {
        let filtered = searchText.isEmpty ? googleDocsService.documents : googleDocsService.documents.filter { doc in
            doc.name.localizedCaseInsensitiveContains(searchText) ||
            (doc.content?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        return filtered.sorted { doc1, doc2 in
            switch sortBy {
            case .dateModified:
                return doc1.modifiedTime > doc2.modifiedTime
            case .dateCreated:
                return doc1.createdTime > doc2.createdTime
            case .name:
                return doc1.name.localizedCompare(doc2.name) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
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
                    if googleDocsService.documents.isEmpty && !googleDocsService.isLoading {
                        emptyStateView
                    } else {
                        VStack(spacing: 16) {
                            // Search and Controls
                            controlsView
                            
                            // Documents List
                            if googleDocsService.isLoading {
                                loadingView
                            } else if filteredDocuments.isEmpty && !searchText.isEmpty {
                                noResultsView
                            } else {
                                documentsListView
                            }
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Google Docs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(LinearColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await refreshDocuments()
                            }
                        }) {
                            Label("Refresh Data", systemImage: "arrow.clockwise")
                        }
                        .disabled(googleDocsService.isLoading)
                        
                        Button(action: {
                            googleDocsService.signOut()
                        }) {
                            Label("Sign Out", systemImage: "person.crop.circle.badge.minus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(LinearColors.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentContent) {
            if let document = selectedDocument {
                DocumentContentSheet(
                    document: document,
                    content: document.content ?? "",
                    isLoading: false
                )
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LinearColors.secondaryText)
                
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.serifBody)
                    .foregroundColor(LinearColors.primaryText)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.inputBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
            )
            
            // Sort options
            HStack {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            sortBy = option
                        }) {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.rawValue)
                                if sortBy == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sortBy.systemImage)
                            .font(.system(size: 16, weight: .medium))
                        Text("Sort: \(sortBy.rawValue)")
                            .font(.system(size: 15, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(LinearColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(LinearColors.accent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: BorderRadius.card)
                                    .stroke(LinearColors.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                Text("\(filteredDocuments.count) documents")
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var documentsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredDocuments) { document in
                    DocumentCard(document: document)
                        .onTapGesture {
                            selectedDocument = document
                            showDocumentContent = true
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearColors.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                        .foregroundColor(LinearColors.accent)
                }
                
                VStack(spacing: 12) {
                    Text("No Documents Found")
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.primaryText)
                    
                    Text("Tap 'Refresh Data' to load your recent Google Docs and enhance your weekly insights.")
                        .font(.serifBody)
                        .foregroundColor(LinearColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
            }
            
            Button(action: {
                Task {
                    await refreshDocuments()
                }
            }) {
                HStack(spacing: 12) {
                    if googleDocsService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(googleDocsService.isLoading ? "Loading..." : "Refresh Data")
                        .font(.serifBody).fontWeight(.semibold)
                }
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .fill(LinearColors.accent)
                        .shadow(color: LinearColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
            .disabled(googleDocsService.isLoading)
            
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(LinearColors.accent)
            Text("Loading your Google Docs...")
                .font(.serifBody)
                .foregroundColor(LinearColors.secondaryText)
            Spacer()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(LinearColors.secondaryText.opacity(0.7))
            Text("No Results Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(LinearColors.primaryText)
            Text("Try adjusting your search terms or refresh to find relevant documents.")
                .font(.serifBody)
                .foregroundColor(LinearColors.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    private func refreshDocuments() async {
        do {
            _ = try await googleDocsService.fetchLastTwoWeeksDocuments()
        } catch {
            print("Failed to refresh documents: \(error)")
        }
    }
}

// MARK: - Document Card
struct DocumentCard: View {
    let document: GoogleDocsModel
    @State private var showingContent = false
    @State private var documentContent = ""
    @State private var isLoadingContent = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and metadata
            HStack(spacing: 15) {
                // Document icon with gradient background
                ZStack {
                    Circle()
                        .fill(LinearColors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.serifBody).fontWeight(.semibold)
                        .foregroundColor(LinearColors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(formatDate(document.modifiedTime))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    showingContent = true
                    loadContent()
                }) {
                    Image(systemName: "eye.circle.fill")
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.accent)
                }
            }
            
            // Divider
            Rectangle()
                .fill(LinearColors.border.opacity(0.5))
                .frame(height: 1)
            
            // Metadata row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.accent)
                    Text("Modified \(relativeDateString(document.modifiedTime))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LinearColors.secondaryText)
                }
                
                if document.content != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.successGreen)
                        Text("Content Available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(LinearColors.successGreen)
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
        )
        .sheet(isPresented: $showingContent) {
            DocumentContentSheet(
                document: document,
                content: documentContent,
                isLoading: isLoadingContent
            )
        }
    }
    
    private func loadContent() {
        print("🔍 LOADING CONTENT for: \(document.name)")
        
        isLoadingContent = true
        documentContent = ""
        
        Task {
            do {
                let content = try await GoogleDocsService.shared.fetchContentForDocument(document.id)
                await MainActor.run {
                    print("✅ SUCCESS: Got \(content.count) characters")
                    self.documentContent = content
                    self.isLoadingContent = false
                }
            } catch {
                await MainActor.run {
                    print("❌ ERROR: \(error)")
                    self.documentContent = "Error loading content: \(error.localizedDescription)"
                    self.isLoadingContent = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Document Content Sheet
struct DocumentContentSheet: View {
    let document: GoogleDocsModel
    let content: String
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching app design
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Document Header
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(LinearColors.accent.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(LinearColors.accent)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Google Document")
                                        .font(.serifLabel)
                                        .foregroundColor(LinearColors.secondaryText)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                    
                                    Text(document.name)
                                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                        .foregroundColor(LinearColors.primaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                            }
                            
                            // Metadata row
                            HStack(spacing: 16) {
                                Label(formatDate(document.modifiedTime), systemImage: "clock")
                                    .font(.serifLabel)
                                    .foregroundColor(LinearColors.secondaryText)
                                
                                Label("\(content.count) characters", systemImage: "textformat.size")
                                    .font(.serifLabel)
                                    .foregroundColor(LinearColors.secondaryText)
                                
                                Spacer()
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Content
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Document Content")
                                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                    .foregroundColor(LinearColors.primaryText)
                                
                                Spacer()
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(LinearColors.accent)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if isLoading {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .tint(LinearColors.accent)
                                    Text("Loading document content...")
                                        .font(.serifBody)
                                        .foregroundColor(LinearColors.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                if content.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "doc.text")
                                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                            .foregroundColor(LinearColors.secondaryText.opacity(0.7))
                                        Text("No content available")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(LinearColors.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    Text(content)
                                        .font(.serifBody)
                                        .foregroundColor(LinearColors.primaryText)
                                        .lineSpacing(6)
                                        .textSelection(.enabled)
                                        .padding(20)
                                        .background(
                                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                                .stroke(LinearColors.border.opacity(0.5), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LinearColors.accent)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Google Auth View
struct GoogleAuthView: View {
    @Binding var isPresented: Bool
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching app design
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
                    ScrollView {
                        VStack(spacing: 32) {
                            // Hero Section
                            VStack(spacing: 24) {
                                ZStack {
                                    Circle()
                                        .fill(LinearColors.accent.opacity(0.15))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "cloud.circle.fill")
                                        .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                        .foregroundColor(LinearColors.accent)
                                }
                                
                                VStack(spacing: 16) {
                                    Text("Secure Document Access")
                                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                        .foregroundColor(LinearColors.primaryText)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("We'll securely access your Google Docs with read-only permissions to include relevant content in your weekly insights.")
                                        .font(.serifBody)
                                        .foregroundColor(LinearColors.secondaryText)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 40)
                            
                            // Features Section
                            VStack(spacing: 20) {
                                FeatureCard(
                                    icon: "doc.text.fill",
                                    title: "Document Content",
                                    description: "Access text from your Google Docs to enhance AI insights"
                                )
                                
                                FeatureCard(
                                    icon: "shield.checkered",
                                    title: "Privacy First",
                                    description: "Read-only access only, your data stays secure and private"
                                )
                                
                                FeatureCard(
                                    icon: "clock.badge.checkmark",
                                    title: "Recent Activity",
                                    description: "Focus on documents modified in the last 2 weeks"
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer(minLength: 40)
                        }
                    }
                    
                    // Bottom Action Section
                    VStack(spacing: 16) {
                        Button(action: authenticateWithGoogle) {
                            HStack(spacing: 12) {
                                if isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.key.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                Text(isAuthenticating ? "Connecting..." : "Connect with Google")
                                    .font(.serifBody).fontWeight(.semibold)
                            }
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.card)
                                    .fill(LinearColors.accent)
                                    .shadow(color: LinearColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .disabled(isAuthenticating)
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Skip for now")
                                .font(.serifBody)
                                .foregroundColor(LinearColors.secondaryText)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .background(LinearColors.background)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LinearColors.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(LinearColors.accent.opacity(0.15))
                            )
                    }
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func authenticateWithGoogle() {
        isAuthenticating = true
        Task {
            do {
                try await googleDocsService.authenticate()
                await MainActor.run {
                    isAuthenticating = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Feature Card for Google Auth
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearColors.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LinearColors.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.serifBody).fontWeight(.semibold)
                    .foregroundColor(LinearColors.primaryText)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(LinearColors.secondaryText)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(LinearColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
