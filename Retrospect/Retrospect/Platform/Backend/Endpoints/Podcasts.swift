import Foundation

extension Backend.Endpoints {
    /// `GET /v2/podcasts` (contract 03 §2): the library, newest first, a page at a time. The hero (the newest ready
    /// episode) and `upcoming` come on the first page only; the hero is never repeated in `items`.
    struct PodcastLibrary: Backend.Endpoint {
        typealias Response = Backend.Podcasts.Library

        /// The opaque cursor from the last page; nil for the first page.
        let cursor: String?
        /// At most 50 (the door's limit); nil leaves the door's default.
        let limit: Int?

        init(cursor: String? = nil, limit: Int? = nil) {
            self.cursor = cursor
            self.limit = limit
        }

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .podcasts
        }

        var query: [URLQueryItem] {
            [cursor.map { URLQueryItem(name: "cursor", value: $0) }, limit.map { URLQueryItem(name: "limit", value: String($0)) }].compactMap { $0 }
        }
    }

    /// `GET /v2/episodes/:id` (contract 03 §3, and contract 01 §6's first episode): one episode, with its signed audio
    /// link (an hour long) when it has audio. Another person's episode is `not_found`.
    struct EpisodeByID: Backend.Endpoint {
        struct Found: Decodable, Sendable, Equatable {
            let episode: Backend.Podcasts.Episode
        }

        typealias Response = Found

        let id: String

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .episodeByID
        }

        var pathParameters: [String: String] {
            ["id": id]
        }
    }
}

extension Backend {
    /// Contract 03's types: the library and one episode. Every enum is a closed list that decodes an unknown value as
    /// `unknown`; a library item of an unknown kind is kept as `.unknown` (the app skips it).
    enum Podcasts {
        enum EpisodeKind: String, Flows.ContractEnum {
            case weekly, first, onDemand, unknown
        }

        enum Timing: String, Flows.ContractEnum {
            case measured, estimated, unknown
        }

        /// One episode as the library lists it.
        struct EpisodeSummary: Decodable, Sendable, Equatable {
            let id: String
            let kind: EpisodeKind
            let number: Int?
            let title: String
            /// Up to three chapter titles, joined by the door; absent for legacy episodes.
            let about: String?
            let durationSeconds: Double
            let timing: Timing
            let createdAt: Date
            /// `YYYY-MM-DD`, the person's zone.
            let coversFrom: String?
            let coversTo: String?
            let hasAudio: Bool
        }

        /// A past brief, as a square on the library.
        struct BriefSummary: Decodable, Sendable, Equatable {
            let id: String
            /// `YYYY-MM-DD`.
            let date: String
            /// The brief's first sentence, cut by the door; the VoiceOver hint only.
            let title: String
            let durationSeconds: Double?
            let hasAudio: Bool
        }

        enum LibraryItem: Decodable, Sendable, Equatable {
            case episode(EpisodeSummary)
            case brief(BriefSummary)
            /// A kind this build doesn't know.
            case unknown

            private enum CodingKeys: String, CodingKey {
                case kind, episode, brief
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                switch try container.decode(String.self, forKey: .kind) {
                case "episode": self = try .episode(container.decode(EpisodeSummary.self, forKey: .episode))
                case "brief": self = try .brief(container.decode(BriefSummary.self, forKey: .brief))
                default: self = .unknown
                }
            }
        }

        /// What is on its way (first page only).
        enum Upcoming: Decodable, Sendable, Equatable {
            /// A weekly or first job is queued or running; `readyAt` is the delivery time.
            case making(readyAt: Date?)
            /// This week ended quiet: the brain's line (shown as written) and when the next one is due.
            case quietWeek(line: String, nextAt: Date?)
            /// The contract's `none`: nothing on its way.
            case nothing
            case unknown

            private enum CodingKeys: String, CodingKey {
                case state, readyAt, line, nextAt
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                switch try container.decode(String.self, forKey: .state) {
                case "making": self = try .making(readyAt: container.decodeIfPresent(Date.self, forKey: .readyAt))
                case "quietWeek":
                    self = try .quietWeek(line: container.decode(String.self, forKey: .line), nextAt: container.decodeIfPresent(Date.self, forKey: .nextAt))
                case "none": self = .nothing
                default: self = .unknown
                }
            }
        }

        /// `GET /v2/podcasts`'s answer.
        struct Library: Decodable, Sendable, Equatable {
            /// The newest ready episode; nil when there is none yet, and on every page after the first.
            let hero: EpisodeSummary?
            /// First page only.
            let upcoming: Upcoming?
            let items: [LibraryItem]
            /// Nil on the last page.
            let nextCursor: String?
        }

        enum SourceKind: String, Flows.ContractEnum {
            case entries, voice, calendar, health, steps, sleep, saved, watched, listened, mail, unknown
        }

        /// The why line's parts: "from 6 entries · calendar · steps".
        struct MadeFrom: Decodable, Sendable, Equatable {
            let kind: SourceKind
            let count: Int
        }

        struct Chapter: Decodable, Sendable, Equatable {
            let index: Int
            let title: String
            let startSeconds: Double
            let claimId: String?
        }

