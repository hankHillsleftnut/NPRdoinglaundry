//
//  Journal.swift
//  The journal's seam (ui-engineer.md §4): the models from contract 02 (`Flows.Journal`) and
//  the `Flows.JournalData` protocol every journal screen reads. The views engineer builds
//  against it with sample data (UI1.0); the Platform engineer implements it live (PL3.1).
//  Neither adds to it on their own side: a missing need goes to the integrator.
//
import Foundation
import Observation

extension Flows {
    /// Contract 02's models.
    enum Journal {}
}

// MARK: - Shared types (contract 02 §1)

extension Flows.Journal {
    /// Something Retro used or can show.
    struct SourceRef: Codable, Hashable, Sendable {
        enum Kind: String, Flows.ContractEnum {
            case entry, fact, answer, pattern, saved, turn, unknown
        }

        let kind: Kind
        let id: String
        /// A short plain line, when the door can give one cheaply.
        let label: String?
    }

    /// A claim Retro holds that the person can point at ("what i took", "not right").
    struct ClaimRef: Codable, Hashable, Sendable {
        let kind: SourceRef.Kind
        let id: String
        let text: String
    }
}

// MARK: - Entries (contract 02 §2, §5)

extension Flows.Journal {
    /// Something the person sent into their bank, from the server or still on the phone.
    struct Entry: Codable, Identifiable, Hashable, Sendable {
        enum Kind: String, Flows.ContractEnum {
            case typed, voice, conversation, imported, unknown
        }

        /// How far Retro has got reading it (contract 02 §5, from processing_status).
        enum Reading: String, Flows.ContractEnum {
            case waiting, reading, read, failed, unknown
        }

        /// Where the entry is on its way to the server. Set on the phone by the outbox,
        /// never by the server: every entry the server lists is `.sent`.
        enum Delivery: Hashable, Sendable {
            case waiting
            case sending
            case sent
            case failed(Flows.Failure)
        }

        /// A matched span in `text` from drawer search, in UTF-16 code units (contract 02 §5).
        struct Match: Codable, Hashable, Sendable {
            let start: Int
            let length: Int
        }

        /// The row's identity: the outbox key when the app sent it, else the server's id. It
        /// stays the same from waiting to sent, so a list never replaces the row as it arrives.
        let id: String
        /// The server's id; nil while the entry is only on the phone.
        let serverId: String?
        /// The outbox key, when the app sent it.
        let clientEntryId: String?
        let kind: Kind
        let text: String
        let createdAt: Date
        /// The person's local day, `YYYY-MM-DD`.
        let day: String
        let reading: Reading
        /// Present only on search results.
        let matches: [Match]?
        var delivery: Delivery = .sent

        enum CodingKeys: String, CodingKey {
            case serverId = "id"
            case clientEntryId, kind, text, createdAt, day, reading, matches
        }

        /// An entry from the server.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let serverId = try container.decode(String.self, forKey: .serverId)
            let clientEntryId = try container.decodeIfPresent(String.self, forKey: .clientEntryId)
            try self.init(
                serverId: serverId,
                clientEntryId: clientEntryId,
                kind: container.decode(Kind.self, forKey: .kind),
                text: container.decode(String.self, forKey: .text),
                createdAt: container.decode(Date.self, forKey: .createdAt),
                day: container.decode(String.self, forKey: .day),
                reading: container.decode(Reading.self, forKey: .reading),
                matches: container.decodeIfPresent([Match].self, forKey: .matches),
                delivery: .sent
            )
        }

        /// An entry sent from this phone, before the server has it.
        init(local clientEntryId: String, kind: Kind, text: String, createdAt: Date, day: String, delivery: Delivery) {
            self.init(
                serverId: nil,
                clientEntryId: clientEntryId,
                kind: kind,
                text: text,
                createdAt: createdAt,
                day: day,
                reading: .waiting,
                matches: nil,
                delivery: delivery
            )
        }

