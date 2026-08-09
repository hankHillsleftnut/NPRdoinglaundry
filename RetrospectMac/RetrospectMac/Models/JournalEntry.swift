import Foundation

/// A free-form, timestamped journal entry. Body is stored as Markdown (best LLM
/// interpretation quality for the synthesis pipeline + portable + clean round-trip).
struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    /// Markdown source of truth.
    var markdown: String

    /// Has this entry's *current* content been synced to the backend yet?
    var syncedMarkdownHash: Int?
    /// When the body last reached the backend (nil = never).
    var lastSyncedAt: Date?

    init(id: UUID = UUID(), createdAt: Date = Date(), markdown: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.markdown = markdown
        self.syncedMarkdownHash = nil
        self.lastSyncedAt = nil
    }

    /// First non-empty line, stripped of markdown markers — used as the list title.
    var title: String {
        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let cleaned = line
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "_", with: "")
                .trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
        }
        return "Untitled"
    }

    var preview: String {
        let body = markdown
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = body.replacingOccurrences(of: "\n", with: " ")
        return String(collapsed.prefix(120))
    }

    var isEmpty: Bool {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Plain text for the pipeline (markers stripped, structure preserved as newlines).
    var plainText: String { markdown }

    var needsSync: Bool {
        guard !isEmpty else { return false }
        return syncedMarkdownHash != markdown.hashValue
    }
}
