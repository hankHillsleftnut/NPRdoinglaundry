import Combine
import Foundation
import UIKit

/// Drains locally captured notes to the backend, forever if it has to.
///
/// The contract this type exists to keep: once `capture` returns, the note is on
/// disk. Owned notes are uploaded only while their account is signed in;
/// signed-out captures remain unowned and local. Explicit deletion removes notes
/// from the store, while sync outcomes always preserve the local copy.
///
/// Safe to retry because the backend upserts on (user_id, client_uuid), so a note
/// that was actually stored but whose response never arrived collapses onto the
/// same row on the next attempt.
@MainActor
final class NoteSyncQueue: ObservableObject {
    static let shared = NoteSyncQueue()

    /// Number of notes still owed to the server. Useful for a subtle "saving…"
    /// affordance; the user should never have to care, but honesty is cheap.
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isDraining: Bool = false

    // MARK: - Configuration

    /// First retry delay. Each subsequent attempt doubles it, up to `maximumBackoff`.
    private let baseBackoff: TimeInterval = 5
    private let maximumBackoff: TimeInterval = 300
    /// Safety net when the drain parks on auth: re-check even if no auth change
    /// is ever published (a token can expire without a sign-out event).
    private let authRecheckInterval: TimeInterval = 60

    private let store: CapturedNoteStore
    private var uploader: NoteUploading
    private var retryTask: Task<Void, Never>?
    /// Set when a drain is asked for while one is already running, so the running
    /// drain does another pass instead of the request being dropped.
    private var drainRequested = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    // Defaults are resolved in the body rather than in the parameter list:
    // default argument expressions are evaluated nonisolated, which cannot touch
    // a @MainActor singleton (an error under the Swift 6 language mode).
    init(store: CapturedNoteStore? = nil, uploader: NoteUploading? = nil, observesLifecycle: Bool = true) {
        self.store = store ?? CapturedNoteStore.shared
        self.uploader = uploader ?? RetrospectAPIClient.shared
        if observesLifecycle { observeLifecycle() }
        refreshPendingCount()
    }

    /// Call once at launch. Picks up anything left pending by a previous session
    /// and gives blocked notes a fresh attempt on the new build.
    static func bootstrap() {
        shared.store.reload()
        shared.store.requeueBlockedNotes()
        shared.refreshPendingCount()
        shared.drainSoon()
    }

    /// Swap the transport. Test seam only — production uses `RetrospectAPIClient`.
    func configure(uploader: NoteUploading) {
        self.uploader = uploader
    }

    // MARK: - Public API

    /// Local-first write. The note hits disk before the network is touched, so a
    /// crash, a kill, or a dead connection immediately after this call still
    /// leaves the note captured.
    @discardableResult
    func capture(
        id: UUID = UUID(),
        content: String,
        contentType: String,
        capturedAt: Date = Date(),
        metadata: [String: String]? = nil
    ) throws -> CapturedNote {
        let note = try store.capture(
            id: id,
            content: content,
            contentType: contentType,
            capturedAt: capturedAt,
            metadata: metadata,
            ownerUserId: uploader.canUpload ? uploader.currentUserId : nil
        )
        refreshPendingCount()
        drainSoon()
        return note
    }

    /// Kick the queue without waiting for it. Cheap and idempotent — a drain
    /// already in flight simply ignores this.
    func drainSoon() {
        Task { await drain() }
    }

    /// Re-read the store from disk, then drain. Used on the triggers where the
    /// on-disk set may be larger than what memory knows about.
    func reloadAndDrain() {
        store.reload()
        refreshPendingCount()
        drainSoon()
    }

    // MARK: - Drain Loop

