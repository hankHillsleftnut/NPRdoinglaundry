//
//  JournalViewModel.swift
//  P09 JR-1: what the journal page shows, from the flow (docs/team/ui/P09.md). The view model
//  turns `Flows.JournalData` (today's entries with their outbox state, the brief slot, the
//  guesses, online) into the thread's items and the brief card's state, and owns what the page
//  itself decides: the composer's draft, the collapse from the scroll, which entry this session
//  watched go from sending to sent (the M08 land: the `confirm` haptic and the one VoiceOver
//  announcement), the player sheet and the drawer. Every mapping is a pure function, so the
//  scenarios can be tested without a view. It never reaches the network: the seam does.
//
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class JournalViewModel {
    typealias Journal = Flows.Journal

    /// One thing in the thread, oldest first, with an identity that stays put as entries arrive.
    enum Item: Identifiable, Equatable {
        /// The day label above a day's first entry ("today").
        case day(label: String)
        /// Something you sent.
        case mine(Journal.Entry)
        /// Retro's line after one of yours landed, keyed by that entry.
        case retro(entryId: String, line: String)
        /// A guess, as Retro's item after your last acknowledgement (founder question 1's lean).
        case guess(Journal.Guess)

        var id: String {
            switch self {
            case let .day(label): "day-\(label)"
            case let .mine(entry): entry.id
            case let .retro(entryId, _): "retro-\(entryId)"
            case let .guess(guess): "guess-\(guess.id)"
            }
        }
    }

    /// What the brief card draws, from the slot.
    struct BriefCard: Equatable {
        let date: String
        let length: String?
        let headline: String
        let subline: String?
        let state: RBriefCard.State
    }

    let data: any Flows.JournalData
    /// The person's local day, `YYYY-MM-DD`, for the "today" label (the launcher passes the
    /// sample's day; the app passes the real one).
    let today: String

    var draft = ""
    var composerMode: RVoiceComposer.Mode = .muted
    /// The thread has been scrolled up past the threshold: the bar and the card compact.
    var collapsed = false
    /// How far the thread sits above its bottom, in 8pt steps, for the top edge's blur band.
    var scrollSteps = 0
    var playerShown = false
    /// The entry this session watched go from sending to sent: the acknowledgement is announced
    /// once and the `confirm` haptic fires once, for it; a thread loaded already sent never does.
    private(set) var landed: String?
    /// The entries this session sent or retried that haven't been seen sent yet. `landed` is set
    /// when one of these turns `.sent` in the data, whenever that happens, so it works the same
    /// for a send that returns at once (the outbox) and one that waits (the sample).
    @ObservationIgnored private var watching: Set<String> = []
    /// Counts failed loads, for the error announcement.
    private(set) var loadAttempts = 0
    /// The last guess answer that failed, until one works; the page plays the error haptic and
    /// announces it once per failure (a queued answer, offline, is not a failure).
    private(set) var answerFailure: Flows.Failure?
    private(set) var answerFailures = 0
    /// The last send that saved nothing (the words are back in the draft), until one works.
    private(set) var sendFailure: Flows.Failure?
    private(set) var sendFailures = 0
    /// Today has finished loading once for this model; coming back to the page doesn't reload.
    @ObservationIgnored private var hasLoaded = false

    /// What the guess card says when a failed answer has no message of its own.
    static let sendFailureLine = "couldn't save that. your words are still in the box."
    static let answerFailureLine = "couldn't send your answer. try again."

    init(data: any Flows.JournalData, today: String) {
        self.data = data
        self.today = today
    }

    // MARK: - What the page reads

    var isOnline: Bool {
        data.isOnline
    }

    var isLoading: Bool {
        if case .loading = data.today {
            return true
        }
        return false
    }

    var failure: Flows.Failure? {
        if case let .failed(failure) = data.today {
            return failure
        }
        return nil
    }

    /// The thread, oldest first; empty while loading or failed.
    var thread: [Item] {
        guard case let .loaded(entries) = data.today else { return [] }
        return Self.items(entries: entries, acknowledgement: data.acknowledgement(for:), guess: data.guesses.first, today: today)
    }

    var briefCard: BriefCard? {
        Self.briefCard(data.brief, today: today, online: data.isOnline)
    }

    /// Today's brief, for the player sheet (P10 replaces this with the brief player).
    var brief: Journal.Brief? {
        if case let .loaded(.ready(brief)) = data.brief {
            return brief
        }
        return nil
    }

    /// The acknowledgement to announce: the landed entry's, once it has one.
    var landedLine: String? {
        landed.flatMap { data.acknowledgement(for: $0) }
    }

    // MARK: - Actions

    func load() async {
        await data.load()
        if failure != nil {
            loadAttempts += 1
        }
        if !Task.isCancelled {
            hasLoaded = true
        }
    }

    /// The page's `.task`: loads once per model, so coming back to the tab doesn't refetch
    /// and flash the skeleton; "try again" calls `load()`.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Sends the draft and watches it land (M08 v1). Empty words are not sent and keep the draft.
    func send(_ text: String) async {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        draft = ""
        let before = Set((data.today.value ?? []).map(\.id))
        if case let .failed(failure) = await data.send(text: words) {
            // nothing was saved: the words go back in the composer and the person is told
            if draft.isEmpty {
                draft = text
            }
            sendFailure = failure
            sendFailures += 1
            return
        }
        sendFailure = nil
        watching.formUnion((data.today.value ?? []).map(\.id).filter { !before.contains($0) })
        noteDeliveries()
    }

    func retry(_ entry: Journal.Entry) async {
        guard let id = entry.clientEntryId else { return }
        watching.insert(entry.id)
        await data.retry(clientEntryId: id)
        noteDeliveries()
    }

    /// A list that changes whenever an entry's delivery does; the page calls `noteDeliveries`
    /// on its change.
    var deliveries: [String] {
        (data.today.value ?? []).map { "\($0.id):\($0.delivery)" }
    }

    /// Sets `landed` for a watched entry that is now sent, once (it stops being watched).
    func noteDeliveries() {
        guard !watching.isEmpty else { return }
        for entry in data.today.value ?? [] where entry.delivery == .sent && watching.contains(entry.id) {
            watching.remove(entry.id)
            landed = entry.id
        }
    }

    func answer(_ guess: Journal.Guess, _ verdict: RGuessCard.Verdict) async {
        switch await data.answer(guess, verdict: verdict == .yes ? .yes : .no) {
        case .recorded, .queued:
            answerFailure = nil
        case let .failed(failure):
            answerFailure = failure
            answerFailures += 1
        }
    }

    func play() {
        playerShown = true
    }

    /// Copies your words, text only; nothing is logged.
    /// It stays on this phone (not Universal Clipboard) and expires after two minutes.
    func copy(_ entry: Journal.Entry) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: entry.text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(Self.copyLasts)]
        )
    }

    static let copyLasts: TimeInterval = 120

    /// Opens the entry (JR-4, P12); the page's host wires it.
    var openEntry: (Journal.Entry) -> Void = { _ in }
    /// Opens the drawer (JR-3, P11); the page's host wires it.
    var openDrawer: () -> Void = {}

    // MARK: - The mappings (pure)

    /// The thread from today's entries: a day label above each day's first entry, your bubble,
    /// Retro's line once the entry is sent and acknowledged, and the one guess as Retro's item
    /// after your last acknowledgement.
    static func items(
        entries: [Journal.Entry],
        acknowledgement: (String) -> String?,
        guess: Journal.Guess?,
        today: String
    ) -> [Item] {
        var items: [Item] = []
        var day: String?
        var lastRetro: Int?
        for entry in entries {
            if entry.day != day {
                day = entry.day
                items.append(.day(label: dayLabel(entry.day, today: today)))
            }
            items.append(.mine(entry))
            if entry.delivery == .sent, let id = entry.clientEntryId, let line = acknowledgement(id) {
                items.append(.retro(entryId: entry.id, line: line))
                lastRetro = items.count
            }
        }
        // A declined guess stays for the session, dimmed (C28); an expired or unknown one is gone.
        if let guess, guess.status == .offered || guess.status == .confirmed || guess.status == .declined, let at = lastRetro {
            items.insert(.guess(guess), at: at)
        }
        return items
    }

    /// The guess card's source line: "from 3 things", "from 1 thing".
    static func sourceLine(count: Int) -> String {
        switch count {
        case ..<1: "from what you've said"
        case 1: "from 1 thing"
        default: "from \(count) things"
        }
    }

    /// "today" for the person's day; otherwise the day as "tue 21 oct".
    static func dayLabel(_ day: String, today: String) -> String {
        day == today ? "today" : dateLabel(day)
    }

    private static func formatter(_ format: String, zone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let zone {
            formatter.timeZone = zone
        }
        formatter.dateFormat = format
        return formatter
    }

    private static let dayReader = formatter("yyyy-MM-dd", zone: TimeZone(identifier: "UTC"))
    private static let dayWriter = formatter("EEE d MMM", zone: TimeZone(identifier: "UTC"))
    private static let timeWriter = formatter("H:mm", zone: .autoupdatingCurrent)

    /// `YYYY-MM-DD` as "tue 21 oct", lowercase, the same in every locale.
    static func dateLabel(_ day: String) -> String {
        guard let date = dayReader.date(from: day) else { return day }
        return dayWriter.string(from: date).lowercased()
    }

    /// "8:30" in the phone's own time zone.
    static func readyBy(_ date: Date?) -> String? {
        guard let date else { return nil }
        return timeWriter.string(from: date)
    }

    /// "2 min" from the audio's length; nil when there's no audio yet.
    static func length(_ brief: Journal.Brief) -> String? {
        guard let seconds = brief.audio?.durationSeconds, seconds > 0 else { return nil }
        let minutes = Swift.max(1, Int((seconds / 60).rounded()))
        return "\(minutes) min"
    }

    /// The brief card from the slot. `.off` and `.none` draw nothing; the headline is the
    /// brief's first part and the subline its second (contract 02's brief has no title).
    static func briefCard(_ slot: Flows.Loadable<Journal.BriefSlot>, today: String, online: Bool) -> BriefCard? {
        let date = dateLabel(today)
        switch slot {
        case .loading:
            // nothing is claimed until the slot is known: not "being made" while merely loading
            return nil
        case let .failed(failure):
            if !online {
                return BriefCard(date: date, length: nil, headline: "", subline: nil, state: .offline)
            }
            return BriefCard(date: date, length: nil, headline: "", subline: nil, state: .error(message: failure.message ?? "couldn't load today's brief"))
        case let .loaded(slotValue):
            switch slotValue {
            case .off, .none:
                return nil
            case let .making(readyBy):
                return BriefCard(date: date, length: nil, headline: "", subline: nil, state: .making(readyBy: Self.readyBy(readyBy)))
            case let .quiet(line):
                return BriefCard(date: date, length: nil, headline: line, subline: nil, state: .quiet)
            case let .ready(brief):
                let parts = brief.parts.map(\.text)
                return BriefCard(
                    date: dateLabel(brief.date),
                    length: length(brief),
                    headline: parts.first ?? "",
                    subline: parts.dropFirst().first,
                    state: .rest
                )
            }
        }
    }

    static func delivery(_ entry: Journal.Entry) -> RMessageBubble.Delivery {
        switch entry.delivery {
        case .sent: .sent
        case .sending: .sending
        case .waiting: .waiting
        case .failed: .notSent
        }
    }

    /// The guess card's phase from the guess's status.
    static func phase(_ guess: Journal.Guess) -> RGuessCard.Phase {
        switch guess.status {
        case .offered, .expired, .unknown: .offered // expired and unknown never reach the thread
        case .confirmed: .confirmed
        case .declined: .declined
        }
    }

    /// Scrolled up past 8pt from the bottom anchor: the bar and the card compact (the card's
    /// "compute collapsed from the distance to the bottom anchor").
    static func collapsed(distanceToBottom: CGFloat) -> Bool {
        distanceToBottom > RDimension.space2
    }

    /// The top edge's blur band grows with the scroll, up to blur.journalTop.band.
    static func topBand(steps: Int) -> CGFloat {
        Swift.min(RDimension.blurJournalTopBand, CGFloat(Swift.max(steps, 0)) * RDimension.space2)
    }
}
