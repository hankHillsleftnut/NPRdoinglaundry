import Foundation
import Combine

/// Local-first persistence. Entries autosave to disk immediately so words are never lost,
/// independent of network. Backend sync is layered on top via `SyncEngine`.
@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published var selectedID: UUID?

    private let fileURL: URL
    private let backupDir: URL
    private var lastSnapshot = Date.distantPast
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    /// Fires whenever an entry's content actually changes (used by the session monitor).
    let didEdit = PassthroughSubject<UUID, Never>()

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("Retrospect", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("journal.json")
        self.backupDir = dir.appendingPathComponent("backups", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        load()
        // Snapshot whatever we loaded before this session touches anything, so the pre-session
        // state is always recoverable.
        snapshotCurrentFile(tag: "launch")

        // Debounced disk writes so rapid typing doesn't thrash the filesystem.
        // DispatchQueue (not RunLoop.main) so the timer still fires during event tracking
        // (menus, scrolling) — otherwise a save could stall exactly while you're interacting.
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.writeToDisk() }

        if entries.isEmpty {
            let first = JournalEntry()
            entries = [first]
            selectedID = first.id
            writeToDisk()
        } else {
            selectedID = entries.first?.id
        }
    }

    var selectedEntry: JournalEntry? {
        guard let id = selectedID else { return nil }
        return entries.first { $0.id == id }
    }

    /// Sorted newest-first for the sidebar list.
    var sortedEntries: [JournalEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    func newEntry() {
        // Reuse an existing empty entry rather than piling up blanks.
        if let empty = entries.first(where: { $0.isEmpty }) {
            selectedID = empty.id
            return
        }
        let entry = JournalEntry()
        entries.insert(entry, at: 0)
        selectedID = entry.id
        scheduleSave()
    }

    func updateSelected(markdown: String) {
        update(id: selectedID, markdown: markdown)
    }

    /// Write to a *specific* entry by id. The editor serializes on a debounce, so by the time
    /// a change lands the selection may have moved — targeting the id (not `selectedID`) keeps
    /// the in-flight text from being written into the wrong entry.
    func update(id: UUID?, markdown: String) {
        guard let id, let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        guard entries[idx].markdown != markdown else { return }
        entries[idx].markdown = markdown
        entries[idx].updatedAt = Date()
        didEdit.send(id)
        scheduleSave()
    }

    func markSynced(id: UUID, contentHash: Int) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].syncedMarkdownHash = contentHash
        entries[idx].lastSyncedAt = Date()
        scheduleSave()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        if selectedID == id { selectedID = sortedEntries.first?.id }
        if entries.isEmpty { newEntry() }
        scheduleSave()
    }

    /// Entries whose current content hasn't been synced yet.
    func unsyncedEntries() -> [JournalEntry] {
        entries.filter { $0.needsSync }
    }

    // MARK: - Disk

    private func scheduleSave() { saveSubject.send(()) }

    private func writeToDisk() {
        // Guard against catastrophic loss: if the file on disk currently holds materially MORE
        // text than what we're about to write (an accidental wipe/shrink), preserve the old file
        // as a backup before overwriting it.
        let newTotal = entries.reduce(0) { $0 + $1.markdown.count }
        if let existing = try? Data(contentsOf: fileURL),
           let prev = try? JSONDecoder.iso.decode([JournalEntry].self, from: existing) {
            let prevTotal = prev.reduce(0) { $0 + $1.markdown.count }
            if prevTotal > 200, newTotal < prevTotal / 2 {
                writeBackup(prev, tag: "autosafe")
            }
        }

        do {
            let data = try JSONEncoder.iso.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[Retrospect] save failed: \(error)")
        }

        // Rolling timestamped snapshot, at most once every few minutes of active writing.
        if Date().timeIntervalSince(lastSnapshot) > 180 {
            lastSnapshot = Date()
            writeBackup(entries, tag: "snap")
        }
    }

    // MARK: - Backups (so content is never unrecoverable)

    private func snapshotCurrentFile(tag: String) {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.iso.decode([JournalEntry].self, from: data),
              decoded.contains(where: { !$0.markdown.isEmpty }) else { return }
        writeBackup(decoded, tag: tag)
    }

    private func writeBackup(_ snapshot: [JournalEntry], tag: String) {
        guard snapshot.contains(where: { !$0.markdown.isEmpty }) else { return }
        let stamp = Self.stampFormatter.string(from: Date())
        let url = backupDir.appendingPathComponent("journal-\(stamp)-\(tag).json")
        if let data = try? JSONEncoder.iso.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
        pruneBackups(keep: 60)
    }

    private func pruneBackups(keep: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let sorted = files.filter { $0.pathExtension == "json" }.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return a > b
        }
        for old in sorted.dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f
    }()

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder.iso.decode([JournalEntry].self, from: data) {
            entries = decoded
        }
    }
}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
