//
//  DrawerModel.swift
//  V2.journal (dark) · JR-3 all entries: the drawer's state. It lists every entry by day, newest
//  first (Paper MW6-0), searches as you type (debounced; MZJ-0 / N17-0), says when it is offline
//  (N2N-0) and retries a row that didn't send. The meta line holds what the contract carries,
//  the kind and the time ("written · 9:12"); Paper's message counts and voice-note lengths need
//  fields contract 02 §5 doesn't have, so they are left out (founder-review 32; DISCREPANCIES J-10).
//
import Foundation
import Observation

@MainActor
@Observable
final class DrawerModel {
    typealias Entry = Flows.Journal.Entry

    /// One drawer row, already worded.
    struct Row: Identifiable, Equatable {
        let id: String
        let words: String
        let meta: String
        let matches: [Range<Int>]
        let status: REntryRow.Status
        let here: Bool
        /// Set for an entry sent from this phone (what retry needs).
        let clientEntryId: String?
    }

    /// A day of rows ("today"), or in search, the one group of results ("2 matches").
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let rows: [Row]
    }

    enum State: Equatable {
        case loading
        /// Nothing written yet (MYD-0).
        case empty
        case list([Section])
        /// A search that found nothing (N17-0).
        case noResults
        /// Couldn't load (no drawing yet: the empty line with the reason).
        case failed(String)
    }

    private(set) var state: State = .loading
    /// The search field's words. Changing them searches after a short pause.
    var query: String {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    var isOffline: Bool {
        data.isOffline
    }

    /// The entry the journal behind is showing ("here").
    var hereID: String?
    /// Opening a row (JR-4, set by the host). Until a host sets it, sent rows don't open and say so
    /// (no dead controls); a row that didn't send still retries.
    var onOpen: ((Row) -> Void)?

    @ObservationIgnored private let data: any EntriesData
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// Every load gets a number; only the newest may write the list (a retry's reload, a search typed
    /// away and back, or a page arriving late never overwrite a newer one).
    @ObservationIgnored private var generation = 0
    /// What the list holds so far, and the cursor for the next page (contract 02 §5 pages).
    @ObservationIgnored private var loaded: [Entry] = []
    @ObservationIgnored private var nextCursor: String?
    /// The load whose next page is in flight (a newer load's page request is never blocked by an older one).
    @ObservationIgnored private var loadingMoreFor: Int?
    /// Entries being sent again: a second tap while one is sending doesn't send it twice.
    @ObservationIgnored private var retrying: Set<String> = []

    init(data: any EntriesData, query: String = "", hereID: String? = nil, debounce: Duration = .milliseconds(250)) {
        self.data = data
        self.query = query
        self.hereID = hereID
        self.debounce = debounce
    }

    // MARK: - Loading and search

    func load() async {
        generation += 1
        // the old list's next page belongs to the old search: a late "load more" must not add it here
        nextCursor = nil
        let mine = generation
        let searched = Self.cleaned(query)
        let result = await data.entries(cursor: nil, query: searched)
        // a newer load or search owns the list
        guard mine == generation, Self.cleaned(query) == searched else { return }
        switch result {
        case let .success(page):
            loaded = page.items
            nextCursor = page.nextCursor
            state = makeState(loaded, searched: searched)
        case let .failure(failure):
            loaded = []
            nextCursor = nil
            state = .failed(failure.message ?? "couldn't load your journal. try again in a moment.")
        }
    }

    /// The next page, when the list's last row comes into view.
    func loadMore() async {
        let mine = generation
        guard let cursor = nextCursor, loadingMoreFor != mine else { return }
        loadingMoreFor = mine
        defer {
            if loadingMoreFor == mine {
                loadingMoreFor = nil
            }
        }
        let searched = Self.cleaned(query)
        let result = await data.entries(cursor: cursor, query: searched)
        guard mine == generation, Self.cleaned(query) == searched, case let .success(page) = result else { return }
        loaded += page.items
        nextCursor = page.nextCursor
        state = makeState(loaded, searched: searched)
    }

    /// Whether this row is the last one loaded with more to come (its appearing asks for the next page).
    func isLast(_ row: Row) -> Bool {
        nextCursor != nil && loaded.last?.id == row.id
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let pause = debounce
        searchTask = Task { [weak self] in
            if pause > .zero {
                try? await Task.sleep(for: pause)
            }
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    /// Waits for the search in flight (tests).
    func settle() async {
        await searchTask?.value
    }

    // MARK: - Rows

    func tap(_ row: Row) {
        if row.status == .notSent, let client = row.clientEntryId {
            Task { await retry(client) }
        } else {
            onOpen?(row)
        }
    }

    /// Whether tapping this row does something now.
    func opens(_ row: Row) -> Bool {
        row.status == .notSent || onOpen != nil
    }

    func retry(_ clientEntryId: String) async {
        // a second tap while the first is sending must not send the entry twice
        guard retrying.insert(clientEntryId).inserted else { return }
        defer { retrying.remove(clientEntryId) }
        await data.retry(clientEntryId: clientEntryId)
        await load()
    }

    private func makeState(_ entries: [Entry], searched: String?) -> State {
        if entries.isEmpty {
            return searched == nil ? .empty : .noResults
        }
        if searched != nil {
            let rows = entries.map { row($0, meta: dayAndTime($0)) }
            let title = rows.count == 1 ? "1 match" : "\(rows.count) matches"
            return .list([Section(id: "matches", title: title, rows: rows)])
        }
        // one section per day, newest day first, each day's rows newest first, however the phone's
        // queue and the server's pages arrive (a day never appears twice)
        let days = Dictionary(grouping: entries, by: \.day)
        let sections = days.keys.sorted(by: >).map { day in
            let rows = (days[day] ?? []).sorted { $0.createdAt > $1.createdAt }.map { row($0, meta: kindAndTime($0)) }
            return Section(id: day, title: dayLabel(day), rows: rows)
        }
        return .list(sections)
    }

    private func row(_ entry: Entry, meta: String) -> Row {
        Row(
            id: entry.id,
            words: entry.text,
            meta: meta,
            matches: (entry.matches ?? []).map { $0.start ..< $0.start + $0.length },
            status: Self.status(entry.delivery),
            here: entry.id == hereID || entry.serverId == hereID,
            clientEntryId: entry.clientEntryId
        )
    }

    static func status(_ delivery: Entry.Delivery) -> REntryRow.Status {
        switch delivery {
        case .sent: .rest
        case .waiting, .sending: .waiting
        case .failed: .notSent
        }
    }

    // MARK: - Words

    /// "written · 9:12": what kind of entry, and when (the contract's fields only).
    func kindAndTime(_ entry: Entry) -> String {
        "\(Self.kindWord(entry.kind)) · \(time(entry.createdAt))"
    }

    /// "today · 9:12", "tue 14 oct · 10:05": a search result's day and time (Paper MZJ-0).
    func dayAndTime(_ entry: Entry) -> String {
        "\(dayLabel(entry.day)) · \(time(entry.createdAt))"
    }

    static func kindWord(_ kind: Entry.Kind) -> String {
        switch kind {
        case .typed, .unknown: "written"
        case .voice: "voice note"
        case .conversation: "conversation"
        case .imported: "shared"
        }
    }

    /// "today", "yesterday", else "sun 19 oct".
    func dayLabel(_ day: String) -> String {
        EntryWords.dayLabel(day, today: data.today)
    }

    /// "9:12", "22:40" in the person's time zone.
    func time(_ date: Date) -> String {
        EntryWords.time(date, in: data.timeZone)
    }

    static func cleaned(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
