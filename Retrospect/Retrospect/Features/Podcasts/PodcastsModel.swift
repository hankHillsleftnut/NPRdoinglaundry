//
//  PodcastsModel.swift
//  V2.podcasts.a · PC-1 podcasts (Paper p-J-0 1FSA-0): what the library page shows, worded. The page
//  reads only this; the model reads only `Flows.PodcastsData` (#195's seam), so the sample and the
//  live library plug in the same way. Dates and lengths are worded here, never in the view.
//
import Foundation
import Observation

/// The artwork a tile wears (the gradient.mesh* recipes; the view picks the recipe).
enum EpisodeArt: Equatable {
    case weekly, brief, first, calls
}

/// PC-1's hero: this week's episode (Paper 1FUK-0).
struct EpisodeHero: Equatable, Identifiable {
    let id: String
    /// The panel's corner line ("this week · 12 min").
    let label: String
    let title: String
    /// Up to three chapter titles ("mornings, the standup, sleep"); nil for a legacy episode.
    let subline: String?
    let art: EpisodeArt
}

/// One square under "earlier" (Paper 1FUE-0 …).
struct EpisodeSquare: Equatable, Identifiable {
    let id: String
    let title: String
    /// "tue 21 oct · 4 min".
    let meta: String
    let art: EpisodeArt
}

/// The worded library.
struct PodcastsContent: Equatable {
    let hero: EpisodeHero?
    let earlier: [EpisodeSquare]

    var isEmpty: Bool {
        hero == nil && earlier.isEmpty
    }
}

@MainActor
@Observable
final class PodcastsModel {
    /// Everything the page can be.
    enum ViewState: Equatable {
        case loading
        case content(PodcastsContent)
        /// Nothing made yet: the first episode comes on sunday.
        case empty
        /// Offline: what was last shown stays (nil when nothing was).
        case offline(PodcastsContent?)
        case failed
    }

    /// The play is drawn ahead of the player (V2.podcasts.d): VoiceOver says so.
    static let notAvailableYet = "not available yet"

    private let data: any Flows.PodcastsData
    private let words: EpisodeWords

    init(data: any Flows.PodcastsData, words: EpisodeWords = EpisodeWords()) {
        self.data = data
        self.words = words
    }

    var viewState: ViewState {
        Self.viewState(data.state, words: words)
    }

    func load() async {
        await data.library()
    }

    func retry() async {
        await data.refresh()
    }

    /// The seam's state, worded for the page.
    static func viewState(_ state: Flows.Podcasts.LibraryState, words: EpisodeWords) -> ViewState {
        switch state {
        case .loading:
            return .loading
        case let .content(library):
            let content = words.content(library)
            return content.isEmpty ? .empty : .content(content)
        case let .offline(library):
            return .offline(library.map(words.content))
        case .failed:
            return .failed
        }
    }
}

/// Words for the library's dates and lengths, in the page's lowercase voice.
struct EpisodeWords {
    /// "Today" for the brief titles ("today's brief").
    var now: Date = .now
    var calendar: Calendar = .current

    func content(_ library: Flows.Podcasts.Library) -> PodcastsContent {
        PodcastsContent(
            hero: library.hero.map(hero),
            earlier: library.items.compactMap(square)
        )
    }

    func hero(_ episode: Flows.Podcasts.EpisodeSummary) -> EpisodeHero {
        let when = episode.kind == .first ? "your first episode" : "this week"
        return EpisodeHero(
            id: episode.id,
            label: "\(when) · \(minutes(episode.durationSeconds))",
            title: episode.title,
            subline: episode.about,
            art: episode.kind == .first ? .first : .weekly
        )
    }

    func square(_ item: Backend.Podcasts.LibraryItem) -> EpisodeSquare? {
        switch item {
        case let .episode(episode):
            return EpisodeSquare(
                id: episode.id,
                title: episode.title,
                meta: "\(day(episode.createdAt)) · \(minutes(episode.durationSeconds))",
                // an earlier weekly wears the calls mesh as Paper draws it (PCD-2: per-episode art is a question)
                art: episode.kind == .first ? .first : .calls
            )
        case let .brief(brief):
            guard let date = Self.isoDay(brief.date, calendar: calendar) else { return nil }
            let meta = brief.durationSeconds.map { "\(day(date)) · \(minutes($0))" } ?? day(date)
            return EpisodeSquare(id: brief.id, title: briefTitle(date), meta: meta, art: .brief)
        case .unknown:
            return nil
        }
    }

    /// "today's brief", or the weekday's ("monday's brief").
    func briefTitle(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "today's brief"
        }
        return "\(format(date, "EEEE"))'s brief"
    }

    /// "tue 21 oct".
    func day(_ date: Date) -> String {
        format(date, "EEE d MMM")
    }

    /// Whole minutes, never "0 min".
    func minutes(_ seconds: Double) -> String {
        "\(max(1, Int((seconds / 60).rounded()))) min"
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date).lowercased()
    }

    /// A contract `YYYY-MM-DD` day, at the start of that day in the person's zone.
    static func isoDay(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
