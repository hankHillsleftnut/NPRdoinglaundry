import Foundation

// MARK: - Entry Type Enum
enum EntryType: String, Codable {
    case text
    case video
    case voice
    
    /// Maps to the backend's expected content type string
    var backendContentType: String {
        switch self {
        case .text: return "text_entry"
        case .voice: return "voice_recording"
        case .video: return "video_entry"
        }
    }
}

// MARK: - Entry Model
struct Entry: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let type: EntryType
    let content: String // Text content, video transcription, or voice transcription
    let videoURL: URL? // Only for video entries
    let audioURL: URL? // Only for voice entries
    let imageURLs: [URL]? // Attached images for the entry
    var aiGeneratedTitle: String?
    var tags: [String]
    var isIncludedInInsights: Bool
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: EntryType,
        content: String,
        videoURL: URL? = nil,
        audioURL: URL? = nil,
        imageURLs: [URL]? = nil,
        aiGeneratedTitle: String? = nil,
        tags: [String] = [],
        isIncludedInInsights: Bool = true
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.content = content
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.imageURLs = imageURLs
        self.aiGeneratedTitle = aiGeneratedTitle
        self.tags = tags
        self.isIncludedInInsights = isIncludedInInsights
    }
    
    // Computed property for display title
    var displayTitle: String {
        if let title = aiGeneratedTitle, !title.isEmpty {
            return title
        }
        
        // Fallback to date-based title
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Entry from \(formatter.string(from: date))"
    }
    
    // Whether this entry has any meaningful content worth saving
    var hasValidContent: Bool {
        let hasText = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        switch type {
        case .text:
            return hasText
        case .voice:
            let hasAudio = audioURL != nil && FileManager.default.fileExists(atPath: audioURL!.path)
            return hasText || hasAudio
        case .video:
            let hasVideo = videoURL != nil && FileManager.default.fileExists(atPath: videoURL!.path)
            return hasText || hasVideo
        }
    }
    
    // Computed property for content preview (first 2 lines)
    var contentPreview: String {
        let lines = content.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: true)
        if lines.count >= 2 {
            return lines[0...1].joined(separator: "\n")
        } else if !lines.isEmpty {
            return String(lines[0])
        }
        return content.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Entry Manager
@MainActor
class EntryManager: ObservableObject {
    @Published var entries: [Entry] = []
    static let shared = EntryManager()
    
    private let fileStorage = FileStorageManager.shared
    
    init() {
        loadEntries()
    }
    
    // MARK: - Public Methods
    
    func addEntry(_ entry: Entry) {
        guard entry.hasValidContent else {
            print("⚠️ Rejected empty entry: \(entry.id) - Type: \(entry.type.rawValue) - no content or media")
            return
        }
        
        entries.append(entry)
        saveEntry(entry)
        print("✅ Added entry: \(entry.id) - Type: \(entry.type.rawValue)")
        
        // Sync to backend (non-blocking)
        syncEntryToBackend(entry)
    }
    
