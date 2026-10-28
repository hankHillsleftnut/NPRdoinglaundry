//
//  JournalViewModel.swift
//  P09 JR-1: what the journal page shows, from the flow (docs/team/ui/P09.md). The view model
//  turns `Flows.JournalData` (today's entries with their outbox state, the brief slot, the
//  guesses, online) into the thread's items and the brief card's state, and owns what the page
//  itself decides: the composer's draft, the collapse from the scroll, which entry this session
//  watched go from sending to sent (the M08 land: the `confirm` haptic and the one VoiceOver
//  announcement), the brief's play through the one player (C26.1), the text sheet and the drawer. Every mapping is a pure function, so the
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
    /// The text sheet (P10's placeholder): the card's body, and the play when there is no sound to play.
    var playerShown = false
    /// The one player (`\.playback`, PLP.1a), built for the signed-in person and dropped on sign-out; nil on
    /// the sample page, whose play opens the text sheet. Held weakly: once the person signs out the page
    /// keeps no player of theirs.
    @ObservationIgnored weak var playback: (any Flows.Playback)?
    /// From a tap on the play until the player answers it: the card turns the starting ring.
    private(set) var starting: Starting?
    /// The entry this session watched go from sending to sent: the acknowledgement is announced
    /// once and the `confirm` haptic fires once, for it; a thread loaded already sent never does.
    private(set) var landed: String?
    /// The entries this session sent or retried that haven't been seen sent yet. `landed` is set
    /// when one of these turns `.sent` in the data, whenever that happens, so it works the same
    /// for a send that returns at once (the outbox) and one that waits (the sample).
    @ObservationIgnored private var watching: Set<String> = []
    /// Sends that saved but whose row hasn't shown up yet: the live store delivers the row after
    /// `send` returns (its observation is asynchronous), so the row is claimed when it arrives:
    /// an id that wasn't in the thread when the send began, with the words that were sent.
    @ObservationIgnored private var awaiting: [Awaited] = []
    /// Every row ever claimed for a send, so one row is never claimed twice.
    @ObservationIgnored private var claimed: Set<String> = []
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

    /// What the page shows and announces when a failed load has no message of its own.
    static let loadFailureLine = "retro couldn't be reached. try again."
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

    /// The failed load's words, shown and announced: the server's message, else the fallback.
    var failureLine: String? {
        failure.map { $0.message ?? Self.loadFailureLine }
    }

    /// The thread, oldest first; empty while loading or failed.
    var thread: [Item] {
        guard case let .loaded(entries) = data.today else { return [] }
        return Self.items(entries: entries, acknowledgement: data.acknowledgement(for:), guess: data.guesses.first, today: today)
    }

    var briefCard: BriefCard? {
        guard let card = Self.briefCard(data.brief, today: today, online: data.isOnline) else { return nil }
        guard card.state == .rest else { return card }
        let state = Self.playState(starting: starting != nil, player: player?.state)
        return BriefCard(date: card.date, length: card.length, headline: card.headline, subline: card.subline, state: state)
    }

    /// What the player is doing with today's brief: nil when it holds nothing, or something else.
    var player: Player? {
        guard let brief, let playback, let item = playback.item, item.id == brief.id else { return nil }
        return Player(id: item.id, state: playback.state)
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
            // nothing was saved: the words go back in the composer, ahead of anything typed
            // since, and the person is told
            draft = Self.restored(failed: text, typed: draft)
            sendFailure = failure
            sendFailures += 1
            return
        }
        sendFailure = nil
        awaiting.append(Awaited(words: words, before: before))
        noteDeliveries()
    }

    /// The draft after a send that saved nothing: the failed words, then whatever was typed
    /// while it was on its way. Neither is dropped.
    static func restored(failed: String, typed: String) -> String {
        if typed.isEmpty {
            return failed
        }
        let words = failed.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? typed : words + " " + typed
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
        claimArrivals()
        guard !watching.isEmpty else { return }
        for entry in data.today.value ?? [] where entry.delivery == .sent && watching.contains(entry.id) {
            watching.remove(entry.id)
            landed = entry.id
        }
    }

    /// Watches the rows of sends that arrived since the last look (oldest send first).
    private func claimArrivals() {
        guard !awaiting.isEmpty else { return }
        for entry in data.today.value ?? [] where !claimed.contains(entry.id) {
            guard let index = awaiting.firstIndex(where: { $0.words == entry.text && !$0.before.contains(entry.id) }) else {
                continue
            }
            awaiting.remove(at: index)
            claimed.insert(entry.id)
            watching.insert(entry.id)
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

    /// The lit play: today's brief through the one player. The first tap loads it and starts it (the ring
    /// turns until it plays); a tap while it plays pauses it, another resumes it. With no player (the
    /// sample) or no audio, or when the player can't get the sound (offline, failed), the text sheet opens.
    func play() async {
        guard let brief, let audio = brief.audio, let playback else {
            showBrief()
            return
        }
        if starting != nil {
            // a second tap while it starts: the person changed their mind
            starting = nil
            playback.pause()
            return
        }
        if toggle(playback, briefID: brief.id) {
            return
        }
        starting = .loading
        await playback.load(Self.item(for: brief, audio: audio))
        // a tap during the load stopped it, or another person's sign-out unloaded the player
        guard starting == .loading else { return }
        if player?.state == .paused {
            starting = .asked
            playback.play()
        }
        notePlayback()
    }

    /// The card's body: the text sheet (P10 replaces it with the brief player).
    func open() {
        showBrief()
    }

    /// The brief's sheet: the host's (JR-2, when it gives one: `openBrief`), else the text sheet.
    private func showBrief() {
        if let openBrief {
            openBrief()
        } else {
            playerShown = true
        }
    }

    /// Pauses or resumes the brief the player already holds; false when there is nothing of it to play
    /// (another item, nothing loaded, or a load that ended offline or failed), which loads it again.
    private func toggle(_ playback: any Flows.Playback, briefID: String) -> Bool {
        guard playback.item?.id == briefID else { return false }
        switch playback.state {
        case .playing, .buffering:
            playback.pause()
            return true
        case .paused, .ended:
            playback.play()
            return true
        case .idle, .failed, .offline:
            return false
        }
    }

    /// The page calls this when the player's state changes: the ring stops once the player plays, stops by
    /// itself (a call, the headphones out) or gives up; giving up opens the text sheet instead. Nothing here
    /// ever starts the sound again: only the person's tap does (the player's rule).
    func notePlayback() {
        guard let start = starting else { return }
        guard let player else {
            // the brief left the player (another item, or the sign-out unload)
            starting = nil
            return
        }
        starting = Self.next(start, after: player.state)
        if starting == nil, Self.gaveUp(player.state) {
            showBrief()
        }
    }

    /// The player couldn't get the sound: offline and not on the phone, or it failed.
    static func gaveUp(_ state: Flows.PlaybackState) -> Bool {
        switch state {
        case .failed, .offline: true
        case .idle, .buffering, .playing, .paused, .ended: false
        }
    }

    /// Where a start goes when the player says `state`.
    static func next(_ start: Starting, after state: Flows.PlaybackState) -> Starting? {
        switch state {
        case .idle, .playing, .ended, .failed, .offline:
            nil
        case .buffering:
            start == .asked ? .answered : start
        case .paused:
            // paused after it had begun: it stopped by itself. Paused before: the load's own rest.
            start == .answered ? nil : start
        }
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

    /// An entry's long-press menu: copy, and "open this entry ›" only once the entry page is
    /// wired (a row that does nothing is never drawn).
    func menu(for entry: Journal.Entry) -> [RMenuRow] {
        var rows = [RMenuRow(id: "copy", title: "copy", symbol: "doc.on.doc") { [weak self] in self?.copy(entry) }]
        if let open = openEntry {
            rows.append(RMenuRow(id: "open", title: "open this entry", symbol: "arrow.up.right", opensMore: true) { open(entry) })
        }
        return rows
    }

    /// Opens the entry (JR-4, P12); the page's host wires it. Nil until JR-4 exists: the menu
    /// then offers copy only (no dead controls).
    var openEntry: ((Journal.Entry) -> Void)?
    /// The composer offers the mic. Off on the live page until voice capture exists, so the
    /// corner button is only the send (no dead controls).
    var voice = false
    /// Opens the drawer (JR-3, P11); the page's host wires it.
    var openDrawer: (() -> Void)? = {}
    /// ON-13 first home: the welcome, the setup recap and the ready first episode (nil on every other day).
    var firstDay: FirstDay?
    /// Opens today's brief in the host's player sheet (JR-2, the demo's shell); nil: the text sheet.
    var openBrief: (() -> Void)?

    // MARK: - The mappings (pure)

    /// How far a tap on the play has got: the brief is loading; loaded and asked to play; the player
    /// has begun (it buffered).
    enum Starting: Equatable {
        case loading
        case asked
        case answered
    }

    /// The player's hold on today's brief, for the page to watch.
    struct Player: Equatable {
        let id: String
        let state: Flows.PlaybackState
    }

    /// The ready card's play, from the tap and the player's state for this brief: the ring while it
    /// buffers, and from the tap until the player answers; at rest otherwise. Never the ring once the
    /// player plays, gives up or holds nothing.
    static func playState(starting: Bool, player: Flows.PlaybackState?) -> RBriefCard.State {
        switch player {
        case .buffering:
            .starting
        case .paused, nil:
            starting ? .starting : .rest
        case .idle, .playing, .ended, .failed, .offline:
            .rest
        }
    }

    /// Today's brief as the player's item: its parts in spoken order with where each starts (a part with
    /// no start yet starts where the one before it did), and the audio's length.
    static func item(for brief: Journal.Brief, audio: Journal.Brief.Audio) -> Flows.PlaybackItem {
        var start = 0.0
        let parts = brief.parts.enumerated().map { index, part in
            start = part.startSeconds ?? start
            return Flows.PlaybackItem.Part(id: index, title: nil, text: part.text, startSeconds: start)
        }
        return Flows.PlaybackItem(id: brief.id, kind: .brief, title: "today's brief", parts: parts, durationSeconds: audio.durationSeconds)
    }

    /// A send waiting for its row.
    private struct Awaited {
        let words: String
        let before: Set<String>
    }

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
