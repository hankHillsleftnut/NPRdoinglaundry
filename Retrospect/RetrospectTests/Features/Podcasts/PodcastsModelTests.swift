import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PodcastsModelTests {
    private func model(_ scenario: PodcastsScenario) -> PodcastsModel {
        PodcastsModel(data: SamplePodcastsData(scenario: scenario), words: SamplePodcastsData.words)
    }

    @Test("at rest, word for word as Paper draws PC-1 (1FSA-0)")
    func asDrawn() throws {
        guard case let .content(content) = model(.rest).viewState else {
            Issue.record("expected content")
            return
        }
        let hero = try #require(content.hero)
        #expect(hero.label == "this week · 12 min")
        #expect(hero.title == "the week you stopped rushing")
        #expect(hero.subline == "mornings, the standup, sleep")
        #expect(hero.art == .weekly)
        #expect(content.earlier.map(\.title) == ["today's brief", "your first episode", "what the sunday calls keep coming back to", "monday's brief"])
        #expect(content.earlier.map(\.meta) == ["tue 21 oct · 4 min", "sun 12 oct · 5 min", "sun 19 oct · 11 min", "mon 20 oct · 3 min"])
        #expect(content.earlier.map(\.art) == [.brief, .first, .calls, .brief])
    }

    @Test("every seam state maps to one page state", arguments: [
        (PodcastsScenario.loading, "loading"),
        (.empty, "empty"),
        (.error, "failed"),
        (.offline, "offline"),
        (.rest, "content"),
    ])
    func states(scenario: PodcastsScenario, expected: String) {
        let name = switch model(scenario).viewState {
        case .loading: "loading"
        case .content: "content"
        case .empty: "empty"
        case .offline: "offline"
        case .failed: "failed"
        }
        #expect(name == expected)
    }

    @Test("offline keeps the last library under the offline line; offline with nothing shows nothing")
    func offlineKeepsLibrary() {
        guard case let .offline(kept) = model(.offline).viewState else {
            Issue.record("expected offline")
            return
        }
        #expect(kept?.hero?.title == "the week you stopped rushing")
        #expect(PodcastsModel.viewState(.offline(nil), words: SamplePodcastsData.words) == .offline(nil))
    }

    @Test("a library with no hero and no items is the empty page, not an empty scroll")
    func emptyLibrary() {
        #expect(model(.empty).viewState == .empty)
    }

    @Test("try again after an error loads the library")
    func retry() async {
        let page = model(.error)
        #expect(page.viewState == .failed)
        await page.retry()
        guard case .content = page.viewState else {
            Issue.record("expected content after retry")
            return
        }
    }

    @Test("lengths are whole minutes and never zero")
    func minutes() {
        let words = SamplePodcastsData.words
        #expect(words.minutes(720) == "12 min")
        #expect(words.minutes(20) == "1 min")
        #expect(words.minutes(89) == "1 min")
        #expect(words.minutes(91) == "2 min")
    }

    @Test("a brief from today is today's; another day is named by its weekday; a bad date is skipped")
    func briefTitles() {
        let words = SamplePodcastsData.words
        let brief = { (date: String) in
            words.square(.brief(.init(id: date, date: date, title: "", durationSeconds: nil, hasAudio: false)))
        }
        #expect(brief("2025-10-21")?.title == "today's brief")
        #expect(brief("2025-10-19")?.title == "sunday's brief")
        #expect(brief("2025-10-19")?.meta == "sun 19 oct")
        #expect(brief("not a day") == nil)
        #expect(words.square(.unknown) == nil)
    }

    @Test("the first episode as the hero says so and wears its own mesh")
    func firstAsHero() {
        let first = Flows.Podcasts.EpisodeSummary(
            id: "f", kind: .first, number: 1, title: "your first episode", about: nil, durationSeconds: 300,
            timing: .measured, createdAt: SamplePodcastsData.now, coversFrom: nil, coversTo: nil, hasAudio: true
        )
        let hero = SamplePodcastsData.words.hero(first)
        #expect(hero.label == "your first episode · 5 min")
        #expect(hero.art == .first)
        #expect(hero.subline == nil)
    }

    @Test("a contract day is read strictly: impossible days and stray parts are refused, never rolled over")
    func strictDays() {
        let calendar = SamplePodcastsData.words.calendar
        #expect(EpisodeWords.isoDay("2025-10-21", calendar: calendar) != nil)
        #expect(EpisodeWords.isoDay("2025-02-31", calendar: calendar) == nil)
        #expect(EpisodeWords.isoDay("2025-x-10-21", calendar: calendar) == nil)
        #expect(EpisodeWords.isoDay("2025-10-", calendar: calendar) == nil)
        #expect(EpisodeWords.isoDay("2025-13-01", calendar: calendar) == nil)
    }

    @Test("a newest weekly older than a week says its day, not \"this week\"")
    func olderHero() {
        let words = SamplePodcastsData.words
        let old = Flows.Podcasts.EpisodeSummary(
            id: "o", kind: .weekly, number: 1, title: "an older week", about: nil, durationSeconds: 600,
            timing: .measured, createdAt: SamplePodcastsData.now.addingTimeInterval(-10 * 86400), coversFrom: nil, coversTo: nil, hasAudio: true
        )
        #expect(words.hero(old).label == "sat 11 oct · 10 min")
        #expect(words.hero(SamplePodcastsData.hero).label == "this week · 12 min")
    }
}