        private init(
            serverId: String?,
            clientEntryId: String?,
            kind: Kind,
            text: String,
            createdAt: Date,
            day: String,
            reading: Reading,
            matches: [Match]?,
            delivery: Delivery
        ) {
            id = clientEntryId ?? serverId ?? ""
            self.serverId = serverId
            self.clientEntryId = clientEntryId
            self.kind = kind
            self.text = text
            self.createdAt = createdAt
            self.day = day
            self.reading = reading
            self.matches = matches
            self.delivery = delivery
        }
    }

    /// A voice note to send: the transcript is the entry's text; the recording stays on the phone.
    struct VoiceNote: Hashable, Sendable {
        let transcript: String
        /// The recording's path relative to the app's documents folder.
        let recordingPath: String
        let durationSeconds: Double
    }

    /// The short line Retro shows after something is sent (contract 02 §2): chosen on the
    /// phone, never the same twice in a row. Founder to confirm the lines (contract 02 §7.6).
    enum Acknowledgements {
        static let lines = ["got it.", "saved.", "it's in.", "kept."]

        /// The next line, never `previous`; `pick` chooses an index below its argument
        /// (inject it in tests; live and sample data pass a seeded or system generator).
        static func next(after previous: String?, lines: [String] = lines, pick: (Int) -> Int) -> String? {
            let choices = lines.filter { $0 != previous }
            guard !choices.isEmpty else { return lines.first }
            return choices[min(max(pick(choices.count), 0), choices.count - 1)]
        }
    }
}

// MARK: - Today's brief (contract 02 §3)

extension Flows.Journal {
    struct Brief: Codable, Identifiable, Hashable, Sendable {
        enum Kind: String, Flows.ContractEnum {
            case brief, quiet, unknown
        }

        struct Part: Codable, Hashable, Sendable {
            let text: String
            /// "here for your goal: …"
            let why: String?
            let sources: [SourceRef]
            /// Where this part starts in the audio, once briefs have audio.
            let startSeconds: Double?
        }

        struct Audio: Codable, Hashable, Sendable {
            /// Signed and private; refetch the brief before `expiresAt`.
            let url: URL
            let expiresAt: Date
            let durationSeconds: Double
        }

        let id: String
        /// The person's local day, `YYYY-MM-DD`.
        let date: String
        let kind: Kind
        /// In spoken order.
        let parts: [Part]
        let audio: Audio?
        let createdAt: Date
    }

    /// What the journal's brief card shows.
    enum BriefSlot: Hashable, Sendable {
        /// The person hasn't turned the brief on: no card at all.
        case off
        /// Turned on, today's isn't ready yet. `readyBy` is nil until brief settings exist (contract 06).
        case making(readyBy: Date?)
        case ready(Brief)
        /// A quiet day: Retro's one line instead of a brief.
        case quiet(line: String)
        /// Turned on, but nothing for today and nothing on the way.
        case none
    }
}

// MARK: - Guesses (contract 02 §4)

extension Flows.Journal {
    struct Guess: Codable, Identifiable, Hashable, Sendable {
        enum Status: String, Flows.ContractEnum {
            case offered, confirmed, declined, expired, unknown
        }

        struct Framework: Codable, Hashable, Sendable {
            let name: String
            let source: String?
            let wonders: String?
        }

        /// One thing the guess rests on, resolved to text by the door.
        struct Evidence: Codable, Hashable, Sendable {
            let kind: SourceRef.Kind
            let id: String
            let label: String?
            let text: String
        }

        let id: String
        /// Always a question.
        let question: String
        let framework: Framework
        let rationale: String?
        let status: Status
        let restsOn: [Evidence]
    }

    enum GuessVerdict: String, Codable, Hashable, Sendable {
        case yes, no
    }

    /// What answering a guess did. The guess on screen updates at once either way.
    enum GuessOutcome: Hashable, Sendable {
        /// The server has the answer.
        case recorded(Guess.Status)
        /// Offline: the answer is saved and will be sent once.
        case queued
        case failed(Flows.Failure)
    }
}

// MARK: - What Retro took, and "not right" (contract 02 §6)

extension Flows.Journal {
    struct Took: Codable, Hashable, Sendable {
        /// How sure Retro is (founder to confirm the words; thresholds in the fixtures).
        enum Sureness: String, Flows.ContractEnum {
            case justAHunch = "just a hunch"
            case fairlySure = "fairly sure"
            case verySure = "very sure"
            case unknown
        }

        struct Item: Codable, Hashable, Sendable, Identifiable {
            let kind: SourceRef.Kind
            let id: String
            let text: String
            let sureness: Sureness
        }

        /// In the order Retro took them. Empty, with `reading` waiting, until Retro has read the entry.
        let items: [Item]
        let reading: Entry.Reading

        /// Retro has finished with the entry: no more updates will come.
        var isSettled: Bool {
            reading == .read || reading == .failed
        }
    }

