import Foundation
import Combine

/// A note exactly as the user typed it, plus everything needed to get it to the
/// server later. The `id` doubles as the backend idempotency key (`clientUuid`),
/// which is what makes replaying the queue safe.
struct CapturedNote: Codable, Identifiable, Equatable {
    enum SyncState: String, Codable {
        /// Written locally, not yet acknowledged by the server.
        case pending
        /// Server acknowledged it. The local copy is kept regardless.
        case synced
        /// The server rejected the payload itself. Still on disk, no longer
        /// cycling through backoff; retried from scratch on the next launch.
        case blocked
    }

    let id: UUID
    /// Missing on older files and signed-out captures; never assigned on sign-in.
    let ownerUserId: String?
    let contentType: String
    let content: String
    let capturedAt: Date
    let metadata: [String: String]?

    var syncState: SyncState
    /// Failed upload attempts. Drives the backoff delay; auth failures never
    /// increment it, because being signed out is not the note's fault.
    var attemptCount: Int
    var lastAttemptAt: Date?
    var lastError: String?
    var rawContentId: String?
    var syncedAt: Date?

    var isPending: Bool {
        syncState == .pending
    }
}

/// Durable, local-first storage for captured notes.
///
/// Every note is written to its own JSON file in the Documents directory before
/// any network call happens, so a note survives app kill, force quit, offline and
/// a failed sign-in. Nothing in here deletes a note as a result of a sync outcome
/// — the local copy is the source of truth and the server is the replica.
///
/// One file per note (rather than a single array) is deliberate: a partial write
/// can only ever damage the note being written, never the ones already captured.
@MainActor
final class CapturedNoteStore: ObservableObject {
    static let shared = CapturedNoteStore()

    /// All notes, newest first.
    @Published private(set) var notes: [CapturedNote] = []

    // MARK: - Directory Structure

    private let fileManager = FileManager.default
    private let directory: URL?

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var retrospectDataDirectory: URL {
        documentsDirectory.appendingPathComponent("RetrospectData", isDirectory: true)
    }

    private var notesDirectory: URL {
        directory ?? retrospectDataDirectory.appendingPathComponent("Notes", isDirectory: true)
    }

    // `.complete` protection would make the file unreadable while the device is
    // locked, which is exactly when a background drain wants to run.
    private let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    // MARK: - Initialization

    init(directory: URL? = nil) {
        self.directory = directory
        setupDirectory()
        loadNotes()
    }

