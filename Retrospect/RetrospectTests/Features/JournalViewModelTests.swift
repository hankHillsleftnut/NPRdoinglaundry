import Foundation
import Observation
@testable import Retrospect
import Testing

/// P09: the view model's state mapping per scenario, on the sample data through the seam.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct JournalViewModelTests {
    private func model(_ scenario: JournalScenario) async -> JournalViewModel {
        let model = JournalViewModel(data: SampleJournalData(scenario: scenario), today: SampleJournalContent.today)
        if scenario != .loading {
            await model.load()
        }
        return model
    }

    @Test("full: a day label, every entry, Retro's line after each acknowledged one, and the guess after the last one")
    func full() async {
        let model = await model(.full)
        let items = model.thread
        #expect(items.first == .day(label: "today"))
        let mine = items.filter {
            if case .mine = $0 {
                return true
            } else {
                return false
            }
        }.count
        let retro = items.filter {
            if case .retro = $0 {
                return true
            } else {
                return false
            }
        }.count
        #expect(mine == SampleJournalContent.todayEntries.count)
        // an imported entry has no client id, so Retro has nothing to say after it yet
        #expect(retro == SampleJournalContent.todayEntries.filter { $0.clientEntryId != nil }.count)
        if case .guess = items.last {} else {
            Issue.record("the guess sits after the last acknowledgement")
        }
        #expect(model.briefCard?.state == .rest)
        #expect(model.briefCard?.headline == SampleJournalContent.brief.parts[0].text)
        #expect(model.isOnline)
    }

    @Test("day one: no entries, the brief being made by 8:30, no guess")
    func dayOne() async {
        let model = await model(.dayOne)
        #expect(model.thread.isEmpty)
        #expect(model.briefCard?.state == .making(readyBy: "8:30"))
    }

    @Test("brief off draws no card; quiet, error and offline draw theirs")
    func briefSlots() async {
        #expect(await model(.briefOff).briefCard == nil)
        #expect(await model(.briefQuiet).briefCard?.state == .quiet)
        #expect(await model(.briefQuiet).briefCard?.headline == SampleJournalContent.quietLine)
        #expect(await model(.briefError).briefCard?.state == .error(message: "Something went wrong on our side."))
        #expect(await model(.offline).isOnline == false)
    }

    @Test("sending, not sent and offline map to the bubble's deliveries")
    func deliveries() async {
        func last(_ scenario: JournalScenario) async -> RMessageBubble.Delivery? {
            let items = await model(scenario).thread
            for item in items.reversed() {
                if case let .mine(entry) = item {
                    return JournalViewModel.delivery(entry)
                }
            }
            return nil
        }
        #expect(await last(.sending) == .sending)
        #expect(await last(.notSent) == .notSent)
        #expect(await last(.offline) == .waiting)
    }

    @Test("an entry that hasn't sent has no acknowledgement after it")
    func honesty() async {
        let items = await model(.sending).thread
        if case .retro = items.last {
            Issue.record("Retro answered an entry that hasn't sent")
        }
    }

    @Test("loading stays loading; a failed load carries the failure")
    func loadingAndError() async {
        let loading = await model(.loading)
        #expect(loading.isLoading)
        let failed = await model(.errorNetwork)
        #expect(failed.failure?.kind == .network)
        #expect(failed.thread.isEmpty)
        #expect(failed.loadAttempts == 1)
    }

    @Test("a send lands: the new entry is sent, and it is the one this session watched")
    func sendLands() async {
        let model = await model(.full)
        await model.send("walked the long way home by the canal. felt lighter after.")
        #expect(model.landed != nil)
        #expect(model.landedLine != nil)
        #expect(model.draft.isEmpty)
    }

    @Test("the day label is today for the person's day, else the date")
    func dayLabels() {
        #expect(JournalViewModel.dayLabel("2026-10-21", today: "2026-10-21") == "today")
        #expect(JournalViewModel.dayLabel("2026-10-20", today: "2026-10-21") == "tue 20 oct")
    }

    @Test("the collapse happens past 8pt from the bottom, and the top band grows to 80")
    func scroll() {
        #expect(!JournalViewModel.collapsed(distanceToBottom: 8))
        #expect(JournalViewModel.collapsed(distanceToBottom: 9))
        #expect(JournalViewModel.topBand(steps: 0) == 0)
        #expect(JournalViewModel.topBand(steps: 5) == 40)
        #expect(JournalViewModel.topBand(steps: 50) == RDimension.blurJournalTopBand)
    }

    // MARK: - Landing, watched

    @Test("a send that returns at once, as the outbox does, lands when the data later says sent: once")
    func landsWhenSentLater() async {
        let data = ScriptedJournalData(entries: SampleJournalContent.todayEntries)
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.load()
        model.noteDeliveries()
        #expect(model.landed == nil, "a thread loaded already sent never lands")

        await model.send("walked the long way home")
        #expect(model.landed == nil, "saved on the phone, not sent yet")
        let id = data.lastID
        data.set(.sending, for: id)
        model.noteDeliveries()
        #expect(model.landed == nil)

        data.set(.sent, for: id)
        model.noteDeliveries()
        #expect(model.landed == id)
        #expect(model.landedLine == "got it.")
    }

    @Test("a watched entry lands once")
    func landsOnce() async {
        let data = ScriptedJournalData(entries: [])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.load()
        await model.send("one")
        let first = data.lastID
        data.set(.sent, for: first)
        model.noteDeliveries()
        #expect(model.landed == first)

        await model.send("two")
        let second = data.lastID
        data.set(.waiting, for: first)
        data.set(.sent, for: first)
        model.noteDeliveries()
        #expect(model.landed == first, "the first is no longer watched; the second hasn't sent")
        data.set(.sent, for: second)
        model.noteDeliveries()
        #expect(model.landed == second)
    }

    @Test("a retry that later sends lands too")
    func retryLands() async {
        let failed = Flows.Journal.Entry(
            local: "00000000-0000-4000-8000-000000009001", kind: .typed, text: "late one",
            createdAt: Date(timeIntervalSince1970: 1_792_569_000), day: SampleJournalContent.today,
            delivery: .failed(SampleJournalContent.networkFailure)
        )
        let data = ScriptedJournalData(entries: [failed])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.load()

        await model.retry(failed)
        #expect(model.landed == nil)
        data.set(.sent, for: failed.id)
        model.noteDeliveries()
        #expect(model.landed == failed.id)
    }

    @Test("empty words are not sent and the draft stays")
    func emptyIsNotSent() async {
        let data = ScriptedJournalData(entries: [])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.load()
        model.draft = "  \n "
        await model.send("  \n ")
        #expect(data.sent.isEmpty)
        #expect(model.draft == "  \n ")
    }

    @Test("a send that saved nothing gives the words back and is announced; the next good send clears it")
    func failedSendRestoresTheDraft() async {
        let data = ScriptedJournalData(entries: [])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.load()
        data.sendOutcome = .failed(Flows.Failure(.unknown))
        model.draft = "my words"

        await model.send("my words")

        #expect(model.draft == "my words")
        #expect(model.sendFailure != nil)
        #expect(model.sendFailures == 1)
        #expect(data.sent.isEmpty)

        data.sendOutcome = nil
        await model.send("my words")
        #expect(model.sendFailure == nil)
        #expect(model.draft.isEmpty)
    }

    // MARK: - A guess answer

    @Test("an answer that fails is kept for the page's error haptic and announcement; recorded and queued are not failures")
    func answerOutcomes() async {
        let guess = SampleJournalContent.guess(.offered)
        let data = ScriptedJournalData(entries: [])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)

        data.outcome = .failed(SampleJournalContent.networkFailure)
        await model.answer(guess, .yes)
        #expect(model.answerFailure == SampleJournalContent.networkFailure)
        #expect(model.answerFailures == 1)

        await model.answer(guess, .no)
        #expect(model.answerFailures == 2)

        data.outcome = .queued
        await model.answer(guess, .yes)
        #expect(model.answerFailure == nil)

        data.outcome = .failed(SampleJournalContent.networkFailure)
        await model.answer(guess, .yes)
        data.outcome = .recorded(.confirmed)
        await model.answer(guess, .yes)
        #expect(model.answerFailure == nil)
        #expect(model.answerFailures == 3)
    }

    // MARK: - The thread

    @Test("a declined guess stays in the thread for the session; an expired one does not")
    func declinedStays() {
        let entry = SampleJournalContent.todayEntries[0]
        func hasGuess(_ status: Flows.Journal.Guess.Status) -> Bool {
            JournalViewModel.items(
                entries: [entry], acknowledgement: { _ in "got it." }, guess: SampleJournalContent.guess(status), today: SampleJournalContent.today
            ).contains {
                if case .guess = $0 {
                    true
                } else {
                    false
                }
            }
        }
        #expect(hasGuess(.offered))
        #expect(hasGuess(.confirmed))
        #expect(hasGuess(.declined))
        #expect(!hasGuess(.expired))
        #expect(!hasGuess(.unknown))
        #expect(JournalViewModel.phase(SampleJournalContent.guess(.declined)) == .declined)
        #expect(JournalViewModel.phase(SampleJournalContent.guess(.confirmed)) == .confirmed)
        #expect(JournalViewModel.phase(SampleJournalContent.guess(.offered)) == .offered)
    }

    @Test("no acknowledgement yet, no guess (it comes after Retro's line)")
    func noGuessWithoutAcknowledgement() {
        let items = JournalViewModel.items(
            entries: [SampleJournalContent.todayEntries[0]], acknowledgement: { _ in nil },
            guess: SampleJournalContent.guess(.offered), today: SampleJournalContent.today
        )
        #expect(!items.contains {
            if case .guess = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test("days: a label above each day's first entry, today as 'today', in order")
    func multipleDays() {
        func entry(_ id: String, _ day: String) -> Flows.Journal.Entry {
            Flows.Journal.Entry(local: id, kind: .typed, text: id, createdAt: Date(timeIntervalSince1970: 0), day: day, delivery: .sent)
        }
        let items = JournalViewModel.items(
            entries: [entry("a", "2026-10-20"), entry("b", "2026-10-20"), entry("c", "2026-10-21")],
            acknowledgement: { _ in nil }, guess: nil, today: "2026-10-21"
        )
        #expect(items.map(\.id) == ["day-tue 20 oct", "a", "b", "day-today", "c"])
    }

    @Test("the guess card says 'thing' for one and 'things' for the rest")
    func sourceLine() {
        #expect(JournalViewModel.sourceLine(count: 1) == "from 1 thing")
        #expect(JournalViewModel.sourceLine(count: 2) == "from 2 things")
        #expect(JournalViewModel.sourceLine(count: 0) == "from what you've said")
    }

    // MARK: - The brief card

    @Test("while the brief is loading nothing is claimed; failed shows offline or the error")
    func briefLoadingAndFailed() {
        let today = SampleJournalContent.today
        #expect(JournalViewModel.briefCard(.loading, today: today, online: true) == nil)
        #expect(JournalViewModel.briefCard(.failed(SampleJournalContent.serverFailure), today: today, online: false)?.state == .offline)
        #expect(
            JournalViewModel.briefCard(.failed(SampleJournalContent.serverFailure), today: today, online: true)?.state
                == .error(message: "Something went wrong on our side.")
        )
    }

    @Test("a malformed day stays as it is; the length rounds to the nearest minute, at least one")
    func labelsAndLength() {
        #expect(JournalViewModel.dateLabel("not a day") == "not a day")
        func brief(seconds: Double) -> Flows.Journal.Brief {
            let base = SampleJournalContent.brief
            return Flows.Journal.Brief(
                id: base.id, date: base.date, kind: base.kind, parts: base.parts,
                audio: .init(url: URL(fileURLWithPath: "/a.m4a"), expiresAt: Date(), durationSeconds: seconds),
                createdAt: base.createdAt
            )
        }
        #expect(JournalViewModel.length(brief(seconds: 89)) == "1 min")
        #expect(JournalViewModel.length(brief(seconds: 90)) == "2 min")
        #expect(JournalViewModel.length(brief(seconds: 10)) == "1 min")
        #expect(JournalViewModel.length(brief(seconds: 0)) == nil)
    }

    @Test("load happens once per model; try again loads again")
    func loadsOnce() async {
        let data = ScriptedJournalData(entries: [])
        let model = JournalViewModel(data: data, today: SampleJournalContent.today)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(data.loads == 1)
        await model.load()
        #expect(data.loads == 2)
    }
}

