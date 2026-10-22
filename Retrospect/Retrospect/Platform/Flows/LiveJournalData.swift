//
//  LiveJournalData.swift
//  PL3.1a: the journal's live data (contracts/PL3.1.md): today and sending. Built per signed-in
//  user by `AppEnvironment`, it never touches GRDB or the client itself: reads go through
//  `Repositories.Journal`, writes through the outbox. Today is shown from the store at once
//  (the rows written here, plus the last list the server gave) and refreshed from the server;
//  delivery comes only from watching the rows, so a bubble's state is whatever the drainer
//  wrote, never the seam's guess. The brief (PL3.1b) is worked out from the last answer at the
//  person's day, and looked for again while it's being made. Guesses (PL3.1c) show from the last list with answers waiting to be sent applied. The drawer and
//  "what
//  Retro took" are PL3.1d and e; until then they answer as "nothing yet" and never throw.
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
        observing?.cancel()
        watchingReachability?.cancel()
        briefPoll?.cancel()
        briefPoll = nil
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
        await loadBrief(day: loadDay)
        await loadGuesses()
    }

    // MARK: Guesses (PL3.1c)

    private func loadGuesses() async {
        if offered == nil, let cached = await repository.cachedGuesses() {
            offered = cached
            await publishGuesses()
        }
        do {
            offered = try await repository.refreshGuesses()
            await publishGuesses()
        } catch is CancellationError {
            return
        } catch {
            // A failed look keeps what was kept; guesses have no failed state, they just aren't there.
            await publishGuesses()
        }
    }

    /// The guesses with answers still waiting to be sent applied: a queued answer's status wins over the server's.
    private func publishGuesses() async {
        let queued = await repository.queuedAnswers()
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

    /// The answer takes at once on screen, then goes to the server in one round trip. A phone-side or server-side
    /// trouble that may pass queues it for the outbox (sent once, later); a refusal puts the guess back.
    func answer(_ guess: Journal.Guess, verdict: Journal.GuessVerdict) async -> Journal.GuessOutcome {
        let before = guess.status
        setStatus(guess.id, verdict == .yes ? .confirmed : .declined)
        do {
            let status = try await repository.answerGuess(id: guess.id, verdict: verdict, key: UUID())
            setStatus(guess.id, status)
            return .recorded(status)
        } catch let failure as Backend.Failure {
            guard Self.worthQueueing(failure) else {
                setStatus(guess.id, before)
                return .failed(failure.flowFailure)
            }
        } catch {
            setStatus(guess.id, before)
            return .failed(Flows.Failure(.unknown))
        }
        do {
            _ = try await outbox.enqueueGuessAnswer(guessID: guess.id, verdict: verdict)
            return .queued
        } catch {
            setStatus(guess.id, before)
            return .failed(Flows.Failure(.unknown))
        }
    }

    /// Trouble that may pass: no connection, a timeout, a server that's down or busy.
    private static func worthQueueing(_ failure: Backend.Failure) -> Bool {
        switch failure.kind {
        case .offline, .timedOut, .transport, .upstreamTimeout, .upstreamUnavailable, .internal, .rateLimited: true
        default: false
        }
    }

    // MARK: The brief (PL3.1b)

    /// When to look again while a brief is being made: at the time it is due, then 2, 5, 10 and 15 minutes
    /// after. Then it stops until the next load (the app coming to the front).
    static let pollOffsets: [Duration] = [.zero, .seconds(120), .seconds(300), .seconds(600), .seconds(900)]

    private func loadBrief(day: String) async {
        if latest == nil, let cached = await repository.cachedBrief() {
            latest = cached
            publishBrief(day: day)
        }
        do {
            latest = try await repository.refreshBrief()
            publishBrief(day: day)
        } catch is CancellationError {
            return
        } catch {
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
        briefPoll = Task { [weak self] in
            for offset in Self.pollOffsets {
                guard let self, !Task.isCancelled else { return }
                let wait = readyBy.addingTimeInterval(offset.seconds).timeIntervalSince(now())
                guard wait > 0 else { continue }
                do {
                    try await clock.sleep(for: .seconds(wait))
                } catch {
                    return
                }
                if await refreshWhileMaking(day: day) {
                    return
                }
            }
            briefPoll = nil
        }
    }

    /// One look while waiting; true when the wait is over (the brief came, or the server asks us to stop).
    private func refreshWhileMaking(day: String) async -> Bool {
        do {
            latest = try await repository.refreshBrief()
        } catch let failure as Backend.Failure {
            if case .rateLimited = failure.kind {
                briefPoll = nil
                return true
            }
            return false
        } catch {
            return true
        }
        publishBrief(day: day)
        if case .making = brief.value {
            return false
        }
        return true
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

    func send(text: String) async {
        await enqueue(kind: .typed, text: text, mediaPath: nil)
    }

    func sendVoice(_ note: Journal.VoiceNote) async {
        await enqueue(kind: .voice, text: note.transcript, mediaPath: note.recordingPath)
    }

    private func enqueue(kind: Backend.Endpoints.CreateEntry.Kind, text: String, mediaPath: String?) async {
        guard text.utf16.count <= Self.longestEntry,
              let draft = Store.EntryDraft(kind: kind, text: text, createdAt: now(), mediaPath: mediaPath)
        else { return }
        // The row lands in the store; the observation shows it as waiting. Nothing is appended here.
        _ = try? await outbox.enqueueEntry(draft)
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

    // MARK: Not yet (PL3.1d, e)

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

private extension Duration {
    var seconds: TimeInterval {
        TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
