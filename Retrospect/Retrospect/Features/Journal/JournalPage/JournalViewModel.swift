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
    /// Counts failed loads, for the error announcement.
    private(set) var loadAttempts = 0

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
    }

    /// Sends the draft and watches it land (M08 v1): the id it gets is the one not there before.
    func send(_ text: String) async {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        draft = ""
        let before = Set((data.today.value ?? []).map(\.id))
        await data.send(text: words)
        if let new = (data.today.value ?? []).first(where: { !before.contains($0.id) }), new.delivery == .sent {
            landed = new.id
        }
    }

    func retry(_ entry: Journal.Entry) async {
        guard let id = entry.clientEntryId else { return }
        await data.retry(clientEntryId: id)
        if (data.today.value ?? []).first(where: { $0.id == entry.id })?.delivery == .sent {
            landed = entry.id
        }
    }

    func answer(_ guess: Journal.Guess, _ verdict: RGuessCard.Verdict) async {
        _ = await data.answer(guess, verdict: verdict == .yes ? .yes : .no)
    }

    func play() {
        playerShown = true
    }

    /// Copies your words, text only; nothing is logged.
    func copy(_ entry: Journal.Entry) {
        UIPasteboard.general.string = entry.text
    }

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
        if let guess, guess.status == .offered || guess.status == .confirmed, let at = lastRetro {
            items.insert(.guess(guess), at: at)
        }
        return items
    }

    /// "today" for the person's day; otherwise the day as "tue 21 oct".
    static func dayLabel(_ day: String, today: String) -> String {
        day == today ? "today" : dateLabel(day)
    }

    /// `YYYY-MM-DD` as "tue 21 oct", lowercase, the same in every locale.
    static func dateLabel(_ day: String) -> String {
        let reader = DateFormatter()
        reader.locale = Locale(identifier: "en_US_POSIX")
        reader.timeZone = TimeZone(identifier: "UTC")
        reader.dateFormat = "yyyy-MM-dd"
        guard let date = reader.date(from: day) else { return day }
        let writer = DateFormatter()
        writer.locale = Locale(identifier: "en_US_POSIX")
        writer.timeZone = TimeZone(identifier: "UTC")
        writer.dateFormat = "EEE d MMM"
        return writer.string(from: date).lowercased()
    }

    /// "8:30" in the phone's own time zone.
    static func readyBy(_ date: Date?) -> String? {
        guard let date else { return nil }
        let writer = DateFormatter()
        writer.locale = Locale(identifier: "en_US_POSIX")
        writer.dateFormat = "H:mm"
        return writer.string(from: date)
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
            return BriefCard(date: date, length: nil, headline: "", subline: nil, state: .making(readyBy: nil))
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
        case .offered, .expired, .unknown: .offered
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
