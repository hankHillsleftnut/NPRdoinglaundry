import Foundation
import EventKit
import MediaPlayer
import Photos
import Contacts
import Network
import UIKit
import UniformTypeIdentifiers

private struct PhotoDayStats {
    var photos = 0
    var videos = 0
    var favorites = 0
    var withLocation = 0
}

private final class NetworkProbeContinuation: @unchecked Sendable {
    let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Bool) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        monitor.cancel()
        continuation.resume(returning: value)
    }
}

/// Captures native iOS sources and sends provider-shaped records through the
/// agent-owned integration pipeline.
@MainActor
final class NativeSourcesManager: ObservableObject {
    static let shared = NativeSourcesManager()
    private init() {}

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()
    private let maxPhotoOriginalUploadsPerSync = 12
    private let maxPhotoOriginalBytes = 25 * 1024 * 1024
    private let photoOriginalUploadedKey = "integrationSync.v2.photos.uploadedOriginalAssetIds"

    // MARK: - Public entry points

    /// Request permission + capture + sync a single source. Returns true if data was synced.
    @discardableResult
    func syncCalendar() async -> Bool {
        guard await requestCalendarAccess() else { return false }
        return await upload(calendarItems(), providerId: "calendar", label: "calendar")
    }

    @discardableResult
    func syncAppleMusic() async -> Bool {
        guard await requestMusicAccess() else { return false }
        return await upload(appleMusicItems(), providerId: "apple_music", label: "apple music")
    }

    @discardableResult
    func syncPhotos() async -> Bool {
        guard await requestPhotosAccess() else { return false }
        let originalCandidates = await canUploadPhotoOriginals() ? photoOriginalCandidates() : []
        let metadataItems = photoActivityItems() + photoOriginalMetadataItems(for: originalCandidates)
        let metadataUploaded = await upload(metadataItems, providerId: "photos", label: "photos")
        let originalsUploaded = metadataUploaded ? await uploadPhotoOriginals(originalCandidates) : 0
        return metadataUploaded || originalsUploaded > 0
    }

    @discardableResult
    func syncContacts() async -> Bool {
        guard await requestContactsAccess() else { return false }
        return await upload(contactItems(), providerId: "contacts", label: "contacts")
    }

    /// Connect everything the user has granted, in parallel.
    func syncAllGranted() async {
        async let c = syncCalendar()
        async let m = syncAppleMusic()
        async let p = syncPhotos()
        async let k = syncContacts()
        _ = await (c, m, p, k)
    }

    // MARK: - Upload

    private func upload(_ items: [[String: Any]], providerId: String, label: String) async -> Bool {
        guard !items.isEmpty else { return false }
        let initialKey = "integrationSync.v2.\(providerId).initialSyncCompleted"
        let initialDone = UserDefaults.standard.bool(forKey: initialKey)
        let capturedAt = ISO8601DateFormatter().string(from: Date())

        for start in stride(from: 0, to: items.count, by: 100) {
            let end = min(start + 100, items.count)
            do {
                try await RetrospectAPIClient.shared.uploadIntegrationItems(
                    providerId: providerId,
                    runType: initialDone ? "incremental_sync" : "initial_backfill",
                    cursorAfter: [
                        "captured_at": capturedAt,
                        "batch_end": end,
                        "total_items": items.count,
                    ],
                    items: Array(items[start..<end])
                )
            } catch {
                print("[NativeSources] \(label) structured sync failed: \(error)")
                return false
            }
        }
        UserDefaults.standard.set(true, forKey: initialKey)
        return true
    }

    // MARK: - Calendar + Reminders (EventKit)

