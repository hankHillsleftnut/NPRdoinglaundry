//
//  LiveJournalData.swift
//  PL3.1a: the journal's live data (contracts/PL3.1.md): today and sending. Built per signed-in
//  user by `AppEnvironment`, it never touches GRDB or the client itself: reads go through
//  `Repositories.Journal`, writes through the outbox. Today is shown from the store at once
//  (the rows written here, plus the last list the server gave) and refreshed from the server;
//  delivery comes only from watching the rows, so a bubble's state is whatever the drainer
//  wrote, never the seam's guess. The brief, guesses, the drawer and "what Retro took" are
//  PL3.1b to e; until then they answer as "nothing yet" and never throw.
//
import Foundation
import Observation

@MainActor
@Observable
final class LiveJournalData: Flows.JournalData {
    typealias Journal = Flows.Journal

    /// An entry longer than this (UTF-16 units) is refused on the phone; the door's limit.
    static let longestEntry = 20000

    private(set) var today: Flows.Loadable<[Journal.Entry]> = .loading
    private(set) var brief: Flows.Loadable<Journal.BriefSlot> = .loading
    private(set) var guesses: [Journal.Guess] = []
    private(set) var isOnline = true

    @ObservationIgnored private let repository: Platform.Repositories.Journal
    @ObservationIgnored private let outbox: Store.Outbox
    @ObservationIgnored private let reachability: any Backend.Reachability
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let timeZone: @Sendable () -> TimeZone
    @ObservationIgnored private var server: [Journal.Entry]?
    @ObservationIgnored private var rows: [Store.EntryRow] = []
    @ObservationIgnored private var acknowledgements: [String: String] = [:]
    @ObservationIgnored private var observing: Task<Void, Never>?
    @ObservationIgnored private var watchingReachability: Task<Void, Never>?
    @ObservationIgnored private var day: String?

    init(
        repository: Platform.Repositories.Journal,
        outbox: Store.Outbox,
        reachability: any Backend.Reachability,
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: @escaping @Sendable () -> TimeZone = { .current }
    ) {
        self.repository = repository
        self.outbox = outbox
        self.reachability = reachability
        self.now = now
        self.timeZone = timeZone
    }

    /// Stops watching the rows and the connection. Called before the person's store is erased.
    func stop() {
        observing?.cancel()
        watchingReachability?.cancel()
        observing = nil
        watchingReachability = nil
    }

    // MARK: Today

    func load() async {
        startWatchingReachability()
        let loadDay = await repository.localDay()
        await startObserving(day: loadDay)
        if server == nil, let cached = await repository.cachedToday(day: loadDay) {
            server = cached
            publish()
        }
        brief = .loaded(.off)
        do {
            server = try await repository.refreshToday(day: loadDay)
            publish()
        } catch is CancellationError {
            return
        } catch {
            let failure = (error as? Backend.Failure)?.flowFailure ?? Flows.Failure(.unknown)
            // Cached or phone-only entries are still true; only an empty page shows the failure.
            if server == nil, rows.isEmpty {
                today = .failed(failure)
            } else {
                publish()
            }
        }
    }

    private func startObserving(day newDay: String) async {
        guard day != newDay || observing == nil else { return }
        observing?.cancel()
        day = newDay
        server = nil
        rows = []
        let stream = repository.rows(day: newDay)
        observing = Task { [weak self] in
            for await changed in stream {
                guard !Task.isCancelled, let self else { return }
                rows = changed
                publish()
            }
        }
    }

    private func startWatchingReachability() {
        guard watchingReachability == nil else { return }
        let stream = reachability.changes()
        watchingReachability = Task { [weak self] in
            for await online in stream {
                guard !Task.isCancelled, let self else { return }
                isOnline = online
            }
        }
    }

    /// Today from what is known now. Nothing is shown as loaded until the store or the server has said something.
    private func publish() {
        for row in rows {
            if let line = row.acknowledgement {
                acknowledgements[row.localID] = line
            }
        }
        if server == nil, rows.isEmpty, case .loading = today {
            return
        }
        today = .loaded(Self.merged(server: server ?? [], rows: rows))
    }

