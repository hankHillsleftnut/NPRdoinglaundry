import Foundation

// Ensure VideoJournalEntry is Hashable for robust ForEach behavior
struct VideoJournalEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let videoURL: URL
    let transcription: String
    var isIncludedInInsights: Bool
    
    init(id: UUID = UUID(), date: Date = Date(), videoURL: URL, transcription: String, isIncludedInInsights: Bool = true) {
        self.id = id
        self.date = date
        self.videoURL = videoURL
        self.transcription = transcription
        self.isIncludedInInsights = isIncludedInInsights
    }
    
    // Hashable conformance will be synthesized by the compiler
    // No need to implement hash(into:) or == if all stored properties are Hashable.
}

@MainActor // Ensure VideoJournalManager is on the MainActor as it publishes UI data
class VideoJournalManager: ObservableObject {
    @Published var entries: [VideoJournalEntry] = []
    static let shared = VideoJournalManager()
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "videoJournalEntries"
    
    init() {
        loadEntries()
        validateVideoFiles()
    }
    
    func addEntry(_ entry: VideoJournalEntry) {
        // Validate that the video file exists before adding
        if !FileManager.default.fileExists(atPath: entry.videoURL.path) {
            print("⚠️ Warning: Video file not found at \(entry.videoURL.path)")
            // Still add the entry but log the warning
        }
        
        entries.append(entry)
        saveEntries()
        print("✅ Added video journal entry: \(entry.id)")
    }
    
    func getEntriesForWeek() -> [VideoJournalEntry] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        return entries.filter { entry in
            entry.date >= oneWeekAgo
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    func toggleInclusionStatus(for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].isIncludedInInsights.toggle()
            saveEntries()
            print("🔄 Toggled inclusion status for entry: \(entryId)")
        }
    }

    internal func deleteEntries(withIDs idsToDelete: [UUID]) {
        // Delete video files before removing entries
        for id in idsToDelete {
            if let entry = entries.first(where: { $0.id == id }) {
                deleteVideoFile(at: entry.videoURL)
            }
        }
        
        entries.removeAll { idsToDelete.contains($0.id) }
        saveEntries()
        print("🗑️ Deleted \(idsToDelete.count) video journal entries")
    }
    
    internal func updateEntry(_ entryToUpdate: VideoJournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entryToUpdate.id }) {
            entries[index] = entryToUpdate
            saveEntries()
            print("📝 Updated video journal entry: \(entryToUpdate.id)")
        }
    }
    
    func getAllEntries() -> [VideoJournalEntry] {
        return entries
    }
    
    func importEntries(_ newEntries: [VideoJournalEntry]) {
        entries = newEntries
        saveEntries()
        print("📥 Imported \(newEntries.count) video journal entries")
    }
    
    func clearAllEntries() {
        // Delete all video files before clearing entries
        for entry in entries {
            deleteVideoFile(at: entry.videoURL)
        }
        
        entries.removeAll()
        saveEntries()
        print("🗑️ Cleared all video journal entries")
    }
    
    // MARK: - Video File Management
    
    private func deleteVideoFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ Deleted video file: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete video file: \(error.localizedDescription)")
        }
    }
    
    private func validateVideoFiles() {
        print("🔍 Validating video files...")
        var validEntries: [VideoJournalEntry] = []
        var deletedCount = 0
        
        for entry in entries {
            if FileManager.default.fileExists(atPath: entry.videoURL.path) {
                validEntries.append(entry)
            } else {
                print("❌ Video file missing for entry \(entry.id): \(entry.videoURL.lastPathComponent)")
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            entries = validEntries
            saveEntries()
            print("🧹 Cleaned up \(deletedCount) entries with missing video files")
        } else {
            print("✅ All video files are valid")
        }
    }
    
    func getVideoFileSize(for entry: VideoJournalEntry) -> String {
        guard FileManager.default.fileExists(atPath: entry.videoURL.path) else {
            return "Missing"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: entry.videoURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("❌ Error getting file size: \(error)")
        }
        
        return "Unknown"
    }

    private func loadEntries() {
        if let data = userDefaults.data(forKey: entriesKey),
           let decodedEntries = try? JSONDecoder().decode([VideoJournalEntry].self, from: data) {
            entries = decodedEntries
            print("📱 Loaded \(entries.count) video journal entries from UserDefaults")
        } else {
            print("📱 No saved video journal entries found")
        }
    }
    
    internal func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: entriesKey)
            print("💾 Saved \(entries.count) video journal entries to UserDefaults")
        } else {
            print("❌ Failed to save video journal entries")
        }
    }
    
    // MARK: - Debug Methods
    
    func debugPrintEntries() {
        print("🔍 Video Journal Entries Debug Info:")
        print("Total entries: \(entries.count)")
        
        for (index, entry) in entries.enumerated() {
            let fileExists = FileManager.default.fileExists(atPath: entry.videoURL.path)
            let fileSize = getVideoFileSize(for: entry)
            print("  \(index + 1). ID: \(entry.id)")
            print("     Date: \(entry.date)")
            print("     File: \(entry.videoURL.lastPathComponent)")
            print("     Exists: \(fileExists)")
            print("     Size: \(fileSize)")
            print("     Transcription: \(entry.transcription.prefix(50))...")
            print("     Included in Insights: \(entry.isIncludedInInsights)")
        }
    }
}