    private func setupDirectory() {
        guard !fileManager.fileExists(atPath: notesDirectory.path) else { return }
        do {
            try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
            print("📁 Created directory: \(notesDirectory.lastPathComponent)")
        } catch {
            print("❌ Failed to create notes directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Capture

    /// Persist a note to disk and return it. Throws only if the write failed, in
    /// which case the caller must surface the failure rather than pretend the
    /// note was saved — this is the one moment where a note can genuinely be lost.
    ///
    /// Pass `id` to tie the note to something the app already identifies (an
    /// `Entry.id`, say). Capturing the same id twice is a no-op that returns the
    /// existing note, so a bulk resync cannot fork a note into two server rows.
    @discardableResult
    func capture(
        id: UUID = UUID(),
        content: String,
        contentType: String,
        capturedAt: Date = Date(),
        metadata: [String: String]? = nil,
        ownerUserId: String? = nil
    ) throws -> CapturedNote {
        if let existing = note(id: id) {
            return existing
        }

        let note = CapturedNote(
            id: id,
            ownerUserId: ownerUserId,
            contentType: contentType,
            content: content,
            capturedAt: capturedAt,
            metadata: metadata,
            syncState: .pending,
            attemptCount: 0,
            lastAttemptAt: nil,
            lastError: nil,
            rawContentId: nil,
            syncedAt: nil
        )

        try write(note)
        insert(note)
        print("💾 Captured note \(note.id) (\(contentType))")
        return note
    }

    // MARK: - Queries

    /// Notes owed to this account, oldest first. Unowned notes remain local.
    func pendingNotes(ownerUserId: String?) -> [CapturedNote] {
        guard let ownerUserId else { return [] }
        return notes.filter { $0.isPending && $0.ownerUserId == ownerUserId }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func note(id: UUID) -> CapturedNote? {
        notes.first { $0.id == id }
    }

    var pendingCount: Int {
        notes.reduce(into: 0) { $0 += $1.isPending ? 1 : 0 }
    }

    /// Explicit user deletion removes the durable copy before forgetting it in
    /// memory. A failed removal leaves the note intact and is reported to the caller.
    func discard(id: UUID) throws {
        do {
            try fileManager.removeItem(at: fileURL(for: id))
        } catch CocoaError.fileNoSuchFile {
            // Already absent on disk; still remove any in-memory copy.
        }
        notes.removeAll { $0.id == id }
    }

    // MARK: - Sync Bookkeeping

    /// The server acknowledged the note. The local copy stays — it is the user's
    /// second brain, not a transmit buffer.
    func markSynced(id: UUID, rawContentId: String?) {
        update(id: id) { note in
            note.syncState = .synced
            note.rawContentId = rawContentId
            note.syncedAt = Date()
            note.lastError = nil
        }
    }

    /// A retryable failure. Bumps the attempt count so backoff widens.
    func markAttemptFailed(id: UUID, error: Error) {
        update(id: id) { note in
            note.attemptCount += 1
            note.lastAttemptAt = Date()
            note.lastError = error.localizedDescription
        }
    }

    /// The user is signed out. Record why the note is stuck without penalising it,
    /// so it goes out immediately once auth returns.
    func markWaitingForAuth(id: UUID, error: Error) {
        update(id: id) { note in
            note.lastAttemptAt = Date()
            note.lastError = error.localizedDescription
        }
    }

    /// The server rejected this payload. Stop cycling, keep the note.
    func markBlocked(id: UUID, error: Error) {
        update(id: id) { note in
            note.syncState = .blocked
            note.attemptCount += 1
            note.lastAttemptAt = Date()
            note.lastError = error.localizedDescription
        }
        print("⚠️ Note \(id) blocked by server, kept locally: \(error.localizedDescription)")
    }

    /// Give every blocked note one more chance. Called at launch, because a new
    /// build may be exactly what unblocks it.
    func requeueBlockedNotes() {
        let blocked = notes.filter { $0.syncState == .blocked }
        guard !blocked.isEmpty else { return }

        for note in blocked {
            update(id: note.id) { candidate in
                candidate.syncState = .pending
                candidate.attemptCount = 0
            }
        }
        print("🔄 Requeued \(blocked.count) blocked note(s)")
    }

    // MARK: - Persistence

    /// Re-read the directory. Needed because a launch before the device's first
    /// unlock cannot read protected files at all: `init` would see an empty store
    /// and the queue would believe there was nothing to send. Callers re-run this
    /// when protected data becomes available and on foreground.
    func reload() {
        loadNotes()
    }

    private func loadNotes() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        var loaded: [CapturedNote] = []
        var unreadable = 0

        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                loaded.append(try Self.decoder.decode(CapturedNote.self, from: data))
            } catch {
                // A single bad file must not take the rest of the second brain
                // down with it. Nothing is deleted either way — a decode failure
                // is left in place for inspection, and a permission failure just
                // means the device is locked and `reload()` will pick it up.
                unreadable += 1
                if (error as NSError).code == NSFileReadNoPermissionError {
                    print("⚠️ Note \(file.lastPathComponent) is protected; will retry after unlock")
                } else {
                    print("❌ Could not read note at \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // Never let a failed read shrink the in-memory view: a note we forget is
        // a note we stop retrying.
        for existing in notes where !loaded.contains(where: { $0.id == existing.id }) {
            loaded.append(existing)
        }

        notes = loaded.sorted { $0.capturedAt > $1.capturedAt }
        print("📂 Loaded \(notes.count) note(s), \(pendingCount) pending, \(unreadable) unreadable")
    }

    private func write(_ note: CapturedNote) throws {
        setupDirectory()
        let data = try Self.encoder.encode(note)
        try data.write(to: fileURL(for: note.id), options: writeOptions)
    }

    private func fileURL(for id: UUID) -> URL {
        notesDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func insert(_ note: CapturedNote) {
        notes.removeAll { $0.id == note.id }
        notes.insert(note, at: 0)
        notes.sort { $0.capturedAt > $1.capturedAt }
    }

    /// Mutate a note in memory and on disk together. If the disk write fails the
    /// in-memory copy is rolled back, so the two never disagree about whether a
    /// note still needs sending — a note we wrongly believe is synced is a lost note.
    private func update(id: UUID, _ mutate: (inout CapturedNote) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }

        let previous = notes[index]
        var updated = previous
        mutate(&updated)

        do {
            try write(updated)
            notes[index] = updated
        } catch {
            print("❌ Failed to persist note \(id): \(error.localizedDescription)")
        }
    }

    // MARK: - Coding

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