    /// The server's list and the rows written here, oldest first, one entry each. A row that is sent
    /// and also in the list takes the server's copy (its reading, its createdAt); a row still on
    /// the phone keeps its own state. The identity of a row never changes from waiting to sent.
    static func merged(server: [Journal.Entry], rows: [Store.EntryRow]) -> [Journal.Entry] {
        let rowByID = Dictionary(rows.map { ($0.localID, $0) }) { first, _ in first }
        var entries: [Journal.Entry] = []
        var placed: Set<String> = []
        for entry in server {
            if let key = entry.clientEntryId, let row = rowByID[key], row.syncState != .sent {
                continue
            }
            entries.append(entry)
            if let key = entry.clientEntryId {
                placed.insert(key)
            }
        }
        for row in rows where !placed.contains(row.localID) {
            entries.append(entry(from: row))
        }
        return entries.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }

    private static func entry(from row: Store.EntryRow) -> Journal.Entry {
        Journal.Entry(
            local: row.localID, kind: Journal.Entry.Kind(rawValue: row.kind.rawValue) ?? .typed, text: row.text,
            createdAt: row.createdAt, day: row.day, delivery: delivery(of: row)
        )
    }

    private static func delivery(of row: Store.EntryRow) -> Journal.Entry.Delivery {
        switch row.syncState {
        case .local: .waiting
        case .sending: .sending
        case .sent, .legacy, .unknown: .sent
        case .failed: .failed(failure(code: row.failureCode))
        }
    }

    /// The failure a stored code stands for; a code this build doesn't know is `.unknown`, which can be retried.
    static func failure(code: String?) -> Flows.Failure {
        code.flatMap(Backend.Failure.Kind.init(code:)).map { Backend.Failure($0).flowFailure } ?? Flows.Failure(.unknown)
    }

    // MARK: Sending

    @discardableResult
    func send(text: String) async -> Journal.WriteOutcome {
        await enqueue(kind: .typed, text: text, mediaPath: nil)
    }

    func sendVoice(_ note: Journal.VoiceNote) async {
        _ = await enqueue(kind: .voice, text: note.transcript, mediaPath: note.recordingPath)
    }

    /// Saves the entry; `.failed` when nothing was saved, so the screen can hand the words back.
    private func enqueue(kind: Backend.Endpoints.CreateEntry.Kind, text: String, mediaPath: String?) async -> Journal.WriteOutcome {
        guard text.utf16.count <= Self.longestEntry,
              let draft = Store.EntryDraft(kind: kind, text: text, createdAt: now(), mediaPath: mediaPath)
        else { return .failed(Flows.Failure(.unknown)) }
        // The row lands in the store; the observation shows it as waiting. Nothing is appended here.
        do {
            _ = try await outbox.enqueueEntry(draft)
            return .queued
        } catch {
            return .failed(Flows.Failure(.unknown))
        }
    }

    func retry(clientEntryId: String) async {
        guard isOnline, let id = UUID(uuidString: clientEntryId),
              case .failed? = today.value?.first(where: { $0.clientEntryId == clientEntryId })?.delivery
        else { return }
        try? await outbox.retry(entityID: id)
        await outbox.drain(reason: .manual)
    }

    func acknowledgement(for clientEntryId: String) -> String? {
        acknowledgements[clientEntryId]
    }

    // MARK: Not yet (PL3.1c to e)

    func answer(_: Journal.Guess, verdict _: Journal.GuessVerdict) async -> Journal.GuessOutcome {
        .failed(Flows.Failure(.unknown))
    }

    func entries(cursor _: String?, query _: String?) async -> Result<Flows.Page<Journal.Entry>, Flows.Failure> {
        .failure(Flows.Failure(.unknown))
    }

    func entry(id _: String) async -> Result<Journal.Entry, Flows.Failure> {
        .failure(Flows.Failure(.unknown))
    }

    func edit(id _: String, text _: String) async -> Journal.WriteOutcome {
        .failed(Flows.Failure(.unknown))
    }

    func delete(id _: String) async -> Journal.WriteOutcome {
        .failed(Flows.Failure(.unknown))
    }

    func tookUpdates(id _: String) -> AsyncStream<Result<Journal.Took, Flows.Failure>> {
        AsyncStream { continuation in
            continuation.yield(.failure(Flows.Failure(.unknown)))
            continuation.finish()
        }
    }

    func correct(text _: String, about _: Journal.ClaimRef?) async -> Journal.CorrectionOutcome {
        .failed(Flows.Failure(.unknown))
    }

    func confirm(_: Journal.ClaimRef, mode _: Journal.CorrectionMode, note _: String?) async -> Journal.CorrectionOutcome {
        .failed(Flows.Failure(.unknown))
    }
}
