//
//  SampleJournalData.swift
//  UI1.0: the journal on sample data (docs/team/ui/UI1.0.md). It conforms to `Flows.JournalData`
//  exactly as the live data will (PL3.1), so the wiring PR swaps one line and nothing on screen
//  changes. Deterministic: every delay waits on the injected clock, nothing is random, and
//  "loading" is a wait that only ends when its task is cancelled.
//
import Foundation
import Observation

@MainActor
@Observable
final class SampleJournalData: Flows.JournalData {
    typealias Journal = Flows.Journal
    typealias Content = SampleJournalContent

    let scenario: JournalScenario

    private(set) var today: Flows.Loadable<[Journal.Entry]> = .loading
    private(set) var brief: Flows.Loadable<Journal.BriefSlot> = .loading
    private(set) var guesses: [Journal.Guess] = []
    private(set) var isOnline: Bool

    @ObservationIgnored private let clock: any Clock<Duration>
    /// Earlier days in the drawer, newest first (today's entries are added from `today`).
    @ObservationIgnored private var earlier: [Journal.Entry]
    @ObservationIgnored private var acknowledgements: [String: String] = [:]
    @ObservationIgnored private var lastAcknowledgement: String?
    /// Picks acknowledgements in turn, so the sample never depends on randomness.
    @ObservationIgnored private var acknowledgementTurn = 0
    @ObservationIgnored private var sentFromHere = 0
    /// The scenario's content is laid down once; after that, edits, deletes, sends and answers
    /// survive a screen reappearing and calling `load()` again.
    @ObservationIgnored private var seeded = false

    /// How long the sample's pretend network takes to send (the card's one second).
    static let sendDelay: Duration = .seconds(1)
    /// The drawer's page size (contract 02 §5: 50).
    static let pageSize = 50

    init(scenario: JournalScenario, clock: any Clock<Duration> = ContinuousClock()) {
        self.scenario = scenario
        self.clock = clock
        isOnline = scenario != .offline
        earlier = scenario == .long ? Content.sixtyEntries : Content.earlierEntries
    }

    // MARK: - Today, the brief, guesses

    func load() async {
        if scenario == .loading {
            await waitUntilCancelled()
            return
        }
        guard !seeded else { return }
        seeded = true
        // thoughts sent before the first load stay, after the scenario's own entries
        let sentEarly = today.value ?? []
        switch Self.today(for: scenario) {
        case let .loaded(entries):
            today = .loaded(entries + sentEarly)
        case let seed where sentEarly.isEmpty:
            today = seed
        default:
            today = .loaded(sentEarly)
        }
        brief = Self.brief(for: scenario)
        guesses = Self.guesses(for: scenario)
        for entry in today.value ?? [] where entry.delivery == .sent {
            if let id = entry.clientEntryId {
                acknowledge(id)
            }
        }
    }

    private static func today(for scenario: JournalScenario) -> Flows.Loadable<[Journal.Entry]> {
        var entries = Content.todayEntries
        switch scenario {
        case .dayOne:
            return .loaded([])
        case .errorNetwork:
            return .failed(Content.networkFailure)
        case .errorServer:
            return .failed(Content.serverFailure)
        case .long:
            entries.append(Content.longEntry)
        case .sending:
            entries[entries.count - 1] = onPhone(entries[entries.count - 1], .sending)
        case .notSent:
            entries[entries.count - 1] = onPhone(entries[entries.count - 1], .failed(Content.networkFailure))
        case .offline:
            entries[entries.count - 2] = onPhone(entries[entries.count - 2], .waiting)
            entries[entries.count - 1] = onPhone(entries[entries.count - 1], .waiting)
        default:
            break
        }
        return .loaded(entries)
    }

    private static func brief(for scenario: JournalScenario) -> Flows.Loadable<Journal.BriefSlot> {
        switch scenario {
        case .briefOff: .loaded(.off)
        case .dayOne, .briefMaking: .loaded(.making(readyBy: Content.readyBy))
        case .briefQuiet: .loaded(.quiet(line: Content.quietLine))
        case .briefError: .failed(Content.serverFailure)
        case .long: .loaded(.ready(Content.longBrief))
        default: .loaded(.ready(Content.brief))
        }
    }

    private static func guesses(for scenario: JournalScenario) -> [Journal.Guess] {
        switch scenario {
        case .dayOne, .errorNetwork, .errorServer: []
        case .guessConfirmed: [Content.guess(.confirmed)]
        default: [Content.guess(.offered)]
        }
    }

    /// The same words as an entry this phone sent and the server doesn't have yet.
    private static func onPhone(_ entry: Journal.Entry, _ delivery: Journal.Entry.Delivery) -> Journal.Entry {
        Journal.Entry(
            local: entry.clientEntryId ?? entry.id,
            kind: entry.kind,
            text: entry.text,
            createdAt: entry.createdAt,
            day: entry.day,
            delivery: delivery
        )
    }