    enum CorrectionMode: String, Codable, Hashable, Sendable {
        /// It was never true.
        case wrong
        /// It was true, and isn't any more.
        case changed
    }

    /// What Retro did with "not right".
    enum CorrectionOutcome: Hashable, Sendable {
        /// Done. `echo` is Retro's plain line about what it stopped saying.
        case applied(echo: String, target: ClaimRef?, retired: Int)
        /// Retro isn't sure which claim is meant: the person picks one, then `confirm`.
        case confirm(candidates: [ClaimRef])
        /// The claim came from the person's own words: show them and ask.
        case askOwnWords(quote: String, writtenOn: String, target: ClaimRef?)
        /// It didn't read as a correction.
        case notACorrection
        /// Offline: nothing was sent (corrections wait for an answer, so they aren't queued).
        case offline
        case failed(Flows.Failure)
    }

    /// What an edit or delete did. The entry on screen changes at once; this says whether it stuck.
    enum WriteOutcome: Hashable, Sendable {
        case done
        /// Offline: saved, and sent once when back online.
        case queued
        /// Refused: the change is undone on screen and this says why.
        case failed(Flows.Failure)
    }
}

extension Flows.Journal.CorrectionOutcome: Decodable {
    private enum CodingKeys: String, CodingKey {
        case outcome, echo, target, retired, candidates, quote, writtenOn
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .outcome) {
        case "applied":
            self = try .applied(
                echo: container.decode(String.self, forKey: .echo),
                target: container.decodeIfPresent(Flows.Journal.ClaimRef.self, forKey: .target),
                retired: container.decodeIfPresent(Int.self, forKey: .retired) ?? 0
            )
        case "confirm":
            self = try .confirm(candidates: container.decode([Flows.Journal.ClaimRef].self, forKey: .candidates))
        case "askOwnWords":
            self = try .askOwnWords(
                quote: container.decode(String.self, forKey: .quote),
                writtenOn: container.decode(String.self, forKey: .writtenOn),
                target: container.decodeIfPresent(Flows.Journal.ClaimRef.self, forKey: .target)
            )
        case "notACorrection":
            self = .notACorrection
        default:
            self = .failed(.unknown)
        }
    }
}

// MARK: - The protocol

extension Flows {
    /// Everything the journal's screens (JR-1 to JR-4) read and do. Actions never throw to a
    /// view: their outcome lands on state, or comes back as a value. Nothing here polls or
    /// waits on a timer inside a view: streams carry updates instead.
    @MainActor
    protocol JournalData: AnyObject, Observable {
        /// Today's thread, oldest first, including entries still on the phone.
        var today: Loadable<[Journal.Entry]> { get }
        var brief: Loadable<Journal.BriefSlot> { get }
        /// Newest first. Empty while guesses aren't speaking (the founder's dial).
        var guesses: [Journal.Guess] { get }
        var isOnline: Bool { get }

        /// Loads today, the brief and guesses (cached first, then fresh). Screens call it in `.task`.
        func load() async

        /// Saves the entry on the phone at once (`.waiting`) and sends it exactly once.
        func send(text: String) async
        func sendVoice(_ note: Journal.VoiceNote) async
        func retry(clientEntryId: String) async
        /// Retro's short line for a sent entry: nil until the entry is `.sent`, never the same
        /// line twice in a row, and never changes once chosen.
        func acknowledgement(for clientEntryId: String) -> String?

        func answer(_ guess: Journal.Guess, verdict: Journal.GuessVerdict) async -> Journal.GuessOutcome

        /// The drawer: every entry the person sent, newest first; `query` searches their own words.
        func entries(cursor: String?, query: String?) async -> Result<Page<Journal.Entry>, Failure>
        func entry(id: String) async -> Result<Journal.Entry, Failure>
        func edit(id: String, text: String) async -> Journal.WriteOutcome
        /// Deleting removes everything Retro took from it.
        func delete(id: String) async -> Journal.WriteOutcome

        /// What Retro took from an entry, as it changes: the current value at once, then a new
        /// one each time it's re-read while Retro is still reading, ending at `read` or `failed`
        /// (or on a failure). Cancelling the consuming task stops the polling.
        func tookUpdates(id: String) -> AsyncStream<Result<Journal.Took, Failure>>
        func correct(text: String, about: Journal.ClaimRef?) async -> Journal.CorrectionOutcome
        func confirm(_ target: Journal.ClaimRef, mode: Journal.CorrectionMode, note: String?) async -> Journal.CorrectionOutcome
    }
}
