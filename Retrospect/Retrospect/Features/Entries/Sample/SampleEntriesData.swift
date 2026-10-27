//
//  SampleEntriesData.swift
//  V2.journal (dark): the drawer's sample data, one scenario per state Paper draws for JR-3
//  (05 · the app in order: rest MW6-0, empty MYD-0, searching MZJ-0, no results N17-0, offline N2N-0).
//  The words are Paper's invented lines (listed in docs/design/sample-data-ledger.md); the days sit on
//  the sample journal's day (tue 21 oct) so "today", "yesterday", "sun 19 oct" and "sat 18 oct" read
//  as Paper draws them, and the times read in London as Paper's do. Debug builds only: state scenes
//  never ship (founder, 27 Oct).
//
#if DEBUG
import Foundation
import Observation

/// The drawer's sample states (`-Screen JR-3 -State <rawValue>`).
enum EntriesScenario: String, CaseIterable, Sendable {
    case rest
    case empty
    case searching
    case noResults
    case offline
    /// JR-1 on sample data with the drawer closed: the drawer button and the edge swipe open it.
    case flow

    /// What the search field holds when the screen opens.
    var query: String {
        switch self {
        case .searching: "standup"
        case .noResults: "kayak"
        default: ""
        }
    }
}

@MainActor
@Observable
final class SampleEntriesData: EntriesData {
    typealias Entry = Flows.Journal.Entry

    let scenario: EntriesScenario
    /// Paper's calendar: 21 oct is a tuesday (2025), so 19 and 18 oct read sun and sat as drawn.
    let today = SampleEntries.today
    let timeZone = SampleEntries.london
    var isOffline: Bool {
        scenario == .offline
    }

    /// The entry the journal behind the drawer is showing (the "here" row).
    static let today = "2025-10-21"
    static let hereID = SampleEntries.hereID

    private var kept: [Entry]
    /// Entries only the entry page opens (JR-4's own states).
    private var pages = SampleEntries.pages
    /// How long the sample's retry takes to send (a beat, so "sending" can be seen).
    private let sendBeat: Duration

    init(scenario: EntriesScenario, sendBeat: Duration = .milliseconds(600)) {
        self.scenario = scenario
        self.sendBeat = sendBeat
        kept = SampleEntries.entries(for: scenario)
    }

    func entries(cursor _: String?, query: String?) async -> Result<Flows.Page<Entry>, Flows.Failure> {
        guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
            return .success(Flows.Page(items: kept, nextCursor: nil))
        }
        let found = kept.compactMap { SampleEntries.matching($0, query) }
        return .success(Flows.Page(items: found, nextCursor: nil))
    }

    func entry(id: String) async -> Result<Entry, Flows.Failure> {
        let found = (kept + pages).first { $0.id == id || $0.serverId == id }
        return found.map { .success($0) } ?? .failure(Flows.Failure(.notFound))
    }

    func retry(clientEntryId: String) async {
        setDelivery(.sending, of: clientEntryId)
        try? await Task.sleep(for: sendBeat)
        // offline, it waits on the phone; online, it sends
        setDelivery(isOffline ? .waiting : .sent, of: clientEntryId)
    }

    private func setDelivery(_ delivery: Entry.Delivery, of clientEntryId: String) {
        if let index = kept.firstIndex(where: { $0.clientEntryId == clientEntryId }) {
            kept[index].delivery = delivery
        }
        if let index = pages.firstIndex(where: { $0.clientEntryId == clientEntryId }) {
            pages[index].delivery = delivery
        }
    }
}

/// Paper's drawer lines, as contract-shaped entries.
@MainActor
enum SampleEntries {
    typealias Entry = Flows.Journal.Entry
    typealias Seed = SampleJournalContent.Seed

    static let london = TimeZone(identifier: "Europe/London") ?? .current
    static let today = "2025-10-21"
    static let hereID = "00000000-0000-4000-8000-000000000a01"
    static let unsentID = "00000000-0000-4000-8000-000000000a90"
    static let waitingID = "00000000-0000-4000-8000-000000000a91"

    static func entries(for scenario: EntriesScenario) -> [Entry] {
        switch scenario {
        case .empty: []
        case .searching: searchable
        case .offline: [waiting] + rest
        case .rest, .noResults, .flow: rest
        }
    }