    // MARK: - Sending

    @discardableResult
    func send(text: String) async -> Journal.WriteOutcome {
        await sendNew(kind: .typed, text: text)
        return isOnline ? .done : .queued
    }

    func sendVoice(_ note: Journal.VoiceNote) async {
        await sendNew(kind: .voice, text: note.transcript)
    }

    func retry(clientEntryId: String) async {
        guard isOnline, case .failed? = delivery(of: clientEntryId) else { return }
        await deliver(clientEntryId)
    }

    func acknowledgement(for clientEntryId: String) -> String? {
        acknowledgements[clientEntryId]
    }

    private func sendNew(kind: Journal.Entry.Kind, text: String) async {
        // a thought sent before today has loaded (or after it failed) is still saved
        var entries = today.value ?? []
        sentFromHere += 1
        let id = String(format: "00000000-0000-4000-8000-%012d", 5000 + sentFromHere)
        let now = Content.todayEntries.last?.createdAt.addingTimeInterval(Double(sentFromHere) * 60) ?? Date(timeIntervalSince1970: 0)
        entries.append(Journal.Entry(local: id, kind: kind, text: text, createdAt: now, day: Content.today, delivery: .waiting))
        today = .loaded(entries)
        guard isOnline else { return }
        await deliver(id)
    }

    /// Sending → (the clock moves on) → sent, with its acknowledgement. In `sending` it never arrives.
    private func deliver(_ clientEntryId: String) async {
        setDelivery(.sending, for: clientEntryId)
        if scenario == .sending {
            await waitUntilCancelled()
            return
        }
        do {
            try await clock.sleep(for: Self.sendDelay)
        } catch {
            return
        }
        setDelivery(.sent, for: clientEntryId)
        acknowledge(clientEntryId)
    }

    private func delivery(of clientEntryId: String) -> Journal.Entry.Delivery? {
        today.value?.first { $0.clientEntryId == clientEntryId }?.delivery
    }

    private func setDelivery(_ delivery: Journal.Entry.Delivery, for clientEntryId: String) {
        guard case var .loaded(entries) = today,
              let index = entries.firstIndex(where: { $0.clientEntryId == clientEntryId })
        else { return }
        entries[index].delivery = delivery
        today = .loaded(entries)
    }

    /// Chosen once, when the entry is sent; never the line before it.
    private func acknowledge(_ clientEntryId: String) {
        guard acknowledgements[clientEntryId] == nil else { return }
        let turn = acknowledgementTurn
        let line = Journal.Acknowledgements.next(after: lastAcknowledgement) { count in turn % count }
        acknowledgementTurn += 1
        acknowledgements[clientEntryId] = line
        lastAcknowledgement = line
    }

    // MARK: - Guesses

    func answer(_ guess: Journal.Guess, verdict: Journal.GuessVerdict) async -> Journal.GuessOutcome {
        let status: Journal.Guess.Status = verdict == .yes ? .confirmed : .declined
        // the guess on screen changes at once, whatever happens next
        guesses = guesses.map { $0.id == guess.id ? Self.guess($0, status) : $0 }
        switch scenario {
        case .guessPending:
            await waitUntilCancelled()
            // the answer never reached the server: the guess goes back to how it was
            guesses = guesses.map { $0.id == guess.id ? guess : $0 }
            return .failed(Content.networkFailure)
        case .guessError:
            guesses = guesses.map { $0.id == guess.id ? guess : $0 }
            return .failed(Content.networkFailure)
        default:
            return isOnline ? .recorded(status) : .queued
        }
    }

    private static func guess(_ guess: Journal.Guess, _ status: Journal.Guess.Status) -> Journal.Guess {
        Journal.Guess(
            id: guess.id,
            question: guess.question,
            framework: guess.framework,
            rationale: guess.rationale,
            status: status,
            restsOn: guess.restsOn
        )
    }

    // MARK: - The drawer and one entry

    func entries(cursor: String?, query: String?) async -> Result<Flows.Page<Journal.Entry>, Flows.Failure> {
        switch scenario {
        case .loading:
            await waitUntilCancelled()
            return .failure(Content.networkFailure)
        case .errorNetwork:
            return .failure(Content.networkFailure)
        case .errorServer:
            return .failure(Content.serverFailure)
        default:
            break
        }
        var all = Array((today.value ?? Content.todayEntries).reversed()) + earlier
        if let query, !query.isEmpty {
            all = all.compactMap { Self.matching($0, query) }
        }
        let start = cursor.flatMap { Int($0.dropFirst("cursor-".count)) } ?? 0
        let end = min(start + Self.pageSize, all.count)
        let items = start < end ? Array(all[start ..< end]) : []
        return .success(Flows.Page(items: items, nextCursor: end < all.count ? "cursor-\(end)" : nil))
    }