    /// Upload an entry to the Retrospect backend for the observation/insight pipeline.
    private func syncEntryToBackend(_ entry: Entry) {
        guard RetrospectAPIClient.shared.isAuthenticated else {
            print("⚠️ Skipping backend sync — not authenticated")
            return
        }
        guard !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Skipping backend sync — empty content for \(entry.id)")
            return
        }
        Task {
            do {
                try await RetrospectAPIClient.shared.uploadContent(
                    contentType: entry.type.backendContentType,
                    content: entry.content,
                    contentDate: entry.date
                )
                print("✅ Entry \(entry.id) synced to backend as '\(entry.type.backendContentType)'")
            } catch {
                print("❌ Entry sync failed for \(entry.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Resync all existing entries to the backend. Call this once to push
    /// entries that were never synced due to the content-type mismatch.
    func resyncAllEntriesToBackend() {
        guard RetrospectAPIClient.shared.isAuthenticated else {
            print("⚠️ Cannot resync — not authenticated")
            return
        }
        let validEntries = entries.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        print("🔄 Resyncing \(validEntries.count) entries to backend...")
        
        Task {
            var successCount = 0
            var failCount = 0
            
            for entry in validEntries {
                do {
                    try await RetrospectAPIClient.shared.uploadContent(
                        contentType: entry.type.backendContentType,
                        content: entry.content,
                        contentDate: entry.date
                    )
                    successCount += 1
                } catch {
                    failCount += 1
                    print("❌ Resync failed for \(entry.id): \(error.localizedDescription)")
                }
                
                // Small delay to avoid hammering the API
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            
            print("🔄 Resync complete: \(successCount) succeeded, \(failCount) failed out of \(validEntries.count)")
        }
    }
    
    func getAllEntries() -> [Entry] {
        return entries.sorted(by: { $0.date > $1.date })
    }
    
    func getEntries(ofType type: EntryType) -> [Entry] {
        return entries.filter { $0.type == type }.sorted(by: { $0.date > $1.date })
    }
    
    func getEntry(byId id: UUID) -> Entry? {
        return entries.first(where: { $0.id == id })
    }
    
    func updateEntry(_ updatedEntry: Entry) {
        if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
            entries[index] = updatedEntry
            saveEntry(updatedEntry)
            print("📝 Updated entry: \(updatedEntry.id)")
        }
    }
    
    func deleteEntry(withId id: UUID) {
        entries.removeAll { $0.id == id }
        
        do {
            try fileStorage.deleteEntry(id: id)
        print("🗑️ Deleted entry: \(id)")
        } catch {
            print("❌ Failed to delete entry: \(error.localizedDescription)")
        }
    }
    
    func deleteEntries(withIds ids: [UUID]) {
        entries.removeAll { ids.contains($0.id) }
        
        for id in ids {
            do {
                try fileStorage.deleteEntry(id: id)
            } catch {
                print("❌ Failed to delete entry \(id): \(error.localizedDescription)")
            }
        }
        
        print("🗑️ Deleted \(ids.count) entries")
    }
    
    func toggleInclusionStatus(for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].isIncludedInInsights.toggle()
            saveEntry(entries[index])
            print("🔄 Toggled inclusion status for entry: \(entryId)")
        }
    }
    
    func searchEntries(query: String) -> [Entry] {
        let lowercaseQuery = query.lowercased()
        return entries.filter { entry in
            entry.displayTitle.lowercased().contains(lowercaseQuery) ||
            entry.content.lowercased().contains(lowercaseQuery) ||
            entry.tags.contains(where: { $0.lowercased().contains(lowercaseQuery) })
        }.sorted(by: { $0.date > $1.date })
    }
    
    func getEntriesForWeek() -> [Entry] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        return entries.filter { entry in
            entry.date >= oneWeekAgo
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    func clearAllEntries() {
        let entryIds = entries.map { $0.id }
        
        entries.removeAll()
        
        for id in entryIds {
            do {
                try fileStorage.deleteEntry(id: id)
            } catch {
                print("❌ Failed to delete entry \(id): \(error.localizedDescription)")
            }
        }
        
        print("🗑️ Cleared all entries")
    }
    
    // MARK: - Storage Info
    
    func getStorageInfo() -> StorageInfo {
        return fileStorage.getStorageInfo()
    }
    
    // MARK: - Private Methods
    
    private func loadEntries() {
        do {
            entries = try fileStorage.loadAllEntries()
            print("📱 Loaded \(entries.count) entries from file storage")
        } catch {
            print("❌ Failed to load entries: \(error.localizedDescription)")
            entries = []
        }
    }
    
    private func saveEntries() {
        // Individual entry saving is now handled by addEntry/updateEntry
        // This method is kept for backward compatibility
        for entry in entries {
            do {
                try fileStorage.saveEntry(entry)
            } catch {
                print("❌ Failed to save entry \(entry.id): \(error.localizedDescription)")
            }
        }
    }
    
    private func saveEntry(_ entry: Entry) {
        do {
            try fileStorage.saveEntry(entry)
        } catch {
            print("❌ Failed to save entry: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug Methods
    
    func debugPrintEntries() {
        print("🔍 Entry Manager Debug Info:")
        print("Total entries: \(entries.count)")
        
        for (index, entry) in entries.enumerated() {
            print("  \(index + 1). ID: \(entry.id)")
            print("     Type: \(entry.type.rawValue)")
            print("     Date: \(entry.date)")
            print("     Title: \(entry.displayTitle)")
            print("     Tags: \(entry.tags.joined(separator: ", "))")
            print("     Content preview: \(String(entry.content.prefix(50)))...")
            print("     Included in Insights: \(entry.isIncludedInInsights)")
        }
    }
}

