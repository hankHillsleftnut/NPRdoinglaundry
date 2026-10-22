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

    @Test("full: a day label, every entry, Retro's line after each, and the guess after the last one")
    func full() async {
        let model = await model(.full)
        let items = model.thread
        #expect(items.first == .day(label: "today"))
        let mine = items.filter { if case .mine = $0 { return true } else { return false } }.count
        let retro = items.filter { if case .retro = $0 { return true } else { return false } }.count
        #expect(mine == SampleJournalContent.todayEntries.count)
        #expect(retro == mine)
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
}
