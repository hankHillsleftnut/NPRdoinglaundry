//
//  LiveJournalData.swift
//  PL3.1a: the journal's live data (contracts/PL3.1.md): today and sending. Built per signed-in
//  user by `AppEnvironment`, it never touches GRDB or the client itself: reads go through
//  `Repositories.Journal`, writes through the outbox. Today is shown from the store at once
//  (the rows written here, plus the last list the server gave) and refreshed from the server;
//  delivery comes only from watching the rows, so a bubble's state is whatever the drainer
//  wrote, never the seam's guess. The brief (PL3.1b) is worked out from the last answer at the
//  person's day, and looked for again while it's being made. Guesses (PL3.1c) show from the last
//  list with answers waiting to be sent applied. The drawer (PL3.1d, in the Drawer extension) reads
//  the server and the phone. "What Retro took" and corrections are PL3.1e; until then they answer
//  with a failure and never throw. When the app comes back on the same day (P09.live) the root calls
//  `refresh()`: the same load, at most once a minute, never alongside another, and never after `stop()`.
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

    @ObservationIgnored let repository: Platform.Repositories.Journal
    @ObservationIgnored private let outbox: Store.Outbox
    @ObservationIgnored private let reachability: any Backend.Reachability
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let timeZone: @Sendable () -> TimeZone
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var latest: Backend.Endpoints.BriefLatest.Latest?
    @ObservationIgnored private var briefPoll: Task<Void, Never>?
    /// The guesses as the server last gave them, before the person's own taps and queued answers.
    @ObservationIgnored private var offered: [Journal.Guess]?
    @ObservationIgnored private var server: [Journal.Entry]?
    @ObservationIgnored private var rows: [Store.EntryRow] = []
    @ObservationIgnored private var acknowledgements: [String: String] = [:]
    @ObservationIgnored private var observing: Task<Void, Never>?
    @ObservationIgnored private var watchingReachability: Task<Void, Never>?
    @ObservationIgnored private var day: String?
    /// Loads (or refreshes) under way; a refresh never starts beside one.
    @ObservationIgnored private var loadsRunning = 0
    /// When the last load started; nil until the page has loaded once.
    @ObservationIgnored private var lastLoad: Date?
    /// After `stop()` nothing more is fetched or written: the next person's page never gets a late answer.
    @ObservationIgnored private var stopped = false

    init(
        repository: Platform.Repositories.Journal,
        outbox: Store.Outbox,
        reachability: any Backend.Reachability,
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: @escaping @Sendable () -> TimeZone = { .current },
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.clock = clock
        self.repository = repository
        self.outbox = outbox
        self.reachability = reachability
        self.now = now
        self.timeZone = timeZone
    }

    /// Stops watching the rows and the connection. Called before the person's store is erased.
    func stop() {
        stopped = true
        observing?.cancel()
        watchingReachability?.cancel()
        briefPoll?.cancel()
        briefPoll = nil
        observing = nil
        watchingReachability = nil
    }

    // MARK: Today

    func load() async {
        guard !stopped else { return }
        loadsRunning += 1
        defer { loadsRunning -= 1 }
        lastLoad = now()
        startWatchingReachability()
        let loadDay = await repository.localDay()
        guard !stopped else { return }
        await startObserving(day: loadDay)
        guard await loadToday(day: loadDay) else { return }
        await loadBrief(day: loadDay)
        guard isCurrent(loadDay) else { return }
        await loadGuesses(day: loadDay)
    }

    /// Today from the cache, then the server. False when the load should go no further (cancelled, stopped,
    /// or the day moved on while it waited).
    private func loadToday(day loadDay: String) async -> Bool {
        if server == nil, let cached = await repository.cachedToday(day: loadDay), isCurrent(loadDay) {
            server = cached
            publish()
        }
        do {
            let fresh = try await repository.refreshToday(day: loadDay)
            guard isCurrent(loadDay) else { return false }
            server = fresh
            publish()
        } catch is CancellationError {
            return false
        } catch {
            guard isCurrent(loadDay) else { return false }
            let failure = (error as? Backend.Failure)?.flowFailure ?? Flows.Failure(.unknown)
            // Cached or phone-only entries are still true; only an empty page shows the failure.
            if server == nil, rows.isEmpty {
                today = .failed(failure)
            } else {
                publish()
            }
        }
        return true
    }

    /// An answer asked for on `loadDay` may still be written: not stopped, and still the same day.
    private func isCurrent(_ loadDay: String) -> Bool {
        !stopped && day == loadDay
    }

    // MARK: Coming back (P09.live)

    /// The shortest time, in seconds, between two looks at the server when the app comes back.
    static let refreshInterval: TimeInterval = 60

    /// The app came back on the same day: today, the brief and the guesses are fetched again, and what is shown
    /// stays until a new answer replaces it (no skeleton, no error over a loaded page). Nothing happens before the
    /// first load, within a minute of the last one, while one is running, offline, or after `stop()`.
    func refresh() async {
        guard !stopped, loadsRunning == 0, isOnline, let lastLoad else { return }
        let since = now().timeIntervalSince(lastLoad)
        // a clock set back counts as time passed, so the page is never stuck waiting for it to catch up
        guard since < 0 || since >= Self.refreshInterval else { return }
        await load()
    }

    // MARK: Guesses (PL3.1c)

    private func loadGuesses(day loadDay: String) async {
        if offered == nil, let cached = await repository.cachedGuesses(), isCurrent(loadDay) {
            offered = cached
            await publishGuesses(day: loadDay)
        }
        do {
            let fresh = try await repository.refreshGuesses()
            guard isCurrent(loadDay) else { return }
            offered = fresh
            await publishGuesses(day: loadDay)
        } catch is CancellationError {
            return
        } catch {
            // A failed look keeps what was kept; guesses have no failed state, they just aren't there.
            await publishGuesses(day: loadDay)
        }
    }

    /// The guesses with answers still waiting to be sent applied: a queued answer's status wins over the server's.
    private func publishGuesses(day loadDay: String) async {
        let queued = await repository.queuedAnswers()
        guard isCurrent(loadDay) else { return }
        guesses = (offered ?? []).map { guess in
            queued[guess.id].map { Self.answered(guess, $0 == .yes ? .confirmed : .declined) } ?? guess
        }
    }

    private static func answered(_ guess: Journal.Guess, _ status: Journal.Guess.Status) -> Journal.Guess {
        Journal.Guess(
            id: guess.id, question: guess.question, framework: guess.framework, rationale: guess.rationale,
            status: status, restsOn: guess.restsOn
        )
    }

    private func setStatus(_ id: String, _ status: Journal.Guess.Status) {
        guesses = guesses.map { $0.id == id ? Self.answered($0, status) : $0 }
        offered = offered?.map { $0.id == id ? Self.answered($0, status) : $0 }
    }

    /// The answer takes at once on screen and goes into the outbox (PL3.1c): one row whose id is the
    /// idempotency key, so every attempt, whenever the phone gets to it, carries the same key and the server
    /// keeps the first answer. A refusal comes back later as a dead row: the guess is offered again.
    func answer(_ guess: Journal.Guess, verdict: Journal.GuessVerdict) async -> Journal.GuessOutcome {
        let before = guess.status
        setStatus(guess.id, verdict == .yes ? .confirmed : .declined)
        do {
            _ = try await outbox.enqueueGuessAnswer(guessID: guess.id, verdict: verdict)
            return .queued
        } catch {
            setStatus(guess.id, before)
            return .failed(Flows.Failure(.unknown))
        }
    }

    // MARK: The brief (PL3.1b)

    /// When to look again while a brief is being made: at the time it is due, then 2, 5, 10 and 15 minutes
    /// after. Then it stops until the next load (the app coming to the front), which starts the same looks
    /// again from then if the brief is still being made.
    static let pollOffsets: [Duration] = [.zero, .seconds(120), .seconds(300), .seconds(600), .seconds(900)]

    private func loadBrief(day: String) async {
        if latest == nil, let cached = await repository.cachedBrief(), isCurrent(day) {
            latest = cached
            publishBrief(day: day)
        }
        do {
            let fresh = try await repository.refreshBrief()
            guard isCurrent(day) else { return }
            latest = fresh
            publishBrief(day: day)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(day) else { return }
            // A kept brief is still true; with nothing kept the card says it couldn't load.
            if latest == nil {
                brief = .failed((error as? Backend.Failure)?.flowFailure ?? Flows.Failure(.unknown))
            } else {
                publishBrief(day: day)
            }
        }
    }

    /// The card's slot from what is known, at the person's day now; starts or ends the wait for a brief being made.
    private func publishBrief(day: String) {
        guard let latest else { return }
        let slot = Journal.BriefSlot.derive(from: latest, today: day)
        brief = .loaded(slot)
        if case let .making(readyBy?) = slot {
            watchForBrief(readyBy: readyBy, day: day)
        } else {
            briefPoll?.cancel()
            briefPoll = nil
        }
    }

    private func watchForBrief(readyBy: Date, day: String) {
        guard briefPoll == nil else { return }
        // Past the whole wait (the app came back late), the same looks start again from now.
        let lastLook = readyBy.addingTimeInterval(Self.pollOffsets.last?.seconds ?? 0)
        let start = lastLook < now() ? now() : readyBy
        briefPoll = Task { [weak self] in
            for offset in Self.pollOffsets {
                guard let self, !Task.isCancelled else { return }
                let wait = start.addingTimeInterval(offset.seconds).timeIntervalSince(now())
                guard wait > 0 else { continue }
                do {
                    try await clock.sleep(for: .seconds(wait))
                } catch {
                    return
                }
                if await refreshWhileMaking(day: day) {
                    break
                }
            }
            // A cancelled wait was ended by whoever cancelled it, and may already have been replaced.
            if let self, !Task.isCancelled {
                briefPoll = nil
            }
        }
    }

    /// One look while waiting; true when the wait is over (the brief came, or the server asks us to stop).
    private func refreshWhileMaking(day: String) async -> Bool {
        let fresh: Backend.Endpoints.BriefLatest.Latest
        do {
            fresh = try await repository.refreshBrief()
        } catch let failure as Backend.Failure {
            if case .rateLimited = failure.kind {
                return true
            }
            return false
        } catch {
            return true
        }
        guard isCurrent(day) else { return true }
        latest = fresh
        publishBrief(day: day)
        if case .making = brief.value {
            return false
        }
        return true
    }

    private func startObserving(day newDay: String) async {
        guard day != newDay || observing == nil else { return }
        observing?.cancel()
        // A wait for the brief belongs to its day; the new day's load starts its own.
        briefPoll?.cancel()
        briefPoll = nil
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

    static func entry(from row: Store.EntryRow, matches: [Journal.Entry.Match]? = nil) -> Journal.Entry {
        Journal.Entry(
            local: row.localID, kind: Journal.Entry.Kind(rawValue: row.kind.rawValue) ?? .typed, text: row.text,
            createdAt: row.createdAt, day: row.day, delivery: delivery(of: row), matches: matches
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

    // MARK: Not yet (PL3.1e)

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

private extension Duration {
    var seconds: TimeInterval {
        TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