        enum Register: String, Flows.ContractEnum {
            /// `craft` is a sentence that makes no claim about the person.
            case stated, asked, craft, unknown
        }

        /// One spoken sentence of the transcript.
        struct Line: Decodable, Sendable, Equatable {
            let index: Int
            let text: String
            /// -1 when there are no chapters.
            let chapterIndex: Int
            /// Present when timing is measured.
            let startSeconds: Double?
            let register: Register
            let claimId: String?
        }

        enum ClaimKind: String, Flows.ContractEnum {
            case pattern, answer, why, hypothesis, shift, goal, content, unknown
        }

        struct ClaimSummary: Decodable, Sendable, Equatable {
            let id: String
            let kind: ClaimKind
            let register: Register
            let chapterIndex: Int
            /// A hypothesis's guess, answerable with `POST /v2/guesses/:id`.
            let guessId: String?
        }

        /// The signed, private audio link; it expires an hour after the answer, and the app re-fetches the episode
        /// to renew it.
        struct Audio: Decodable, Sendable, Equatable {
            let url: URL
            let expiresAt: Date
            /// Absent in contract 01's first-episode shape.
            let durationSeconds: Double?
            let bytes: Int?
            let mimeType: String?
        }

        enum FeedbackVerdict: String, Flows.ContractEnum {
            case more, less, unknown
        }

        struct Feedback: Decodable, Sendable, Equatable {
            let verdict: FeedbackVerdict?
            let at: Date
        }

        /// One episode, as `GET /v2/episodes/:id` answers (contract 03 §3).
        struct Episode: Sendable, Equatable {
            let id: String
            let kind: EpisodeKind
            let number: Int?
            let title: String
            let about: String?
            let durationSeconds: Double
            let timing: Timing
            let createdAt: Date
            let coversFrom: String?
            let coversTo: String?
            let hasAudio: Bool
            let madeFrom: [MadeFrom]
            /// `[]` for legacy and estimated-only episodes.
            let chapters: [Chapter]
            /// The transcript; `[]` means the app shows `description` in its place.
            let lines: [Line]
            let description: String?
            let claims: [ClaimSummary]
            /// Absent when `hasAudio` is false.
            let audio: Audio?
            let feedback: Feedback?
        }
    }
}

extension Backend.Podcasts.Episode: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, number, title, about, durationSeconds, timing, createdAt, coversFrom, coversTo, hasAudio, madeFrom, chapters, lines,
             description, claims, audio, feedback, transcript
    }

    /// Contract 01 §6 writes the first episode in an older shape (`transcript` instead of `lines`, chapters without
    /// `index`, no `timing`/`hasAudio`/`madeFrom`/`claims`); both shapes read into this one type, so the first
    /// episode never fails to open for want of a field contract 03 added.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(Backend.Podcasts.EpisodeKind.self, forKey: .kind)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        about = try container.decodeIfPresent(String.self, forKey: .about)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        timing = try container.decodeIfPresent(Backend.Podcasts.Timing.self, forKey: .timing) ?? .unknown
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        coversFrom = try container.decodeIfPresent(String.self, forKey: .coversFrom)
        coversTo = try container.decodeIfPresent(String.self, forKey: .coversTo)
        audio = try container.decodeIfPresent(Backend.Podcasts.Audio.self, forKey: .audio)
        hasAudio = try container.decodeIfPresent(Bool.self, forKey: .hasAudio) ?? (audio != nil)
        madeFrom = try container.decodeIfPresent([Backend.Podcasts.MadeFrom].self, forKey: .madeFrom) ?? []
        chapters = try Self.chapters(in: container)
        lines = try Self.lines(in: container)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        claims = try container.decodeIfPresent([Backend.Podcasts.ClaimSummary].self, forKey: .claims) ?? []
        feedback = try container.decodeIfPresent(Backend.Podcasts.Feedback.self, forKey: .feedback)
    }

    /// A chapter without `index` (contract 01's shape) takes its place in the list.
    private static func chapters(in container: KeyedDecodingContainer<CodingKeys>) throws -> [Backend.Podcasts.Chapter] {
        let wire = try container.decodeIfPresent([WireChapter].self, forKey: .chapters) ?? []
        return wire.enumerated().map { offset, chapter in
            .init(index: chapter.index ?? offset, title: chapter.title, startSeconds: chapter.startSeconds, claimId: chapter.claimId)
        }
    }

    /// `lines` when present, else contract 01's `transcript`: each sentence a craft line with no chapter.
    private static func lines(in container: KeyedDecodingContainer<CodingKeys>) throws -> [Backend.Podcasts.Line] {
        if let lines = try container.decodeIfPresent([Backend.Podcasts.Line].self, forKey: .lines) {
            return lines
        }
        let transcript = try container.decodeIfPresent([WireTranscriptLine].self, forKey: .transcript) ?? []
        return transcript.enumerated().map { offset, line in
            .init(index: offset, text: line.text, chapterIndex: -1, startSeconds: line.startSeconds, register: .craft, claimId: nil)
        }
    }

    private struct WireChapter: Decodable {
        let index: Int?
        let title: String
        let startSeconds: Double
        let claimId: String?
    }

    private struct WireTranscriptLine: Decodable {
        let text: String
        let startSeconds: Double?
    }
}
