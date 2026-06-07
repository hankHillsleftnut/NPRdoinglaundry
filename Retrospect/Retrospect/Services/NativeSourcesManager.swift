import Foundation
import EventKit
import MediaPlayer
import Photos
import Contacts

/// Captures the native iOS data sources on-device, serializes each to a compact
/// privacy-respecting TEXT summary (never raw files), and syncs it through the
/// existing pipeline: uploadContent(contentType:) -> POST /content -> agent ingest.
///
/// Each source maps to a backend content_type the pipeline now accepts:
///   calendar (events + reminders), apple_music, photos, contacts.
@MainActor
final class NativeSourcesManager: ObservableObject {
    static let shared = NativeSourcesManager()
    private init() {}

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    // MARK: - Public entry points

    /// Request permission + capture + sync a single source. Returns true if data was synced.
    @discardableResult
    func syncCalendar() async -> Bool {
        guard await requestCalendarAccess() else { return false }
        let text = readCalendarAndReminders()
        return await upload(text, contentType: "calendar", label: "calendar")
    }

    @discardableResult
    func syncAppleMusic() async -> Bool {
        guard await requestMusicAccess() else { return false }
        let text = readAppleMusic()
        return await upload(text, contentType: "apple_music", label: "apple music")
    }

    @discardableResult
    func syncPhotos() async -> Bool {
        guard await requestPhotosAccess() else { return false }
        let text = readPhotosMetadata()
        return await upload(text, contentType: "photos", label: "photos")
    }

    @discardableResult
    func syncContacts() async -> Bool {
        guard await requestContactsAccess() else { return false }
        let text = readContacts()
        return await upload(text, contentType: "contacts", label: "contacts")
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

    private func upload(_ text: String, contentType: String, label: String) async -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            try await RetrospectAPIClient.shared.uploadContent(
                contentType: contentType,
                content: text,
                contentDate: Date(),
                metadata: ["source": "native_ios", "captured_at": ISO8601DateFormatter().string(from: Date())]
            )
            return true
        } catch {
            print("[NativeSources] \(label) sync failed: \(error)")
            return false
        }
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

    private func readCalendarAndReminders() -> String {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let end = cal.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate).prefix(120)

        let fmt = DateFormatter()
        fmt.dateFormat = "EEE MMM d, h:mma"

        let eventLines = events.map { e -> String in
            let attendees = e.attendees?.count ?? 0
            let recur = e.hasRecurrenceRules ? " [recurring]" : ""
            let who = attendees > 0 ? " (\(attendees) attendee\(attendees == 1 ? "" : "s"))" : ""
            return "- \(fmt.string(from: e.startDate)): \(e.title ?? "Untitled")\(who)\(recur)"
        }

        return """
        # Calendar (last 30 + next 30 days)
        \(eventLines.isEmpty ? "(no events)" : eventLines.joined(separator: "\n"))
        """
    }

    // MARK: - Apple Music (MediaPlayer)

    private func requestMusicAccess() async -> Bool {
        await withCheckedContinuation { cont in
            MPMediaLibrary.requestAuthorization { status in cont.resume(returning: status == .authorized) }
        }
    }

    private func readAppleMusic() -> String {
        let songs = (MPMediaQuery.songs().items ?? [])

        let mostPlayed = songs
            .filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }
            .prefix(25)
            .map { "- \($0.title ?? "?") — \($0.artist ?? "?")\($0.genre.map { " [\($0)]" } ?? "") ×\($0.playCount)" }

        let recent = songs
            .compactMap { s -> (MPMediaItem, Date)? in s.lastPlayedDate.map { (s, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(25)
            .map { "- \($0.0.title ?? "?") — \($0.0.artist ?? "?")" }

        return """
        # Apple Music
        ## Most played
        \(mostPlayed.isEmpty ? "(none)" : mostPlayed.joined(separator: "\n"))

        ## Recently played
        \(recent.isEmpty ? "(none)" : recent.joined(separator: "\n"))
        """
    }

    // MARK: - Photos (metadata only)

    private func requestPhotosAccess() async -> Bool {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                cont.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    private func readPhotosMetadata() -> String {
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -90, to: Date()) ?? Date()

        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@", since as NSDate)
        let assets = PHAsset.fetchAssets(with: opts)

        var total = 0
        var favorites = 0
        var withLocation = 0
        var dayCounts: [Int: Int] = [:] // weekday -> count
        assets.enumerateObjects { asset, _, _ in
            total += 1
            if asset.isFavorite { favorites += 1 }
            if asset.location != nil { withLocation += 1 }
            if let d = asset.creationDate {
                let wd = cal.component(.weekday, from: d)
                dayCounts[wd, default: 0] += 1
            }
        }

        let dayNames = cal.weekdaySymbols
        let topDays = dayCounts.sorted { $0.value > $1.value }.prefix(2)
            .map { dayNames[($0.key - 1) % 7] }
            .joined(separator: ", ")

        return """
        # Photos (metadata only, last 90 days — no images leave the device)
        - total photos: \(total)
        - favorites: \(favorites)
        - with location: \(withLocation)
        - most active days: \(topDays.isEmpty ? "n/a" : topDays)
        """
    }

    // MARK: - Contacts

    private func requestContactsAccess() async -> Bool {
        await withCheckedContinuation { cont in
            contactStore.requestAccess(for: .contacts) { granted, _ in cont.resume(returning: granted) }
        }
    }

    private func readContacts() -> String {
        let keys = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactOrganizationNameKey, CNContactRelationsKey,
        ] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var lines: [String] = []
        var count = 0
        do {
            try contactStore.enumerateContacts(with: request) { contact, stop in
                count += 1
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let org = contact.organizationName.isEmpty ? "" : " (\(contact.organizationName))"
                let rels = contact.contactRelations.map { $0.label ?? "" }.filter { !$0.isEmpty }
                let rel = rels.isEmpty ? "" : " [\(rels.joined(separator: ", "))]"
                lines.append("- \(name)\(org)\(rel)")
                if lines.count >= 300 { stop.pointee = true }
            }
        } catch {
            print("[NativeSources] contacts read failed: \(error)")
        }

        return """
        # Contacts (the people in their life — \(count) total)
        \(lines.isEmpty ? "(none readable)" : lines.joined(separator: "\n"))
        """
    }
}
