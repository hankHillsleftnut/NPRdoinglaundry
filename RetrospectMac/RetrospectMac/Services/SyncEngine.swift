import Foundation
import Combine

/// Ties the local store, session monitor, and backend together.
///
/// Reliability model (decided with the user):
///  • Local-first autosave always (handled by `JournalStore`) — words are never lost.
///  • An **outbox** flushes unsynced entries to `POST /content` with retry/backoff, so a
///    cold-starting / 429-ing backend never costs you writing.
///  • Flush + synthesis run only at **session end** (10 min idle) — never mid-session.
///  • **Synthesis** runs at most **once per calendar day**, and only if there is **new
///    writing** since the last synthesis.
@MainActor
final class SyncEngine: ObservableObject {
    @Published private(set) var status: String = ""
    @Published private(set) var isFlushing = false

    private let store: JournalStore
    private let session: SessionMonitor
    private let api = RetrospectAPI.shared

    private var cancellables = Set<AnyCancellable>()
    private var retryTask: Task<Void, Never>?
    private var retryDelay: TimeInterval = 4

    private let lastSynthesisKey = "retrospect.lastSynthesisDate"

    init(store: JournalStore, session: SessionMonitor) {
        self.store = store
        self.session = session

        session.sessionDidEnd
            .sink { [weak self] in self?.onSessionEnd() }
            .store(in: &cancellables)
    }

    private var lastSynthesisDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSynthesisKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSynthesisKey) }
    }

    /// Called on app termination / window close to flush in-progress work.
    func flushNow() {
        session.endSessionNow() // triggers onSessionEnd synchronously via the subject
    }

    private func onSessionEnd() {
        Task { await flushAndMaybeSynthesize() }
    }

    private func flushAndMaybeSynthesize() async {
        await flushOutbox()
        await maybeSynthesize()
    }

    // MARK: - Outbox

    private func flushOutbox() async {
        guard api.isAuthenticated else {
            status = "Saved locally — sign in to sync"
            return
        }
        let pending = store.unsyncedEntries()
        guard !pending.isEmpty else { status = "All synced"; return }

        isFlushing = true
        defer { isFlushing = false }
        var failed = false

        for entry in pending {
            do {
                try await api.uploadContent(
                    contentType: "journal",
                    content: entry.plainText,
                    contentDate: entry.createdAt,
                    metadata: ["source": "macos_journal", "entryId": entry.id.uuidString]
                )
                store.markSynced(id: entry.id, contentHash: entry.markdown.hashValue)
            } catch {
                failed = true
                status = "Sync deferred: \(error.localizedDescription)"
                break
            }
        }

        if failed {
            scheduleRetry()
        } else {
            retryDelay = 4
            status = "Synced \(pending.count) " + (pending.count == 1 ? "entry" : "entries")
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 300) // cap backoff at 5 min
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await self.flushOutbox()
        }
    }

    // MARK: - Synthesis (daily, only if new writing)

    private func maybeSynthesize() async {
        guard api.isAuthenticated else { return }

        let cal = Calendar.current
        if let last = lastSynthesisDate, cal.isDateInToday(last) {
            return // already synthesized today
        }

        // New writing since the last synthesis?
        let cutoff = lastSynthesisDate ?? .distantPast
        let hasNewWriting = store.entries.contains { !$0.isEmpty && $0.updatedAt > cutoff }
        guard hasNewWriting else { return }

        do {
            try await api.requestSynthesis(daysSince: 1)
            lastSynthesisDate = Date()
            status = "Synthesis started"
        } catch {
            // Tolerated: content is already uploaded; synthesis can run on the next session end.
            status = "Synced — synthesis will retry"
        }
    }
}
