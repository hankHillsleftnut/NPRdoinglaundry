import Foundation
@testable import Retrospect
import Testing

/// Contract 02's fixtures decode into the journal's models (testing.md layer 4). The backend's
/// zod schemas check the same files, so a shape that drifts fails on both sides.
struct JournalFixtureTests {
    private struct Envelope<Payload: Decodable>: Decodable {
        let success: Bool
        let data: Payload
    }

    private struct Today: Decodable {
        let date: String
        let entries: [JournalEntry]
    }

    private struct EntryBody: Decodable {
        let entry: JournalEntry
    }

    private struct EntryPage: Decodable {
        let entries: [JournalEntry]
        let nextCursor: String?
    }

    private struct LatestBrief: Decodable {
        let brief: Brief?
        let enabled: Bool
    }

    private struct BriefPage: Decodable {
        let briefs: [Brief]
        let nextCursor: String?
    }

    private struct Guesses: Decodable {
        let guesses: [Guess]
        let speaking: Bool
    }

    private struct Answer: Decodable {
        let status: Guess.Status
    }

    private struct FailureBody: Decodable {
        let code: String
        let message: String
        let retryAfterSeconds: Int?
    }

    private struct Failure: Decodable {
        let success: Bool
        let error: FailureBody
    }

    /// The repo's `docs/team/contracts/fixtures/02`, found from this file's place in the repo.
    /// PL0.1's shared `Fixtures` helper replaces this once it lands.
    private static let folder: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Flows
        .deletingLastPathComponent() // Platform
        .deletingLastPathComponent() // RetrospectTests
        .deletingLastPathComponent() // Retrospect
        .deletingLastPathComponent() // the repo
        .appendingPathComponent("docs/team/contracts/fixtures/02", isDirectory: true)

    private func decode<Payload: Decodable>(_ name: String, as _: Payload.Type = Payload.self) throws -> Payload {
        let bytes = try Data(contentsOf: Self.folder.appendingPathComponent("\(name).json"))
        let envelope = try JSONDecoder.contract.decode(Envelope<Payload>.self, from: bytes)
        #expect(envelope.success)
        return envelope.data
    }

    @Test("today's entries decode oldest first, with their kinds and reading states")
    func todayDecodes() throws {
        let today: Today = try decode("entries.today")
        #expect(today.entries.map(\.kind) == [.typed, .voice, .imported])
        #expect(today.entries.map(\.reading) == [.read, .reading, .waiting])
        #expect(today.entries.allSatisfy { $0.delivery == .sent })
        #expect(today.entries[0].createdAt < today.entries[1].createdAt)
        #expect(try decode("entries.today.empty", as: Today.self).entries.isEmpty)
    }

    @Test("a created entry decodes, full and minimal")
    func createdEntryDecodes() throws {
        #expect(try decode("entry.create.response", as: EntryBody.self).entry.clientEntryId != nil)
        let minimal: EntryBody = try decode("entry.create.response.minimal")
        #expect(minimal.entry.clientEntryId == nil)
        #expect(minimal.entry.matches == nil)
    }

    @Test("every brief shape decodes: v1, v2 with audio, quiet, none and off")
    func briefsDecode() throws {
        let v1: LatestBrief = try decode("brief.latest.v1")
        #expect(v1.brief?.parts.count == 3)
        #expect(v1.brief?.audio == nil)
        let v2: LatestBrief = try decode("brief.latest.v2")
        #expect(v2.brief?.audio?.durationSeconds == 74.2)
        #expect(v2.brief?.parts.last?.startSeconds == 41.5)
        #expect(try decode("brief.latest.quiet", as: LatestBrief.self).brief?.kind == .quiet)
        #expect(try decode("brief.latest.none", as: LatestBrief.self).brief == nil)
        #expect(try decode("brief.latest.off", as: LatestBrief.self).enabled == false)
        #expect(try decode("briefs.list", as: BriefPage.self).nextCursor == "cursor-2")
        #expect(try decode("briefs.list.last", as: BriefPage.self).nextCursor == nil)
    }