/// A journal data source that answers like the live one will: `send` saves at once (`.waiting`)
/// and returns; the test moves the delivery on.
@MainActor
@Observable
final class ScriptedJournalData: Flows.JournalData {
    typealias Journal = Flows.Journal

    private(set) var today: Flows.Loadable<[Journal.Entry]>
    private(set) var brief: Flows.Loadable<Journal.BriefSlot> = .loaded(.off)
    private(set) var guesses: [Journal.Guess] = []
    private(set) var isOnline = true
    @ObservationIgnored var sendOutcome: Journal.WriteOutcome?
    @ObservationIgnored var outcome: Journal.GuessOutcome = .recorded(.confirmed)
    @ObservationIgnored private(set) var loads = 0
    @ObservationIgnored private(set) var sent: [String] = []
    @ObservationIgnored private(set) var lastID = ""

    init(entries: [Journal.Entry]) {
        today = .loaded(entries)
    }

    func set(_ delivery: Journal.Entry.Delivery, for id: String) {
        guard case var .loaded(entries) = today, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].delivery = delivery
        today = .loaded(entries)
    }

    func load() async {
        loads += 1
    }

    func send(text: String) async -> Journal.WriteOutcome {
        if let sendOutcome {
            return sendOutcome
        }
        sent.append(text)
        lastID = "00000000-0000-4000-8000-\(String(format: "%012d", sent.count + 7000))"
        today = .loaded((today.value ?? []) + [Journal.Entry(
            local: lastID, kind: .typed, text: text, createdAt: Date(timeIntervalSince1970: 1_792_570_000),
            day: SampleJournalContent.today, delivery: .waiting
        )])
        return .queued
    }

    func sendVoice(_: Journal.VoiceNote) async {}

    func retry(clientEntryId: String) async {
        set(.waiting, for: clientEntryId)
    }

    func acknowledgement(for _: String) -> String? {
        "got it."
    }

    func answer(_: Journal.Guess, verdict _: Journal.GuessVerdict) async -> Journal.GuessOutcome {
        outcome
    }

    func entries(cursor _: String?, query _: String?) async -> Result<Flows.Page<Journal.Entry>, Flows.Failure> {
        .failure(.notFound)
    }

    func entry(id _: String) async -> Result<Journal.Entry, Flows.Failure> {
        .failure(.notFound)
    }

    func edit(id _: String, text _: String) async -> Journal.WriteOutcome {
        .done
    }

    func delete(id _: String) async -> Journal.WriteOutcome {
        .done
    }

    func tookUpdates(id _: String) -> AsyncStream<Result<Journal.Took, Flows.Failure>> {
        AsyncStream { $0.finish() }
    }

    func correct(text _: String, about _: Journal.ClaimRef?) async -> Journal.CorrectionOutcome {
        .notACorrection
    }

    func confirm(_: Journal.ClaimRef, mode _: Journal.CorrectionMode, note _: String?) async -> Journal.CorrectionOutcome {
        .notACorrection
    }
}
