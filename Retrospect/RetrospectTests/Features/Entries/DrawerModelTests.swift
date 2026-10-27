import Observation
@testable import Retrospect
import Testing

/// V2.journal · JR-3: the drawer's model on its sample data. Days group newest first with Paper's
/// labels, the meta line carries only the contract's fields, search finds and highlights, an empty
/// search says so, a row that didn't send retries, and offline is said once.
@MainActor
struct DrawerModelTests {
    private func model(_ scenario: EntriesScenario, query: String? = nil) -> DrawerModel {
        DrawerModel(
            data: SampleEntriesData(scenario: scenario, sendBeat: .zero),
            query: query ?? scenario.query,
            hereID: SampleEntriesData.hereID,
            debounce: .zero
        )
    }

    private func sections(_ model: DrawerModel) -> [DrawerModel.Section] {
        if case let .list(sections) = model.state {
            return sections
        }
        return []
    }

    @Test("rest: four days, newest first, with Paper's labels")
    func restDays() async {
        let drawer = model(.rest)
        await drawer.load()
        #expect(sections(drawer).map(\.title) == ["today", "yesterday", "sun 19 oct", "sat 18 oct"])
        #expect(sections(drawer).first?.rows.first?.words == "i think it's the 9am standup. i dread it.")
    }

    @Test("the meta line is the kind and the time, read in the person's time zone")
    func metaLine() async {
        let drawer = model(.rest)
        await drawer.load()
        let rows = sections(drawer).flatMap(\.rows)
        #expect(rows.first?.meta == "written · 9:12")
        #expect(rows.contains { $0.meta == "voice note · 18:05" })
        #expect(rows.contains { $0.meta == "written · 8:02" })
    }

    @Test("the entry the journal shows is the one 'here' row")
    func hereRow() async {
        let drawer = model(.rest)
        await drawer.load()
        let here = sections(drawer).flatMap(\.rows).filter(\.here)
        #expect(here.map(\.id) == [SampleEntriesData.hereID])
    }

    @Test("empty: nothing written yet")
    func empty() async {
        let drawer = model(.empty)
        await drawer.load()
        #expect(drawer.state == .empty)
    }

    @Test("searching: one group of matches, day and time meta, spans on the word")
    func searching() async {
        let drawer = model(.searching)
        await drawer.load()
        let found = sections(drawer)
        #expect(found.map(\.title) == ["2 matches"])
        #expect(found.first?.rows.map(\.meta) == ["today · 9:12", "tue 14 oct · 10:05"])
        #expect(found.first?.rows.first?.matches == [8 ..< 15])
    }

    @Test("a search that finds nothing says so; clearing it brings the days back")
    func noResultsThenClear() async {
        let drawer = model(.noResults)
        await drawer.load()
        #expect(drawer.state == .noResults)
        drawer.query = ""
        await drawer.settle()
        #expect(sections(drawer).count == 4)
    }

    @Test("typing searches after the pause; a newer search wins")
    func typingSearches() async {
        let drawer = model(.rest)
        await drawer.load()
        drawer.query = "mum"
        drawer.query = "walk"
        await drawer.settle()
        #expect(sections(drawer).first?.rows.count == 2)
        #expect(sections(drawer).first?.title == "2 matches")
    }

    @Test("not sent: a tap retries, and the row comes back sent")
    func retry() async throws {
        let drawer = model(.rest)
        await drawer.load()
        let unsent = try #require(sections(drawer).flatMap(\.rows).first { $0.status == .notSent })
        let client = try #require(unsent.clientEntryId)
        await drawer.retry(client)
        let after = sections(drawer).flatMap(\.rows).first { $0.id == unsent.id }
        #expect(after?.status == .rest)
        #expect(after?.meta == "shared · 14:30")
    }

    @Test("offline: the line shows, the queued row waits, and a retry keeps it waiting")
    func offline() async throws {
        let drawer = model(.offline)
        await drawer.load()
        #expect(drawer.isOffline)
        let rows = sections(drawer).flatMap(\.rows)
        #expect(rows.first?.status == .waiting)
        let unsent = try #require(rows.first { $0.status == .notSent }?.clientEntryId)
        await drawer.retry(unsent)
        #expect(sections(drawer).flatMap(\.rows).first { $0.clientEntryId == unsent }?.status == .waiting)
    }

    @Test("a sent row opens; it never retries")
    func opens() async throws {
        let drawer = model(.rest)
        await drawer.load()
        var opened: [String] = []
        drawer.onOpen = { opened.append($0.id) }
        let first = try #require(sections(drawer).first?.rows.first)
        drawer.tap(first)
        #expect(opened == [first.id])
    }

    @Test("with no page to open, a sent row says so; a row that didn't send still retries")
    func nothingToOpen() async {
        let drawer = model(.rest)
        await drawer.load()
        let rows = sections(drawer).flatMap(\.rows)
        #expect(rows.filter { $0.status == .rest }.allSatisfy { !drawer.opens($0) })
        #expect(rows.filter { $0.status == .notSent }.allSatisfy { drawer.opens($0) })
        drawer.onOpen = { _ in }
        #expect(rows.allSatisfy { drawer.opens($0) })
    }

    @Test("two taps on a row that didn't send send it once")
    func doubleTapRetriesOnce() async throws {
        let data = CountingEntries()
        let drawer = DrawerModel(data: data, debounce: .zero)
        await drawer.load()
        let row = try #require(sections(drawer).flatMap(\.rows).first { $0.status == .notSent })
        let client = try #require(row.clientEntryId)
        async let first: Void = drawer.retry(client)
        async let second: Void = drawer.retry(client)
        _ = await (first, second)
        #expect(data.retries == 1)
    }

    @Test("pages: the last row asks for the next page; a day split across pages stays one section")
    func pages() async throws {
        let data = CountingEntries()
        let drawer = DrawerModel(data: data, debounce: .zero)
        await drawer.load()
        #expect(sections(drawer).flatMap(\.rows).count == 2)
        let last = try #require(sections(drawer).flatMap(\.rows).last)
        #expect(drawer.isLast(last))
        await drawer.loadMore()
        #expect(sections(drawer).map(\.id) == ["2025-10-21", "2025-10-20"])
        #expect(sections(drawer).flatMap(\.rows).count == 3)
        #expect(!sections(drawer).flatMap(\.rows).contains { drawer.isLast($0) })
    }

    @Test("delivery maps to the row's status")
    func statuses() {
        #expect(DrawerModel.status(.sent) == .rest)
        #expect(DrawerModel.status(.waiting) == .waiting)
        #expect(DrawerModel.status(.sending) == .waiting)
        #expect(DrawerModel.status(.failed(Flows.Failure(.network))) == .notSent)
    }
}

/// Two pages (the second repeats a day from the first) and a retry counter.
@MainActor
@Observable
private final class CountingEntries: EntriesData {
    let today = SampleEntries.today
    let timeZone = SampleEntries.london
    let isOffline = false
    private(set) var retries = 0

    func entries(cursor: String?, query _: String?) async -> Result<Flows.Page<Flows.Journal.Entry>, Flows.Failure> {
        let rest = SampleEntries.rest
        if cursor == nil {
            // today, then yesterday's unsent row
            return .success(Flows.Page(items: [rest[0], SampleEntries.unsent], nextCursor: "next"))
        }
        // yesterday again, on the next page
        return .success(Flows.Page(items: [rest[1]], nextCursor: nil))
    }

    func retry(clientEntryId _: String) async {
        retries += 1
        try? await Task.sleep(for: .milliseconds(20))
    }
}
