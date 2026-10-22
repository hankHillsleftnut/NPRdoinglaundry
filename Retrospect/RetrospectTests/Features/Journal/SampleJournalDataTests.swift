import Foundation
@testable import Retrospect
import Testing

/// UI1.0: the journal's sample data behaves like the seam promises, on an injected clock, and its
/// content is contract 02's fixtures wherever a fixture exists.
@MainActor
struct SampleJournalDataTests {
    typealias Journal = Flows.Journal
    typealias Content = SampleJournalContent

    private func decoded<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder.contract.decode(ContractFixtureTests.Envelope<T>.self, from: Fixtures.data("02", name)).data
    }

    /// Lets every task the test started run until it waits on the clock (or ends).
    private func settle(_ clock: TestClock, waiting count: Int) async {
        for _ in 0 ..< 1000 where clock.pendingSleeps < count {
            await Task.yield()
        }
    }

    // MARK: - Scenarios

    @Test("every scenario loads without a crash", arguments: JournalScenario.allCases.filter { $0 != .loading })
    func everyScenarioLoads(scenario: JournalScenario) async {
        let data = SampleJournalData(scenario: scenario, clock: TestClock())
        await data.load()
        switch data.today {
        case .loaded, .failed: break
        case .loading: Issue.record("\(scenario.rawValue) is still loading")
        }
    }

    @Test("loading never resolves within 60 simulated seconds")
    func loadingNeverResolves() async {
        let clock = TestClock()
        let data = SampleJournalData(scenario: .loading, clock: clock)
        let load = Task { await data.load() }
        await settle(clock, waiting: 1)
        for _ in 0 ..< 60 {
            clock.advance(by: .seconds(1))
            await Task.yield()
        }
        #expect(data.today == .loading)
        #expect(data.brief == .loading)
        load.cancel()
        await load.value
        #expect(clock.heldSleeps == 0)
    }

    // MARK: - Content from the fixtures

    @Test("today's fixture entries are entries.today.json's, field for field")
    func todayMatchesFixture() throws {
        let fixture = try decoded(ContractFixtureTests.Today.self, "entries.today").entries
        #expect(Array(Content.todayEntries.prefix(fixture.count)) == fixture)
    }

    @Test("the brief, the quiet line, the guess and what Retro took are the fixtures'")
    func modelsMatchFixtures() throws {
        #expect(try decoded(ContractFixtureTests.LatestBrief.self, "brief.latest.v1").brief == Content.brief)
        #expect(try decoded(ContractFixtureTests.LatestBrief.self, "brief.latest.quiet").brief?.parts.first?.text == Content.quietLine)
        #expect(try decoded(ContractFixtureTests.Guesses.self, "guesses").guesses == [Content.guess(.offered)])
        #expect(try decoded(Journal.Took.self, "took") == Content.took)
        #expect(try decoded(Journal.Took.self, "took.waiting") == Content.tookWaiting)
    }

    @Test("the correction outcomes are the fixtures'")
    func correctionsMatchFixtures() throws {
        let outcome = { (name: String) in try decoded(Journal.CorrectionOutcome.self, name) }
        #expect(try outcome("correction.applied") == Content.applied)
        #expect(try outcome("correction.confirm") == Content.confirm)
        #expect(try outcome("correction.ask") == Content.askOwnWords)
        #expect(try outcome("correction.confirm.response") == Content.confirmed)
    }

    @Test("the server failure carries error.internal.json's message")
    func failureMatchesFixture() throws {
        let body = try JSONDecoder.contract.decode(ContractFixtureTests.FailureEnvelope.self, from: Fixtures.data("02", "error.internal")).error
        #expect(body.message == Content.serverFailure.message)
    }

    // MARK: - Sending

    @Test("a retry in notSent moves the entry to sent after the clock advances one second")
    func retrySendsAfterOneSecond() async {
        let clock = TestClock()
        let data = SampleJournalData(scenario: .notSent, clock: clock)
        await data.load()
        guard let last = data.today.value?.last, let id = last.clientEntryId else {
            Issue.record("no last entry")
            return
        }
        #expect(last.delivery == .failed(.network))
        let retry = Task { await data.retry(clientEntryId: id) }
        await settle(clock, waiting: 1)
        #expect(data.today.value?.last?.delivery == .sending)
        #expect(data.acknowledgement(for: id) == nil)
        clock.advance(by: .milliseconds(999))
        await Task.yield()
        #expect(data.today.value?.last?.delivery == .sending)
        clock.advance(by: .milliseconds(1))
        await retry.value
        #expect(data.today.value?.last?.delivery == .sent)
        #expect(data.acknowledgement(for: id) != nil)
    }

    @Test("the acknowledgement appears only once an entry is sent")
    func acknowledgementOnlyAfterSent() async {
        let clock = TestClock()
        let data = SampleJournalData(scenario: .full, clock: clock)
        await data.load()
        let send = Task { await data.send(text: "a new line") }
        await settle(clock, waiting: 1)
        guard let id = data.today.value?.last?.clientEntryId else {
            Issue.record("the sent entry isn't in today")
            return
        }
        #expect(data.acknowledgement(for: id) == nil)
        clock.advance(by: SampleJournalData.sendDelay)
        await send.value
        #expect(data.acknowledgement(for: id) != nil)
    }

    @Test("the acknowledgement never repeats twice in a row over 100 sends")
    func acknowledgementsNeverRepeat() async {
        let clock = TestClock()
        let data = SampleJournalData(scenario: .dayOne, clock: clock)
        await data.load()
        var previous: String?
        for index in 0 ..< 100 {
            let send = Task { await data.send(text: "line \(index)") }
            await settle(clock, waiting: 1)
            clock.advance(by: SampleJournalData.sendDelay)
            await send.value
            let line = data.today.value?.last?.clientEntryId.flatMap { data.acknowledgement(for: $0) }
            #expect(line != nil)
            #expect(line != previous)
            previous = line
        }
    }

    @Test("offline, a new entry waits and nothing is sent")
    func offlineEntriesWait() async {
        let clock = TestClock()
        let data = SampleJournalData(scenario: .offline, clock: clock)
        await data.load()
        await data.send(text: "on the train")
        #expect(data.today.value?.last?.delivery == .waiting)
        #expect(clock.heldSleeps == 0)
    }

    // MARK: - The drawer

    @Test("search marks every match in UTF-16 units, as entries.search.json does")
    func searchMarksMatches() async throws {
        let data = SampleJournalData(scenario: .searchHit, clock: TestClock())
        await data.load()
        let page = try await data.entries(cursor: nil, query: "canal").get()
        let fixture = try decoded(ContractFixtureTests.EntryPage.self, "entries.search").entries[0]
        let hit = page.items.first { $0.id == fixture.id }
        #expect(hit?.matches == fixture.matches)
        #expect(try await data.entries(cursor: nil, query: "kayak").get().items.isEmpty)
    }

    @Test("the long drawer pages at 50, then ends")
    func longDrawerPages() async throws {
        let data = SampleJournalData(scenario: .long, clock: TestClock())
        await data.load()
        let first = try await data.entries(cursor: nil, query: nil).get()
        #expect(first.items.count == SampleJournalData.pageSize)
        let second = try await data.entries(cursor: first.nextCursor, query: nil).get()
        #expect(second.nextCursor == nil)
        #expect(first.items.count + second.items.count == 60 + 7)
    }

    @Test("a guess answered with an error goes back to how it was")
    func guessErrorRestores() async {
        let data = SampleJournalData(scenario: .guessError, clock: TestClock())
        await data.load()
        let guess = Content.guess(.offered)
        let outcome = await data.answer(guess, verdict: .yes)
        #expect(outcome == .failed(.network))
        #expect(data.guesses == [guess])
    }
}