    private func requestCalendarAccess() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, _ in cont.resume(returning: granted) }
            } else {
                eventStore.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }

    private func calendarItems() -> [[String: Any]] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let end = cal.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate).prefix(120)
        let iso = ISO8601DateFormatter()

        let records = events.map { event in
            let title = event.title ?? "Untitled event"
            let startAt = iso.string(from: event.startDate)
            let endAt = iso.string(from: event.endDate)
            let eventId = event.eventIdentifier ?? event.calendarItemIdentifier
            let location = event.location ?? ""
            let calendarTitle = event.calendar.title
            let attendeeRecords = (event.attendees ?? []).map { attendee in
                [
                    "name": attendee.name ?? "",
                    "identifier": attendee.url.absoluteString,
                    "role": attendee.participantRole.rawValue,
                    "status": attendee.participantStatus.rawValue,
                    "type": attendee.participantType.rawValue,
                ] as [String: Any]
            }
            let attendees = attendeeRecords.count
            let organizer = event.organizer.map {
                ["name": $0.name ?? "", "identifier": $0.url.absoluteString] as [String: Any]
            } ?? [:]
            let payload: [String: Any] = [
                "event_id": eventId,
                "title": title,
                "start_at": startAt,
                "end_at": endAt,
                "timezone": event.timeZone?.identifier ?? TimeZone.current.identifier,
                "is_all_day": event.isAllDay,
                "is_recurring": event.hasRecurrenceRules,
                "attendee_count": attendees,
                "attendees": attendeeRecords,
                "organizer": organizer,
                "location": location,
                "notes": event.notes ?? "",
                "url": event.url?.absoluteString ?? "",
                "calendar_id": event.calendar.calendarIdentifier,
                "calendar_title": calendarTitle,
                "status": event.status.rawValue,
            ]
            let canonical = [
                "Calendar event: \(title)",
                "Starts: \(startAt)",
                "Ends: \(endAt)",
                "Calendar: \(calendarTitle)",
                location.isEmpty ? nil : "Location: \(location)",
                attendees > 0 ? "Attendees: \(attendees)" : nil,
                event.notes.flatMap { $0.isEmpty ? nil : "Notes: \($0)" },
                event.hasRecurrenceRules ? "Recurring event" : nil,
            ].compactMap { $0 }.joined(separator: "\n")

            return [
                "providerObjectType": "calendar_event",
                "providerObjectId": eventId,
                "payload": payload,
                "canonicalType": "calendar_event",
                "canonicalText": canonical,
                "normalizedData": payload,
                "occurredAt": startAt,
                "providerCreatedAt": event.creationDate.map { iso.string(from: $0) } ?? startAt,
                "providerUpdatedAt": event.lastModifiedDate.map { iso.string(from: $0) } ?? startAt,
                "parserVersion": "eventkit-v1",
                "normalizerVersion": "calendar-event-v1",
                "contentType": "calendar",
                "metadata": ["source": "eventkit", "calendar_title": calendarTitle],
            ] as [String: Any]
        }
        return withAnalysisSummary(
            records,
            providerId: "calendar",
            title: "Calendar context from the last 30 days and next 30 days"
        )
    }

    // MARK: - Apple Music (MediaPlayer)

    private func requestMusicAccess() async -> Bool {
        await withCheckedContinuation { cont in
            MPMediaLibrary.requestAuthorization { status in cont.resume(returning: status == .authorized) }
        }
    }

    private func appleMusicItems() -> [[String: Any]] {
        let songs = (MPMediaQuery.songs().items ?? [])
        let selected = songs
            .filter { $0.playCount > 0 || $0.lastPlayedDate != nil }
            .sorted {
                ($0.lastPlayedDate ?? .distantPast, $0.playCount) >
                ($1.lastPlayedDate ?? .distantPast, $1.playCount)
            }
            .prefix(75)
        let iso = ISO8601DateFormatter()

        var records = selected.map { song in
            let title = song.title ?? "Unknown track"
            let artist = song.artist ?? "Unknown artist"
            let album = song.albumTitle ?? ""
            let genre = song.genre ?? ""
            let objectId = String(song.persistentID)
            let payload: [String: Any] = [
                "persistent_id": objectId,
                "title": title,
                "artist": artist,
                "album": album,
                "genre": genre,
                "play_count": song.playCount,
                "skip_count": song.skipCount,
                "rating": song.rating,
                "last_played_at": song.lastPlayedDate.map { iso.string(from: $0) } ?? "",
                "is_cloud_item": song.isCloudItem,
                "store_id": song.playbackStoreID,
            ]
            var item: [String: Any] = [
                "providerObjectType": "library_track",
                "providerObjectId": objectId,
                "payload": payload,
                "canonicalType": "music_preference",
                "canonicalText": "\(title) by \(artist)\nAlbum: \(album)\nGenre: \(genre)\nPlay count: \(song.playCount)",
                "normalizedData": payload,
                "parserVersion": "media-library-v1",
                "normalizerVersion": "music-preference-v1",
                "contentType": "apple_music",
                "metadata": ["source": "apple_music_library"],
            ]
            if let lastPlayedDate = song.lastPlayedDate {
                item["occurredAt"] = iso.string(from: lastPlayedDate)
            }
            return item
        }
        let playlists = (MPMediaQuery.playlists().collections ?? []).prefix(100).map { playlist -> [String: Any] in
            let name = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Untitled playlist"
            let persistentId = playlist.persistentID
            let payload: [String: Any] = [
                "persistent_id": String(persistentId),
                "name": name,
                "track_count": playlist.count,
                "representative_tracks": playlist.items.prefix(30).map {
                    [
                        "title": $0.title ?? "",
                        "artist": $0.artist ?? "",
                        "album": $0.albumTitle ?? "",
                    ]
                },
            ]
            return [
                "providerObjectType": "playlist",
                "providerObjectId": String(persistentId),
                "payload": payload,
                "canonicalType": "music_preference",
                "canonicalText": "Apple Music playlist: \(name)\nTracks: \(playlist.count)\n\(playlist.items.prefix(30).map { "\($0.title ?? "Unknown") by \($0.artist ?? "Unknown")" }.joined(separator: "\n"))",
                "normalizedData": payload,
                "parserVersion": "media-library-v2",
                "normalizerVersion": "music-playlist-v1",
                "contentType": "apple_music",
                "metadata": ["source": "apple_music_library", "relationship": "playlist"],
            ]
        }
        records.append(contentsOf: playlists)
        return withAnalysisSummary(
            records,
            providerId: "apple_music",
            title: "Apple Music listening and library preference context"
        )
    }

    // MARK: - Photos

    private func requestPhotosAccess() async -> Bool {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    private func photoActivityItems() -> [[String: Any]] {
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -90, to: Date()) ?? Date()

        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@", since as NSDate)
        let assets = PHAsset.fetchAssets(with: opts)

        var days: [String: PhotoDayStats] = [:]
        assets.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            let day = Self.dayKey(for: creationDate)
            var stats = days[day] ?? PhotoDayStats()
            if asset.mediaType == .video { stats.videos += 1 } else { stats.photos += 1 }
            if asset.isFavorite { stats.favorites += 1 }
            if asset.location != nil { stats.withLocation += 1 }
            days[day] = stats
        }
        let records: [[String: Any]] = days.sorted { $0.key > $1.key }.compactMap { entry -> [String: Any]? in
            let day = entry.key
            let stats = entry.value
            guard let occurred = Self.dayFormatter.date(from: day) else { return nil }
            let payload: [String: Any] = [
                "day": day,
                "photo_count": stats.photos,
                "video_count": stats.videos,
                "favorite_count": stats.favorites,
                "assets_with_location_count": stats.withLocation,
                "content_analysis_performed": false,
            ]
            return [
                "providerObjectType": "photo_activity_day",
                "providerObjectId": day,
                "payload": payload,
                "canonicalType": "photo_activity_day",
                "canonicalText": "Photo-library activity for \(day): \(stats.photos) photos, \(stats.videos) videos, \(stats.favorites) favorites, \(stats.withLocation) assets with location metadata.",
                "normalizedData": payload,
                "occurredAt": ISO8601DateFormatter().string(from: occurred),
                "parserVersion": "photos-metadata-v1",
                "normalizerVersion": "photo-activity-day-v1",
                "contentType": "photos",
                "metadata": ["source": "photos_metadata", "image_content_analyzed": false],
            ] as [String: Any]
        }
        return withAnalysisSummary(
            records,
            providerId: "photos",
            title: "Photo-library activity context from the last 90 days"
        )
    }

    private func canUploadPhotoOriginals() async -> Bool {
        if UserDefaults.standard.object(forKey: "integration.photos.uploadOriginalMedia") == nil {
            UserDefaults.standard.set(false, forKey: "integration.photos.uploadOriginalMedia")
        }
        guard UserDefaults.standard.bool(forKey: "integration.photos.uploadOriginalMedia") else { return false }
        return await canUploadLargeOriginalMedia()
    }

    private func uploadPhotoOriginals(_ candidates: [PHAsset]) async -> Int {
        guard !candidates.isEmpty else { return 0 }

        var uploadedIds = stringSet(forKey: photoOriginalUploadedKey)
        var uploadedCount = 0

        for asset in candidates {
            guard !uploadedIds.contains(asset.localIdentifier) else { continue }
            guard let original = await imageOriginalData(for: asset) else { continue }
            guard original.data.count <= maxPhotoOriginalBytes else { continue }

            do {
                try await RetrospectAPIClient.shared.uploadIntegrationAsset(
                    providerId: "photos",
                    providerObjectType: "photo_asset",
                    providerObjectId: asset.localIdentifier,
                    contentType: original.contentType,
                    data: original.data
                )
                uploadedIds.insert(asset.localIdentifier)
                save(uploadedIds, forKey: photoOriginalUploadedKey)
                uploadedCount += 1
            } catch {
                print("[NativeSources] photo original upload failed: \(error)")
            }
        }

        return uploadedCount
    }

    private func photoOriginalMetadataItems(for assets: [PHAsset]) -> [[String: Any]] {
        let iso = ISO8601DateFormatter()
        return assets.compactMap { asset -> [String: Any]? in
            guard let creationDate = asset.creationDate else { return nil }
            let occurredAt = iso.string(from: creationDate)
            var payload: [String: Any] = [
                "local_identifier": asset.localIdentifier,
                "created_at": occurredAt,
                "modified_at": asset.modificationDate.map { iso.string(from: $0) } ?? "",
                "pixel_width": asset.pixelWidth,
                "pixel_height": asset.pixelHeight,
                "is_favorite": asset.isFavorite,
                "media_subtypes": asset.mediaSubtypes.rawValue,
                "original_media_upload_requested": true,
            ]
            if let location = asset.location {
                payload["latitude"] = location.coordinate.latitude
                payload["longitude"] = location.coordinate.longitude
                payload["altitude"] = location.altitude
                payload["horizontal_accuracy"] = location.horizontalAccuracy
            }
            return [
                "providerObjectType": "photo_asset",
                "providerObjectId": asset.localIdentifier,
                "payload": payload,
                "canonicalType": "photo_asset",
                "canonicalText": "Photo asset from \(occurredAt). Favorite: \(asset.isFavorite). Dimensions: \(asset.pixelWidth)x\(asset.pixelHeight). Location metadata: \(asset.location == nil ? "not available" : "available").",
                "normalizedData": payload,
                "occurredAt": occurredAt,
                "providerUpdatedAt": asset.modificationDate.map { iso.string(from: $0) } ?? occurredAt,
                "analysisEligible": false,
                "parserVersion": "photos-asset-v1",
                "normalizerVersion": "photo-asset-v1",
                "contentType": "photos",
                "metadata": ["source": "photos_original_asset", "original_media_upload_requested": true],
            ] as [String: Any]
        }
    }

    private func photoOriginalCandidates() -> [PHAsset] {
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let uploadedIds = stringSet(forKey: photoOriginalUploadedKey)
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@ AND mediaType == %d", since as NSDate, PHAssetMediaType.image.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: opts)
        var candidates: [PHAsset] = []
        assets.enumerateObjects { asset, _, stop in
            guard !uploadedIds.contains(asset.localIdentifier) else { return }
            candidates.append(asset)
            if candidates.count >= self.maxPhotoOriginalUploadsPerSync * 4 {
                stop.pointee = true
            }
        }
        return Array(candidates.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }.prefix(maxPhotoOriginalUploadsPerSync))
    }

    private func imageOriginalData(for asset: PHAsset) async -> (data: Data, contentType: String)? {
        await withCheckedContinuation { cont in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    cont.resume(returning: nil)
                    return
                }
                guard let data else {
                    cont.resume(returning: nil)
                    return
                }
                let contentType = uti.flatMap { UTType($0)?.preferredMIMEType } ?? "application/octet-stream"
                cont.resume(returning: (data, contentType))
            }
        }
    }

    private func canUploadLargeOriginalMedia() async -> Bool {
        let allowCellular = UserDefaults.standard.bool(forKey: "integration.photos.uploadOriginalsOnCellular")
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryState = UIDevice.current.batteryState
        let hasPower = batteryState == .charging || batteryState == .full
        guard hasPower else { return false }
        if allowCellular { return true }
        return await isUnmeteredNetworkAvailable()
    }

    private func isUnmeteredNetworkAvailable() async -> Bool {
        await withCheckedContinuation { cont in
            let probe = NetworkProbeContinuation(cont)
            let queue = DispatchQueue(label: "retrospect.photos.network")

            probe.monitor.pathUpdateHandler = { path in
                probe.resume(path.status == .satisfied && !path.isExpensive && !path.isConstrained)
            }
            probe.monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 2) {
                probe.resume(false)
            }
        }
    }

    // MARK: - Contacts

    private func requestContactsAccess() async -> Bool {
        await withCheckedContinuation { cont in
            contactStore.requestAccess(for: .contacts) { granted, _ in cont.resume(returning: granted) }
        }
    }

    private func contactItems() -> [[String: Any]] {
        let keys = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactOrganizationNameKey, CNContactRelationsKey,
            CNContactEmailAddressesKey, CNContactPhoneNumbersKey,
            CNContactSocialProfilesKey, CNContactJobTitleKey,
            CNContactDepartmentNameKey, CNContactBirthdayKey,
        ] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var items: [[String: Any]] = []
        do {
            try contactStore.enumerateContacts(with: request) { contact, stop in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let organization = contact.organizationName
                guard !name.isEmpty || !organization.isEmpty else { return }
                let relationships = contact.contactRelations
                    .map { $0.label ?? $0.value.name }
                    .filter { !$0.isEmpty }
                let emails = contact.emailAddresses.map { String($0.value) }
                let phones = contact.phoneNumbers.map { $0.value.stringValue }
                let socialProfiles = contact.socialProfiles.map {
                    [
                        "service": $0.value.service,
                        "username": $0.value.username,
                        "url": $0.value.urlString,
                    ]
                }
                let birthday = contact.birthday.flatMap { Calendar.current.date(from: $0) }
                    .map { ISO8601DateFormatter().string(from: $0) } ?? ""
                let payload: [String: Any] = [
                    "contact_id": contact.identifier,
                    "display_name": name,
                    "organization": organization,
                    "job_title": contact.jobTitle,
                    "department": contact.departmentName,
                    "relationship_labels": relationships,
                    "email_addresses": emails,
                    "phone_numbers": phones,
                    "social_profiles": socialProfiles,
                    "birthday": birthday,
                ]
                items.append([
                    "providerObjectType": "contact_record",
                    "providerObjectId": contact.identifier,
                    "payload": payload,
                    "canonicalType": "person_record",
                    "canonicalText": """
                    Contact: \(name.isEmpty ? organization : name)
                    Organization: \(organization)
                    Role: \(contact.jobTitle) \(contact.departmentName)
                    Relationship labels: \(relationships.joined(separator: ", "))
                    Email addresses: \(emails.joined(separator: ", "))
                    Phone numbers: \(phones.joined(separator: ", "))
                    """,
                    "normalizedData": payload,
                    "parserVersion": "contacts-v1",
                    "normalizerVersion": "person-record-v2",
                    "contentType": "contacts",
                    "metadata": ["source": "contacts"],
                ])
                if items.count >= 300 { stop.pointee = true }
            }
        } catch {
            print("[NativeSources] contacts read failed: \(error)")
        }
        return withAnalysisSummary(
            items,
            providerId: "contacts",
            title: "Contact-directory relationship and organization context"
        )
    }

    private func withAnalysisSummary(
        _ records: [[String: Any]],
        providerId: String,
        title: String
    ) -> [[String: Any]] {
        guard !records.isEmpty else { return [] }
        let canonicalRecords = records.compactMap { $0["canonicalText"] as? String }
        let selectedText = canonicalRecords.prefix(80).joined(separator: "\n\n")
        let summaryText = "\(title)\n\n\(String(selectedText.prefix(3_500)))"
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        let summaryPayload: [String: Any] = [
            "provider_id": providerId,
            "record_count": records.count,
            "records_in_summary": min(canonicalRecords.count, 80),
            "captured_at": capturedAt,
        ]
        let summary: [String: Any] = [
            "providerObjectType": "analysis_summary",
            "providerObjectId": "rolling-summary-v1",
            "payload": summaryPayload,
            "canonicalType": "\(providerId)_context_summary",
            "canonicalText": summaryText,
            "normalizedData": summaryPayload,
            "occurredAt": capturedAt,
            "analysisEligible": true,
            "parserVersion": "\(providerId)-summary-v1",
            "normalizerVersion": "\(providerId)-context-summary-v1",
            "contentType": providerId,
            "metadata": ["source": "native_ios", "synthetic_analysis_summary": true],
        ]
        let storedRecords = records.map { record -> [String: Any] in
            var result = record
            result["analysisEligible"] = false
            return result
        }
        return [summary] + storedRecords
    }

    private func stringSet(forKey key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func save(_ set: Set<String>, forKey key: String) {
        UserDefaults.standard.set(Array(set).sorted(), forKey: key)
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
}