    func drain() async {
        // Coalesce rather than drop. A note captured while a drain is in flight
        // would otherwise get no attempt and no scheduled retry, and with a 480s
        // request timeout that window is not small.
        guard !isDraining else {
            drainRequested = true
            return
        }

        guard uploader.canUpload else {
            // Signed out. Notes are untouched and unpenalised; the auth observer
            // below restarts the drain the moment a session exists.
            if store.pendingCount > 0 {
                print("⚠️ Note sync paused: not signed in (\(store.pendingCount) pending)")
                scheduleRetry(after: authRecheckInterval)
            }
            return
        }

        isDraining = true
        defer {
            isDraining = false
            refreshPendingCount()
        }

        var nextReadyAt: Date?

        // Re-read the pending list on every pass so notes captured mid-drain are
        // picked up by this run instead of waiting for an external trigger.
        repeat {
            drainRequested = false
            let now = Date()

            for note in store.pendingNotes(ownerUserId: uploader.currentUserId) {
                // An earlier upload can suspend while an entry is deleted or the
                // account changes. Recheck the live store and auth before sending.
                guard uploader.canUpload,
                      let currentUserId = uploader.currentUserId,
                      let current = store.note(id: note.id),
                      current.isPending,
                      current.ownerUserId == currentUserId else { continue }

                let readyAt = nextAttemptDate(for: note)
                guard readyAt <= now else {
                    nextReadyAt = [nextReadyAt, readyAt].compactMap { $0 }.min()
                    continue
                }

                do {
                    try await uploader.uploadNote(
                        clientUuid: note.id,
                        contentType: note.contentType,
                        content: note.content,
                        contentDate: note.capturedAt,
                        metadata: note.metadata
                    )
                    store.markSynced(id: note.id, rawContentId: nil)
                    print("✅ Synced note \(note.id)")
                    continue
                } catch {
                    let disposition = resolvedDisposition(for: error)

                    switch disposition {
                    case .waitForAuth:
                        store.markWaitingForAuth(id: note.id, error: error)
                        print("⚠️ Note sync paused mid-drain: \(error.localizedDescription)")
                        scheduleRetry(after: authRecheckInterval)
                        return

                    case .blocked:
                        store.markBlocked(id: note.id, error: error)

                    case .retry:
                        store.markAttemptFailed(id: note.id, error: error)
                        print("🔄 Note \(note.id) will retry: \(error.localizedDescription)")
                    }

                    if let updated = store.note(id: note.id), updated.isPending {
                        let retryAt = nextAttemptDate(for: updated)
                        nextReadyAt = [nextReadyAt, retryAt].compactMap { $0 }.min()
                    }
                }
            }
        } while drainRequested

        if let nextReadyAt {
            scheduleRetry(after: max(nextReadyAt.timeIntervalSinceNow, 1))
        }
    }

    /// Second-guess an auth classification when the client still holds a usable
    /// token. Client and server disagreeing is not a reason to stall every note
    /// behind this one — treat it as a normal retryable failure so backoff grows
    /// and the rest of the queue keeps moving.
    private func resolvedDisposition(for error: Error) -> NoteUploadDisposition {
        let disposition = NoteUploadDisposition.classify(error)
        guard disposition == .waitForAuth, uploader.canUpload else {
            return disposition
        }
        return .retry
    }

    /// Exponential backoff with a little jitter, so a batch that failed together
    /// does not come back as a thundering herd. Capped rather than exhausted —
    /// the queue slows down but never gives up.
    private func nextAttemptDate(for note: CapturedNote) -> Date {
        guard note.attemptCount > 0, let lastAttemptAt = note.lastAttemptAt else {
            return .distantPast
        }

        let exponential = baseBackoff * pow(2, Double(note.attemptCount - 1))
        let capped = min(exponential, maximumBackoff)
        let jitter = capped * Double.random(in: 0...0.2)
        return lastAttemptAt.addingTimeInterval(capped + jitter)
    }

    private func scheduleRetry(after delay: TimeInterval) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(delay, 1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.drain()
        }
    }

    private func refreshPendingCount() {
        pendingCount = uploader.canUpload
            ? store.pendingNotes(ownerUserId: uploader.currentUserId).count
            : 0
    }

    // MARK: - Lifecycle Triggers

    private func observeLifecycle() {
        store.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPendingCount() }
            .store(in: &cancellables)

        // Coming back to the foreground is the most reliable moment to retry:
        // connectivity has usually recovered and the app has fresh runtime.
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.reloadAndDrain() }
            .store(in: &cancellables)

        // A launch before the device's first unlock reads nothing off disk. This
        // is the moment the notes actually become readable, so re-read before
        // concluding there is nothing to send.
        NotificationCenter.default
            .publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
            .sink { [weak self] _ in self?.reloadAndDrain() }
            .store(in: &cancellables)

        // Account changes release only work owned by the active account.
        Publishers.CombineLatest(
            RetrospectAPIClient.shared.$isAuthenticated,
            RetrospectAPIClient.shared.$currentUserId
        )
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPendingCount()
                self?.drainSoon()
            }
            .store(in: &cancellables)
    }
}
