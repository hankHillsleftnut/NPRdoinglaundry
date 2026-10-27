//
//  SamplePodcastsData.swift
//  V2.podcasts.a: the podcast library with no network, through `Flows.PodcastsData` only (#195's
//  seam). The library is word for word Paper PC-1 1FSA-0: the hero "the week you stopped rushing"
//  (12 min, "mornings, the standup, sleep") and four squares under "earlier". Sample "today" is
//  tue 21 oct 2025, the day Paper draws, so the brief squares read "today's brief" and
//  "monday's brief".
//
import Foundation
import Observation

/// The library's launcher states.
enum PodcastsScenario: String, CaseIterable {
    /// PC-1 at rest, as drawn.
    case rest
    /// Not drawn (founder-review lean): the skeleton while the library loads.
    case loading
    /// Not drawn: nothing made yet.
    case empty
    /// Not drawn: the first load failed; "try again" loads the sample.
    case error
    /// Not drawn: offline, the last library still shown under the offline line.
    case offline
}

@MainActor
@Observable
final class SamplePodcastsData: Flows.PodcastsData {
    private(set) var state: Flows.Podcasts.LibraryState

    init(scenario: PodcastsScenario) {
        state = Self.state(for: scenario)
    }

    @discardableResult
    func library() async -> Flows.Podcasts.LibraryState {
        state
    }

    /// The sample always answers: a refresh shows the drawn library.
    func refresh() async {
        state = .content(Self.library)
    }

    func episode(id _: String) async -> Result<Flows.Podcasts.Episode, Flows.Failure> {
        .failure(Flows.Failure(.notFound))
    }

    static func state(for scenario: PodcastsScenario) -> Flows.Podcasts.LibraryState {
        switch scenario {
        case .rest: .content(library)
        case .loading: .loading
        case .empty: .content(Flows.Podcasts.Library(hero: nil, upcoming: Backend.Podcasts.Upcoming.nothing, items: [], nextCursor: nil))
        case .error: .failed(Flows.Failure(.server))
        case .offline: .offline(library)
        }
    }

    // MARK: - Paper's library (1FSA-0)

    /// Sample "now": tue 21 oct 2025, 9:41 in UTC.
    static let now = day(2025, 10, 21, hour: 9, minute: 41)

    /// Words worded against the sample's day, in UTC so the launcher and tests agree.
    static var words: EpisodeWords {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return EpisodeWords(now: now, calendar: calendar)
    }

    static let hero = Flows.Podcasts.EpisodeSummary(
        id: "sample-weekly-3",
        kind: .weekly,
        number: 3,
        title: "the week you stopped rushing",
        about: "mornings, the standup, sleep",
        durationSeconds: 720,
        timing: .measured,
        createdAt: day(2025, 10, 19, hour: 9),
        coversFrom: "2025-10-13",
        coversTo: "2025-10-19",
        hasAudio: true
    )

    static let library = Flows.Podcasts.Library(
        hero: hero,
        upcoming: Backend.Podcasts.Upcoming.nothing,
        items: [
            .brief(.init(id: "sample-brief-21", date: "2025-10-21", title: "three things moved since yesterday", durationSeconds: 240, hasAudio: true)),
            .episode(.init(
                id: "sample-first",
                kind: .first,
                number: 1,
                title: "your first episode",
                about: nil,
                durationSeconds: 300,
                timing: .measured,
                createdAt: day(2025, 10, 12, hour: 9),
                coversFrom: nil,
                coversTo: nil,
                hasAudio: true
            )),
            .episode(.init(
                id: "sample-weekly-2",
                kind: .weekly,
                number: 2,
                title: "what the sunday calls keep coming back to",
                about: "your sister, the job, the calls",
                durationSeconds: 660,
                timing: .measured,
                createdAt: day(2025, 10, 19, hour: 8),
                coversFrom: "2025-10-06",
                coversTo: "2025-10-12",
                hasAudio: true
            )),
            .brief(.init(id: "sample-brief-20", date: "2025-10-20", title: "a slower monday", durationSeconds: 180, hasAudio: true)),
        ],
        nextCursor: nil
    )

    private static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }
}