    /// Paper 1FOQ-0 / MW6-0, newest first. Times in UTC, read in London (BST, +1).
    static var rest: [Entry] {
        [
            Seed(
                id: hereID,
                client: nil,
                kind: .typed,
                text: "i think it's the 9am standup. i dread it.",
                at: "2025-10-21T08:12:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a02",
                client: nil,
                kind: .typed,
                text: "slept badly, long day of meetings",
                at: "2025-10-20T21:40:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: walkID, client: nil, kind: .voice,
                text: "on the walk home i kept thinking about the offer, and whether i even want it. "
                    + "the money's better, but i'd be commuting again, and i only just got my mornings back.",
                at: "2025-10-20T17:05:00.000Z", reading: .read
            ).entry,
            unsent,
            Seed(
                id: "00000000-0000-4000-8000-000000000a04",
                client: nil,
                kind: .typed,
                text: "long walk, first good sleep in a week",
                at: "2025-10-19T20:05:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a05",
                client: nil,
                kind: .voice,
                text: "mum called. we talked about dad for the first time in months",
                at: "2025-10-19T17:20:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a06",
                client: nil,
                kind: .typed,
                text: "couldn't stop thinking about what sam said at dinner",
                at: "2025-10-18T22:10:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a07",
                client: nil,
                kind: .typed,
                text: "ran 5k without stopping",
                at: "2025-10-18T07:02:00.000Z",
                reading: .read
            ).entry,
        ]
    }

    /// JR-4's own entries (Paper N7R-0, N9D-0), opened only from the entry launcher states.
    static var pages: [Entry] {
        [
            Seed(
                id: ranID,
                client: nil,
                kind: .typed,
                text: "ran 5k without stopping",
                at: "2026-10-21T07:02:00.000Z",
                reading: .waiting
            ).entry,
            Entry(
                local: trainID,
                kind: .typed,
                text: "the train is stuck again, writing this underground",
                createdAt: date("2026-10-21T08:40:00.000Z"),
                day: "2026-10-21",
                delivery: .failed(Flows.Failure(.network))
            ),
        ]
    }

    static let walkID = "00000000-0000-4000-8000-000000000a03"
    static let ranID = "00000000-0000-4000-8000-000000000a30"
    static let trainID = "00000000-0000-4000-8000-000000000a31"

    /// Paper MZJ-0: the two lines "standup" finds, among others it doesn't.
    static var searchable: [Entry] {
        [
            Seed(
                id: "00000000-0000-4000-8000-000000000a20",
                client: nil,
                kind: .typed,
                text: "the 9am standup again",
                at: "2025-10-21T08:12:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a21",
                client: nil,
                kind: .typed,
                text: "slept badly, long day of meetings",
                at: "2025-10-20T21:40:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000a22",
                client: nil,
                kind: .typed,
                text: "standup ran long, i said nothing",
                at: "2025-10-14T09:05:00.000Z",
                reading: .read
            ).entry,
        ]
    }

    /// Paper 1FQ8-0: shared yesterday, didn't send.
    static var unsent: Entry {
        Entry(
            local: unsentID,
            kind: .imported,
            text: "the fundraise article you shared",
            createdAt: date("2025-10-20T13:30:00.000Z"),
            day: "2025-10-20",
            delivery: .failed(Flows.Failure(.network))
        )
    }

    /// Paper N4N-0: written underground, kept on the phone.
    static var waiting: Entry {
        Entry(
            local: waitingID,
            kind: .typed,
            text: "the train is stuck again, writing this underground",
            createdAt: date("2025-10-21T08:40:00.000Z"),
            day: "2025-10-21",
            delivery: .waiting
        )
    }

    /// The entry with its matched spans (UTF-16, contract 02 §5), or nil when it doesn't match.
    static func matching(_ entry: Entry, _ query: String) -> Entry? {
        let spans = LiveJournalData.spans(of: query, in: entry.text)
        return spans.isEmpty ? nil : entry.replacingMatches(spans)
    }

    static func date(_ iso: String) -> Date {
        (try? Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))) ?? .distantPast
    }
}
#endif