    @Test("guesses decode, including a silent dial and a minimal guess")
    func guessesDecode() throws {
        let full: Guesses = try decode("guesses")
        #expect(full.guesses.first?.restsOn.count == 2)
        #expect(full.guesses.first?.question.hasSuffix("?") == true)
        #expect(try decode("guesses.minimal", as: Guesses.self).guesses.first?.rationale == nil)
        let silent: Guesses = try decode("guesses.silent")
        #expect(silent.guesses.isEmpty && !silent.speaking)
        #expect(try decode("guess.answer", as: Answer.self).status == .confirmed)
        #expect(try decode("guess.answer.declined", as: Answer.self).status == .declined)
        #expect(try decode("guess.why", as: Guess.self).status == .offered)
    }

    @Test("the drawer's pages and search matches decode")
    func entryPagesDecode() throws {
        #expect(try decode("entries.list", as: EntryPage.self).nextCursor == "cursor-50")
        #expect(try decode("entries.list.last", as: EntryPage.self).nextCursor == nil)
        let search: EntryPage = try decode("entries.search")
        let entry = try #require(search.entries.first)
        let match = try #require(entry.matches?.first)
        let utf16 = Array(entry.text.utf16)
        #expect(String(decoding: utf16[match.start ..< match.start + match.length], as: UTF16.self) == "canal")
        #expect(try decode("entries.search.empty", as: EntryPage.self).entries.isEmpty)
        #expect(try decode("entry", as: EntryBody.self).entry.kind == .typed)
        #expect(try decode("entry.edit.response", as: EntryBody.self).entry.reading == .waiting)
    }

    @Test("what retro took decodes with its sureness words")
    func tookDecodes() throws {
        let took: Took = try decode("took")
        #expect(took.items.map(\.sureness) == [.fairlySure, .verySure, .justAHunch])
        let waiting: Took = try decode("took.waiting")
        #expect(waiting.items.isEmpty && waiting.reading == .waiting)
    }

    @Test("each correction outcome decodes to its case")
    func correctionsDecode() throws {
        guard case let .applied(echo, target, retired) = try decode("correction.applied", as: CorrectionOutcome.self) else {
            Issue.record("applied didn't decode as applied")
            return
        }
        #expect(echo.hasPrefix("got it."))
        #expect(target?.kind == .fact)
        #expect(retired == 3)
        guard case let .confirm(candidates) = try decode("correction.confirm", as: CorrectionOutcome.self) else {
            Issue.record("confirm didn't decode as confirm")
            return
        }
        #expect(candidates.count == 2)
        guard case let .askOwnWords(quote, writtenOn, _) = try decode("correction.ask", as: CorrectionOutcome.self) else {
            Issue.record("askOwnWords didn't decode as askOwnWords")
            return
        }
        #expect(!quote.isEmpty)
        #expect(writtenOn == "2026-09-02")
        #expect(try decode("correction.not", as: CorrectionOutcome.self) == .notACorrection)
        guard case .applied = try decode("correction.confirm.response", as: CorrectionOutcome.self) else {
            Issue.record("confirm's response didn't decode as applied")
            return
        }
    }

    @Test("an enum value the app doesn't know decodes as unknown, never failing the response")
    func unknownEnumValuesDecode() throws {
        let bytes = Data(#"{"kind":"podcast","id":"x","text":"t","createdAt":"2026-10-21T13:02:11Z","day":"2026-10-21","reading":"skimmed"}"#.utf8)
        let entry = try JSONDecoder.contract.decode(JournalEntry.self, from: bytes)
        #expect(entry.kind == .unknown)
        #expect(entry.reading == .unknown)
        let outcome = try JSONDecoder.contract.decode(CorrectionOutcome.self, from: Data(#"{"outcome":"later"}"#.utf8))
        #expect(outcome == .failed(.unknown))
    }

    @Test("every error fixture is a failure envelope with a plain message")
    func errorsDecode() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path).filter { $0.hasPrefix("error.") }
        #expect(!names.isEmpty)
        for name in names {
            let failure = try JSONDecoder.contract.decode(Failure.self, from: Data(contentsOf: Self.folder.appendingPathComponent(name)))
            #expect(!failure.success)
            #expect(name == "error.\(failure.error.code).json")
            #expect(!failure.error.message.isEmpty)
            let limited = ["rate_limited", "spend_limited"].contains(failure.error.code)
            #expect((failure.error.retryAfterSeconds != nil) == limited)
        }
    }
}
