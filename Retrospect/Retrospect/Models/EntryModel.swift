import Foundation

// MARK: - Entry Type Enum
enum EntryType: String, Codable {
    case text
    case video
    case voice
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
        entries.append(entry)
        saveEntry(entry)
        print("✅ Added entry: \(entry.id) - Type: \(entry.type.rawValue)")
        
        // Sync to backend (non-blocking)
        syncEntryToBackend(entry)
    }
    
    /// Upload an entry to the Retrospect backend for the observation/insight pipeline.
    private func syncEntryToBackend(_ entry: Entry) {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        Task {
            do {
                try await RetrospectAPIClient.shared.uploadContent(
                    contentType: entry.type.rawValue,
                    content: entry.content,
                    contentDate: entry.date
                )
                print("Entry \(entry.id) synced to backend")
            } catch {
                print("Entry sync failed: \(error.localizedDescription)")
            }
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

