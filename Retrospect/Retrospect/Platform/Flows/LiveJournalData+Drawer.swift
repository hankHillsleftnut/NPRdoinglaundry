//
//  LiveJournalData+Drawer.swift
//  PL3.1d: the drawer's reads (contracts/PL3.1.md §1): every entry the person sent, newest first,
//  a page at a time, searchable, and one entry opened. The phone's own unsent entries come first
//  on the first page and match a search too; the server's list follows, de-duplicated; offline the
//  drawer still shows the phone's entries and today's, never an error. Editing and deleting wait
//  for BE1.5b (after Beta 1): they fail at once and the drawer hides the controls.
//
import Foundation

extension LiveJournalData {
    /// The longest search the door takes (UTF-16 units); longer is clipped on the phone.
    static let longestSearch = 100

    func entries(cursor: String?, query: String?) async -> Result<Flows.Page<Journal.Entry>, Flows.Failure> {
        let search = Self.cleaned(query)
        let phone = cursor == nil ? await phoneEntries(matching: search) : []
        do {
            let listed = try await repository.listEntries(cursor: cursor, search: search)
            let server = listed.entries.map { entry in
                entry.replacingMatches(entry.matches?.filter { Self.valid($0, in: entry.text) })
            }
            return .success(Flows.Page(items: Self.deduplicated(phone + server), nextCursor: listed.nextCursor))
        } catch let failure as Backend.Failure {
            guard cursor == nil, failure.flowFailure.kind == .network else { return .failure(failure.flowFailure) }
            let today = await repository.cachedToday(day: repository.localDay()) ?? []
            let kept = today.reversed().compactMap { Self.matching($0, search) }
            return .success(Flows.Page(items: Self.deduplicated(phone + kept), nextCursor: nil))
        } catch {
            return .failure(Flows.Failure(.unknown))
        }
    }

    func entry(id: String) async -> Result<Journal.Entry, Flows.Failure> {
        let row = await repository.row(id: id)
        if let row, row.syncState != .sent {
            return .success(Self.entry(from: row))
        }
        let today = await repository.cachedToday(day: repository.localDay())
        let known = today?.first { $0.id == id || $0.serverId == id }
        if let known, known.reading == .read {
            return .success(known)
        }
        do {
            return try await .success(repository.fetchEntry(id: row?.serverID ?? known?.serverId ?? id))
        } catch let failure as Backend.Failure {
            if let kept = known ?? row.map({ Self.entry(from: $0) }) {
                return .success(kept)
            }
            return .failure(failure.flowFailure)
        } catch {
            return .failure(Flows.Failure(.unknown))
        }
    }

    // MARK: Pieces

    /// The search as the door takes it: trimmed, clipped, or nil when empty.
    static func cleaned(_ query: String?) -> String? {
        guard let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        let units = Array(trimmed.utf16.prefix(longestSearch))
        return String(decoding: units, as: UTF16.self)
    }

    private func phoneEntries(matching search: String?) async -> [Journal.Entry] {
        await repository.phoneOnlyRows().compactMap { row in
            guard let search else { return Self.entry(from: row) }
            let spans = Self.spans(of: search, in: row.text)
            return spans.isEmpty ? nil : Self.entry(from: row, matches: spans)
        }
    }

    /// The entry with its matched spans, or nil when the search isn't in it. With no search, the entry as it is.
    static func matching(_ entry: Journal.Entry, _ search: String?) -> Journal.Entry? {
        guard let search else { return entry }
        let spans = spans(of: search, in: entry.text)
        return spans.isEmpty ? nil : entry.replacingMatches(spans)
    }

    /// Every occurrence of `search` in `text`, ignoring case, in UTF-16 units.
    static func spans(of search: String, in text: String) -> [Journal.Entry.Match] {
        let whole = text as NSString
        var matches: [Journal.Entry.Match] = []
        var from = NSRange(location: 0, length: whole.length)
        while from.length > 0 {
            let found = whole.range(of: search, options: .caseInsensitive, range: from)
            guard found.location != NSNotFound, found.length > 0 else { break }
            matches.append(Journal.Entry.Match(start: found.location, length: found.length))
            let next = found.location + found.length
            from = NSRange(location: next, length: whole.length - next)
        }
        return matches
    }

    /// A range that sits inside the text it matches.
    static func valid(_ match: Journal.Entry.Match, in text: String) -> Bool {
        match.start >= 0 && match.length > 0 && match.start + match.length <= text.utf16.count
    }

    /// One entry each: by the id the app sent it under, then by the server's.
    static func deduplicated(_ entries: [Journal.Entry]) -> [Journal.Entry] {
        var seen: Set<String> = []
        return entries.filter { entry in
            let keys = [entry.clientEntryId, entry.serverId].compactMap(\.self)
            guard !keys.contains(where: seen.contains) else { return false }
            seen.formUnion(keys)
            return true
        }
    }
}

extension Flows.Journal.Entry {
    /// The same entry with other matches. The entry keeps its delivery.
    func replacingMatches(_ matches: [Match]?) -> Self {
        guard self.matches != matches, let data = try? Backend.Coding.encoder.encode(self),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return self }
        object["matches"] = matches?.map { ["start": $0.start, "length": $0.length] }
        guard let changed = try? JSONSerialization.data(withJSONObject: object),
              var copy = try? Backend.Coding.decoder.decode(Self.self, from: changed)
        else { return self }
        copy.delivery = delivery
        return copy
    }
}
