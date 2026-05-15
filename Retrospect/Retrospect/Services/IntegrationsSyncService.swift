import Foundation

@MainActor
final class IntegrationsSyncService: ObservableObject {
    static let shared = IntegrationsSyncService()

    private let healthEnabledKey = "healthKitEnabled"
    private let healthSyncedDaysKey = "integrationSync.healthkit.syncedDays"
    private let healthPendingDaysKey = "integrationSync.healthkit.pendingDays"
    private let docsInitialSyncCompletedKey = "integrationSync.googleDocs.initialSyncCompleted"
    private let docsSyncedChunksKey = "integrationSync.googleDocs.syncedChunks"
    private let docsPendingChunksKey = "integrationSync.googleDocs.pendingChunks"
    private let docsChunkSize = 10_000
    private var isSyncing = false

    private init() {}

    func syncIfNeeded() {
        guard !isSyncing else { return }
        guard RetrospectAPIClient.shared.isAuthenticated else {
            print("⚠️ Integrations sync skipped - not authenticated")
            return
        }

        isSyncing = true
        Task {
            await syncHealthKitIfNeeded()
            await syncGoogleDocsIfNeeded()
            await MainActor.run {
                self.isSyncing = false
            }
        }
    }

    private func syncHealthKitIfNeeded() async {
        guard UserDefaults.standard.bool(forKey: healthEnabledKey) else { return }
        guard HealthKitManager.shared.isHealthDataAvailable() else { return }

        let days = healthDaysToSync()
        guard !days.isEmpty else { return }

        for day in days {
            let summary = await HealthKitManager.shared.fetchDailyHealthSummary(for: day)
            guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let dayKey = Self.dayKey(for: day)
            do {
                try await RetrospectAPIClient.shared.uploadContent(
                    contentType: "healthkit",
                    content: summary,
                    contentDate: Calendar.current.startOfDay(for: day),
                    metadata: [
                        "source": "apple_health",
                        "sync_day": dayKey,
                        "sync_scope": "daily"
                    ]
                )
                markSynced(dayKey, syncedKey: healthSyncedDaysKey, pendingKey: healthPendingDaysKey)
                print("✅ HealthKit: Synced \(dayKey)")
            } catch {
                markPending(dayKey, pendingKey: healthPendingDaysKey)
                print("❌ HealthKit: Failed to sync \(dayKey) - \(error.localizedDescription)")
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func healthDaysToSync() -> [Date] {
        let calendar = Calendar.current
        let synced = stringSet(forKey: healthSyncedDaysKey)
        let pending = stringSet(forKey: healthPendingDaysKey)
        var dayKeys = pending

        for offset in 1...30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            dayKeys.insert(Self.dayKey(for: day))
        }

        return dayKeys
            .subtracting(synced)
            .compactMap { Self.dayFormatter.date(from: $0) }
            .sorted()
    }

    private func syncGoogleDocsIfNeeded() async {
        let service = GoogleDocsService.shared
        guard service.isGoogleDocsEnabled else { return }
        guard service.isConnected else { return }

        let initialDone = UserDefaults.standard.bool(forKey: docsInitialSyncCompletedKey)
        let windowDays = initialDone ? 7 : 30

        do {
            let docs = try await service.fetchDocumentsModifiedWithin(days: windowDays)
            var allUploadsSucceeded = true

            for doc in docs {
                do {
                    let docSucceeded = try await syncGoogleDoc(doc, service: service)
                    allUploadsSucceeded = allUploadsSucceeded && docSucceeded
                } catch {
                    allUploadsSucceeded = false
                    print("❌ Google Docs: Failed to sync \(doc.name) - \(error.localizedDescription)")
                }
            }

            if !initialDone && allUploadsSucceeded {
                UserDefaults.standard.set(true, forKey: docsInitialSyncCompletedKey)
            }
        } catch {
            print("❌ Google Docs: Sync failed - \(error.localizedDescription)")
        }
    }

    private func syncGoogleDoc(_ doc: GoogleDocsModel, service: GoogleDocsService) async throws -> Bool {
        let content = try await service.fetchContentForDocument(doc.id)
        let chunks = Self.chunk(content, size: docsChunkSize)
        let synced = stringSet(forKey: docsSyncedChunksKey)
        var allChunksSucceeded = true

        for index in chunks.indices {
            let chunkKey = "\(doc.id):\(Self.timestampKey(for: doc.modifiedTime)):\(index + 1)"
            guard !synced.contains(chunkKey) else { continue }

            do {
                try await RetrospectAPIClient.shared.uploadContent(
                    contentType: "google_docs",
                    content: chunks[index],
                    contentDate: doc.modifiedTime,
                    metadata: [
                        "source": "google_docs",
                        "document_id": doc.id,
                        "title": doc.name,
                        "created_time": ISO8601DateFormatter().string(from: doc.createdTime),
                        "modified_time": ISO8601DateFormatter().string(from: doc.modifiedTime),
                        "chunk_index": index + 1,
                        "chunk_count": chunks.count,
                        "chunk_size": docsChunkSize,
                        "is_chunked": chunks.count > 1
                    ]
                )
                markSynced(chunkKey, syncedKey: docsSyncedChunksKey, pendingKey: docsPendingChunksKey)
                print("✅ Google Docs: Synced \(doc.name) chunk \(index + 1)/\(chunks.count)")
            } catch {
                allChunksSucceeded = false
                markPending(chunkKey, pendingKey: docsPendingChunksKey)
                print("❌ Google Docs: Failed \(doc.name) chunk \(index + 1) - \(error.localizedDescription)")
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return allChunksSucceeded
    }

    private func stringSet(forKey key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func save(_ set: Set<String>, forKey key: String) {
        UserDefaults.standard.set(Array(set).sorted(), forKey: key)
    }

    private func markPending(_ value: String, pendingKey: String) {
        var pending = stringSet(forKey: pendingKey)
        pending.insert(value)
        save(pending, forKey: pendingKey)
    }

    private func markSynced(_ value: String, syncedKey: String, pendingKey: String) {
        var synced = stringSet(forKey: syncedKey)
        synced.insert(value)
        save(synced, forKey: syncedKey)

        var pending = stringSet(forKey: pendingKey)
        pending.remove(value)
        save(pending, forKey: pendingKey)
    }

    private static func chunk(_ text: String, size: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var start = text.startIndex

        while start < text.endIndex {
            let end = text.index(start, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))
            start = end
        }

        return chunks
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func timestampKey(for date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
