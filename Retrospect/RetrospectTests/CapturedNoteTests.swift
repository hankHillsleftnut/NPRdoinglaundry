import Foundation
import Testing
@testable import Retrospect

@MainActor
struct CapturedNoteTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func ownershipPersistsAndUnownedNotesStayLocal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let owned = try store.capture(content: "Account A", contentType: "text_entry", ownerUserId: "A")
        let unowned = try store.capture(content: "Signed out", contentType: "text_entry")
        let reloaded = CapturedNoteStore(directory: directory)
        #expect(reloaded.note(id: owned.id)?.ownerUserId == "A")
        #expect(reloaded.note(id: unowned.id)?.ownerUserId == nil)
        #expect(reloaded.pendingNotes(ownerUserId: "A").map(\.id) == [owned.id])
        #expect(reloaded.pendingNotes(ownerUserId: "B").isEmpty)
        #expect(reloaded.pendingNotes(ownerUserId: nil).isEmpty)
        let recaptured = try reloaded.capture(id: unowned.id, content: "Signed out", contentType: "text_entry", ownerUserId: "B")
        #expect(recaptured.ownerUserId == nil)
    }

    @Test func olderFilesDecodeWithoutAcquiringAnOwner() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let note = try store.capture(content: "Older file", contentType: "text_entry", ownerUserId: "A")
        let file = directory.appendingPathComponent("\(note.id.uuidString).json")
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        json.removeValue(forKey: "ownerUserId")
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        let reloaded = CapturedNoteStore(directory: directory)
        #expect(reloaded.note(id: note.id)?.ownerUserId == nil)
        #expect(reloaded.pendingNotes(ownerUserId: "A").isEmpty)
    }

    @Test func discardRemovesDiskAndMemoryAndIsIdempotent() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let note = try store.capture(content: "Delete me", contentType: "text_entry", ownerUserId: "A")
        try store.discard(id: note.id)
        #expect(store.note(id: note.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(note.id.uuidString).json").path))
        store.markSynced(id: note.id, rawContentId: "late-response")
        store.reload()
        #expect(store.notes.isEmpty)
        #expect(CapturedNoteStore(directory: directory).notes.isEmpty)
        try store.discard(id: note.id)
    }

    @Test func captureUsesTheAuthenticatedOwnerAndNeverBindsSignedOutNotes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let uploader = StubNoteUploader()
        let queue = NoteSyncQueue(store: store, uploader: uploader, observesLifecycle: false)
        let owned = try queue.capture(content: "Account A", contentType: "text_entry")
        uploader.canUpload = false
        let unowned = try queue.capture(content: "Signed out", contentType: "text_entry")
        #expect(owned.ownerUserId == "A")
        #expect(unowned.ownerUserId == nil)
        uploader.currentUserId = "B"
        uploader.canUpload = true
        await queue.drain()
        #expect(uploader.uploaded.isEmpty)
        #expect(queue.pendingCount == 0)
        uploader.currentUserId = "A"
        await queue.drain()
        #expect(uploader.uploaded == [owned.id])
        #expect(store.note(id: unowned.id)?.ownerUserId == nil)
        #expect(store.note(id: unowned.id)?.isPending == true)
    }

    @Test func drainRechecksAccountAfterEachUpload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let first = try store.capture(content: "First A", contentType: "text_entry", capturedAt: .distantPast, ownerUserId: "A")
        let second = try store.capture(content: "Second A", contentType: "text_entry", ownerUserId: "A")
        let other = try store.capture(content: "B", contentType: "text_entry", ownerUserId: "B")
        let uploader = StubNoteUploader()
        let queue = NoteSyncQueue(store: store, uploader: uploader, observesLifecycle: false)
        uploader.onUpload = { [weak uploader] in uploader?.currentUserId = "B" }
        await queue.drain()
        #expect(uploader.uploaded == [first.id])
        #expect(store.note(id: second.id)?.isPending == true)
        uploader.onUpload = nil
        await queue.drain()
        #expect(uploader.uploaded == [first.id, other.id])
        #expect(store.note(id: second.id)?.isPending == true)
    }

    @Test func drainSkipsNotesDeletedDuringAnEarlierUpload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CapturedNoteStore(directory: directory)
        let first = try store.capture(content: "First", contentType: "text_entry", capturedAt: .distantPast, ownerUserId: "A")
        let deleted = try store.capture(content: "Delete next", contentType: "text_entry", ownerUserId: "A")
        let uploader = StubNoteUploader()
        let queue = NoteSyncQueue(store: store, uploader: uploader, observesLifecycle: false)
        uploader.onUpload = { try store.discard(id: deleted.id) }
        await queue.drain()
        #expect(uploader.uploaded == [first.id])
        #expect(store.note(id: deleted.id) == nil)
    }
}

@MainActor
private final class StubNoteUploader: NoteUploading {
    var canUpload = true
    var currentUserId: String? = "A"
    var uploaded: [UUID] = []
    var onUpload: (() throws -> Void)?

    func uploadNote(clientUuid: UUID, contentType: String, content: String, contentDate: Date, metadata: [String: String]?) async throws {
        uploaded.append(clientUuid)
        try onUpload?()
    }
}
