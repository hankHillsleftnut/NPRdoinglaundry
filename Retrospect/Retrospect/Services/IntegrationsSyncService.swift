import BackgroundTasks
import Foundation

enum IntegrationBackgroundTasks {
    static let refreshIdentifier = "com.shauryanarang.Retrospect.integrations.refresh"
    static let processingIdentifier = "com.shauryanarang.Retrospect.integrations.processing"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            schedule()
            let work = Task { @MainActor in
                await IntegrationsSyncService.shared.syncNow()
                refreshTask.setTaskCompleted(success: !Task.isCancelled)
            }
            refreshTask.expirationHandler = { work.cancel() }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            schedule()
            let work = Task { @MainActor in
                await IntegrationsSyncService.shared.syncNow()
                processingTask.setTaskCompleted(success: !Task.isCancelled)
            }
            processingTask.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let refresh = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        refresh.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(refresh)

        let processing = BGProcessingTaskRequest(identifier: processingIdentifier)
        processing.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        processing.requiresNetworkConnectivity = true
        processing.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(processing)
    }
}

@MainActor
final class IntegrationsSyncService: ObservableObject {
    static let shared = IntegrationsSyncService()

    private let healthEnabledKey = "healthKitEnabled"
    private let healthSyncedDaysKey = "integrationSync.v2.healthkit.syncedDays"
    private let healthPendingDaysKey = "integrationSync.v2.healthkit.pendingDays"
    private let healthInitialSyncCompletedKey = "integrationSync.v2.healthkit.initialSyncCompleted"
    private var isSyncing = false

    private init() {}

    func syncIfNeeded() {
        Task { await syncNow() }
    }

    func syncNow() async {
        guard !isSyncing, RetrospectAPIClient.shared.isAuthenticated else { return }
        isSyncing = true
        defer {
            isSyncing = false
            IntegrationBackgroundTasks.schedule()
        }
        await syncHealthKitIfNeeded()
        await syncNativeSourcesIfNeeded()
    }

    private func syncHealthKitIfNeeded() async {
        guard UserDefaults.standard.bool(forKey: healthEnabledKey), HealthKitManager.shared.isHealthDataAvailable() else { return }

        let days = healthDaysToSync()
        guard !days.isEmpty else { return }

        var items: [[String: Any]] = []
        var dayKeys: [String] = []

        for day in days {
            guard let snapshot = await HealthKitManager.shared.fetchDailyHealthSnapshot(for: day) else { continue }
            let dayKey = Self.dayKey(for: snapshot.day)
            let occurredAt = Self.timestampKey(for: snapshot.day)
            let payload = snapshot.normalizedData.merging([
                "day": dayKey,
                "timezone": TimeZone.current.identifier,
                "aggregation_window": "calendar_day",
            ]) { current, _ in current }

            items.append([
                "providerObjectType": "daily_health_summary",
                "providerObjectId": dayKey,
                "payload": payload,
                "canonicalType": "health_daily_summary",
                "canonicalText": snapshot.canonicalText,
                "normalizedData": payload,
                "occurredAt": occurredAt,
                "parserVersion": "healthkit-v1",
                "normalizerVersion": "health-daily-v1",
                "contentType": "healthkit",
                "metadata": [
                    "source": "apple_health",
                    "sync_day": dayKey,
                    "sync_scope": "daily",
                ],
            ])
            dayKeys.append(dayKey)
        }

        guard !items.isEmpty else { return }

        do {
            let initialDone = UserDefaults.standard.bool(forKey: healthInitialSyncCompletedKey)
            try await RetrospectAPIClient.shared.uploadIntegrationItems(
                providerId: "healthkit",
                runType: initialDone ? "incremental_sync" : "initial_backfill",
                cursorBefore: ["last_synced_day": stringSet(forKey: healthSyncedDaysKey).sorted().last ?? ""],
                cursorAfter: ["last_synced_day": dayKeys.sorted().last ?? ""],
                items: items
            )
            for dayKey in dayKeys {
                markSynced(dayKey, syncedKey: healthSyncedDaysKey, pendingKey: healthPendingDaysKey)
            }
            UserDefaults.standard.set(true, forKey: healthInitialSyncCompletedKey)
            print("✅ HealthKit: Structured sync completed for \(dayKeys.count) day(s)")
        } catch {
            for dayKey in dayKeys {
                markPending(dayKey, pendingKey: healthPendingDaysKey)
            }
            print("❌ HealthKit: Structured sync failed - \(error.localizedDescription)")
        }
    }

    private func healthDaysToSync() -> [Date] {
        let calendar = Calendar.current
        let synced = stringSet(forKey: healthSyncedDaysKey)
        let pending = stringSet(forKey: healthPendingDaysKey)
        var dayKeys = pending

        for offset in 1 ... 30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            dayKeys.insert(Self.dayKey(for: day))
        }

        return dayKeys
            .subtracting(synced)
            .compactMap { Self.dayFormatter.date(from: $0) }
            .sorted()
    }

    private func syncNativeSourcesIfNeeded() async {
        let sources: [(id: String, connectedKey: String, sync: () async -> Bool)] = [
            ("calendar", "integration.calendar.connected", { await NativeSourcesManager.shared.syncCalendar() }),
            ("apple_music", "integration.appleMusic.connected", { await NativeSourcesManager.shared.syncAppleMusic() }),
            ("photos", "integration.photos.connected", { await NativeSourcesManager.shared.syncPhotos() }),
            ("contacts", "integration.contacts.connected", { await NativeSourcesManager.shared.syncContacts() }),
        ]

        for source in sources {
            guard UserDefaults.standard.bool(forKey: source.connectedKey) else { continue }
            let lastSyncKey = "integrationSync.v2.\(source.id).lastSuccessfulSync"
            if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date,
               Date().timeIntervalSince(lastSync) < 24 * 60 * 60 {
                continue
            }

            if await source.sync() {
                UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            }
        }
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