    /// The entry with its matched spans (UTF-16, as contract 02 §5), or nil when it doesn't match.
    private static func matching(_ entry: Journal.Entry, _ query: String) -> Journal.Entry? {
        let text = entry.text as NSString
        var matches: [Journal.Entry.Match] = []
        var searchFrom = NSRange(location: 0, length: text.length)
        while true {
            let found = text.range(of: query, options: .caseInsensitive, range: searchFrom)
            guard found.location != NSNotFound else { break }
            matches.append(.init(start: found.location, length: found.length))
            let next = found.location + found.length
            searchFrom = NSRange(location: next, length: text.length - next)
        }
        return matches.isEmpty ? nil : rebuilt(entry, matches: matches)
    }

    func entry(id: String) async -> Result<Journal.Entry, Flows.Failure> {
        if scenario == .loading {
            await waitUntilCancelled()
            return .failure(Content.networkFailure)
        }
        let all = (today.value ?? Content.todayEntries) + earlier
        guard let found = all.first(where: { $0.id == id || $0.serverId == id }) else {
            return .failure(.notFound)
        }
        return .success(found)
    }

    func edit(id: String, text: String) async -> Journal.WriteOutcome {
        replace(id) { Self.rebuilt($0, text: text) }
        return isOnline ? .done : .queued
    }

    func delete(id: String) async -> Journal.WriteOutcome {
        replace(id) { _ in nil }
        return isOnline ? .done : .queued
    }

    private func replace(_ id: String, with change: (Journal.Entry) -> Journal.Entry?) {
        let matches: (Journal.Entry) -> Bool = { $0.id == id || $0.serverId == id }
        if case let .loaded(entries) = today {
            today = .loaded(entries.compactMap { matches($0) ? change($0) : $0 })
        }
        earlier = earlier.compactMap { matches($0) ? change($0) : $0 }
    }

    /// An entry with new words or matches. Entries keep their identity rules in the decoder, so the
    /// changed one is decoded from the server's shape too. Entries only on the phone keep theirs.
    private static func rebuilt(_ entry: Journal.Entry, text: String? = nil, matches: [Journal.Entry.Match]? = nil) -> Journal.Entry {
        guard let serverId = entry.serverId else {
            return Journal.Entry(
                local: entry.clientEntryId ?? entry.id, kind: entry.kind, text: text ?? entry.text,
                createdAt: entry.createdAt, day: entry.day, delivery: entry.delivery,
                matches: matches
            )
        }
        var json: [String: Any] = [
            "id": serverId, "kind": entry.kind.rawValue, "text": text ?? entry.text,
            "createdAt": entry.createdAt.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
            "day": entry.day, "reading": entry.reading.rawValue,
        ]
        json["clientEntryId"] = entry.clientEntryId
        if let matches {
            json["matches"] = matches.map { ["start": $0.start, "length": $0.length] }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let decoded = try? JSONDecoder.contract.decode(Journal.Entry.self, from: data)
        else { return entry }
        return decoded
    }

    // MARK: - What Retro took, and "not right"

    func tookUpdates(id _: String) -> AsyncStream<Result<Journal.Took, Flows.Failure>> {
        let scenario = scenario
        return AsyncStream { continuation in
            switch scenario {
            case .errorNetwork:
                continuation.yield(.failure(Content.networkFailure))
                continuation.finish()
            case .errorServer:
                continuation.yield(.failure(Content.serverFailure))
                continuation.finish()
            case .tookWaiting, .loading:
                // still reading: the stream stays open until the screen goes away
                continuation.yield(.success(Content.tookWaiting))
            default:
                continuation.yield(.success(Content.took))
                continuation.finish()
            }
        }
    }

    func correct(text _: String, about _: Journal.ClaimRef?) async -> Journal.CorrectionOutcome {
        guard isOnline else { return .offline }
        switch scenario {
        case .correctionConfirm: return Content.confirm
        case .correctionAskOwnWords: return Content.askOwnWords
        case .correctionNotACorrection: return .notACorrection
        default: return Content.applied
        }
    }

    func confirm(_: Journal.ClaimRef, mode _: Journal.CorrectionMode, note _: String?) async -> Journal.CorrectionOutcome {
        isOnline ? Content.confirmed : .offline
    }

    // MARK: - Waiting

    /// Waits on the injected clock until the task is cancelled: how "loading" and "sending" never end.
    private func waitUntilCancelled() async {
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: .seconds(3600))
            } catch {
                return
            }
        }
    }
}
