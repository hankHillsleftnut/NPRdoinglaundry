import Foundation
@testable import Retrospect
import Testing

/// Every file in contracts 00 and 02's fixture folders decodes into its model or matches its
/// request shape (testing.md layer 4). The backend's zod schemas check the same files, so a
/// shape that drifts fails on both sides. A fixture nobody mapped fails here too.
struct ContractFixtureTests {
    typealias Journal = Flows.Journal

    /// The repo's `docs/team/contracts/fixtures`, found from this file's place in the repo.
    /// PL0.1's shared `Fixtures` helper replaces this once it lands.
    static let root: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Flows
        .deletingLastPathComponent() // Platform
        .deletingLastPathComponent() // RetrospectTests
        .deletingLastPathComponent() // Retrospect
        .deletingLastPathComponent() // the repo
        .appendingPathComponent("docs/team/contracts/fixtures", isDirectory: true)

    // MARK: - Contract 02

    /// Response fixtures (the full envelope), each decoded as the type its door returns.
    static let journalResponses: [String: (Data) throws -> Void] = [
        "entries.today": decodes(Today.self),
        "entries.today.empty": decodes(Today.self),
        "entry.create.response": decodes(EntryBody.self),
        "entry.create.response.minimal": decodes(EntryBody.self),
        "entry": decodes(EntryBody.self),
        "entry.edit.response": decodes(EntryBody.self),
        "entry.delete": decodes(Deleted.self),
        "entries.list": decodes(EntryPage.self),
        "entries.list.last": decodes(EntryPage.self),
        "entries.search": decodes(EntryPage.self),
        "entries.search.empty": decodes(EntryPage.self),
        "entries.search.astral": decodes(EntryPage.self),
        "brief.latest.v1": decodes(LatestBrief.self),
        "brief.latest.v2": decodes(LatestBrief.self),
        "brief.latest.quiet": decodes(LatestBrief.self),
        "brief.latest.none": decodes(LatestBrief.self),
        "brief.latest.off": decodes(LatestBrief.self),
        "briefs.list": decodes(BriefPage.self),
        "briefs.list.last": decodes(BriefPage.self),
        "briefs.enabled.response": decodes(Enabled.self),
        "guesses": decodes(Guesses.self),
        "guesses.minimal": decodes(Guesses.self),
        "guesses.silent": decodes(Guesses.self),
        "guess.answer": decodes(Answer.self),
        "guess.answer.declined": decodes(Answer.self),
        "guess.why": decodes(Journal.Guess.self),
        "took": decodes(Journal.Took.self),
        "took.waiting": decodes(Journal.Took.self),
        "correction.applied": decodes(Journal.CorrectionOutcome.self),
        "correction.confirm": decodes(Journal.CorrectionOutcome.self),
        "correction.ask": decodes(Journal.CorrectionOutcome.self),
        "correction.not": decodes(Journal.CorrectionOutcome.self),
        "correction.confirm.response": decodes(Journal.CorrectionOutcome.self),
    ]

    /// Request fixtures (the bare body): exact key sets, plus the typed fields decoded.
    static let journalRequests: [String: (Data) throws -> Void] = [
        "entry.create.request": request(EntryCreate.self, required: ["text", "kind", "clientEntryId", "createdAt"]),
        "entry.create.request.voice": request(EntryCreate.self, required: ["text", "kind", "clientEntryId", "createdAt"]),
        "entry.edit.request": request(TextOnly.self, required: ["text"]),
        "briefs.enabled.request": request(Enabled.self, required: ["enabled"]),
        "guess.answer.request": request(Verdict.self, required: ["verdict"]),
        "correction.request": request(Correction.self, required: ["text"], optional: ["about"]),
        "correction.request.minimal": request(Correction.self, required: ["text"], optional: ["about"]),
        "correction.confirm.request": request(CorrectionConfirm.self, required: ["kind", "id", "mode"], optional: ["note"]),
    ]

    // MARK: - Contract 00

    static let platformResponses: [String: (Data) throws -> Void] = [
        "auth.response": decodes(Auth.self),
        "auth.response.waitlisted": decodes(Auth.self),
        "signout.response": decodes(SignedOut.self),
        "access.waitlisted": decodes(Access.self),
        "access.member": decodes(Access.self),
        "waitlist.response": decodes(OnWaitlist.self),
        "public-waitlist.response": decodes(Received.self),
        "redeem.response": decodes(Redeem.self),
        "redeem.response.minimal": decodes(Redeem.self),
        "invites-mine": decodes(InvitesMine.self),
        "meta": decodes(Meta.self),
        "diagnostics.response": decodes(Backend.Endpoints.SendReport.Receipt.self),
    ]

    static let platformRequests: [String: (Data) throws -> Void] = [
        "auth-apple.request": request(AppleSignIn.self, required: ["identityToken", "authorizationCode", "rawNonce"], optional: ["fullName", "email"]),
        "auth-apple.request.minimal": request(AppleSignIn.self, required: ["identityToken", "authorizationCode", "rawNonce"], optional: ["fullName", "email"]),
        "auth-google.request": request(GoogleSignIn.self, required: ["idToken", "rawNonce"]),
        "refresh.request": request(RefreshToken.self, required: ["refreshToken"]),
        "signout.request": request(RefreshToken.self, required: ["refreshToken"]),
        "waitlist.request": request(WaitlistReason.self, required: [], optional: ["reason"]),
        "public-waitlist.request": request(PublicWaitlist.self, required: ["email", "name", "website"], optional: ["reason"]),
        "redeem.request": request(RedeemRequest.self, required: ["code"]),
        "diagnostics.request": request(
            Platform.Diagnostics.Report.self,
            required: ["reportId", "createdAt", "note", "environment", "account", "outbox", "performance", "events", "network", "failures", "crashes"]
        ),
        "diagnostics.request.minimal": request(
            Platform.Diagnostics.Report.self,
            required: ["reportId", "createdAt", "note", "environment", "account", "outbox", "performance", "events", "network", "failures", "crashes"]
        ),
        // The closed id lists the report may carry, shared with the backend (DG.1, DG.4).
        "diagnostics.ids": request(DiagnosticsIds.self, required: ["routes", "screens", "sheets", "controls", "failures"]),
    ]

    @Test("every contract 02 fixture is mapped, and each one decodes or matches its request shape")
    func journalFixtures() throws {
        try checkFolder("02", responses: Self.journalResponses, requests: Self.journalRequests)
    }

    @Test("every contract 00 fixture is mapped, and each one decodes or matches its request shape")
    func platformFixtures() throws {
        try checkFolder("00", responses: Self.platformResponses, requests: Self.platformRequests)
    }

    @Test("every door the app calls is in the diagnostics route list, so a report can name it")
    func pathTemplatesAreDiagnosticRoutes() throws {
        let ids = try JSONDecoder.contract.decode(DiagnosticsIds.self, from: data("00", "diagnostics.ids"))
        for path in Backend.PathTemplate.allCases {
            #expect(ids.routes.contains(path.rawValue), "\(path.rawValue) is missing from fixtures/00/diagnostics.ids.json")
        }
    }

    @Test("every error fixture is a failure envelope with a plain message, named for its code")
    func errorFixtures() throws {
        for folder in ["00", "02"] {
            let names = try fixtureNames(folder).filter { $0.hasPrefix("error.") }
            #expect(!names.isEmpty)
            for name in names {
                let failure = try JSONDecoder.contract.decode(FailureEnvelope.self, from: data(folder, name))
                #expect(!failure.success)
                #expect(name == "error.\(failure.error.code)")
                #expect(!failure.error.message.isEmpty)
                let limited = ["rate_limited", "spend_limited"].contains(failure.error.code)
                #expect((failure.error.retryAfterSeconds != nil) == limited, "\(folder)/\(name)")
            }
        }
    }

    @Test("the decoded contract 02 fixtures carry what the screens read")
    func journalValues() throws {
        let today = try envelope(Today.self, "02", "entries.today")
        #expect(today.entries.map(\.kind) == [.typed, .voice, .imported])
        #expect(today.entries.map(\.reading) == [.read, .reading, .waiting])
        #expect(today.entries.allSatisfy { $0.delivery == .sent })
        #expect(today.entries[0].createdAt < today.entries[1].createdAt, "today is oldest first")

        let v2 = try envelope(LatestBrief.self, "02", "brief.latest.v2")
        #expect(v2.brief?.audio?.durationSeconds == 74.2)
        #expect(v2.brief?.parts.last?.startSeconds == 41.5)
        #expect(try envelope(LatestBrief.self, "02", "brief.latest.off").enabled == false)
        let briefs = try envelope(BriefPage.self, "02", "briefs.list").briefs
        #expect(briefs.map(\.date) == ["2026-10-21", "2026-10-20"], "briefs are newest first")
        #expect(briefs[0].createdAt > briefs[1].createdAt)

        let search = try envelope(EntryPage.self, "02", "entries.search")
        let entry = try #require(search.entries.first)
        let match = try #require(entry.matches?.first)
        let utf16 = Array(entry.text.utf16)
        #expect(String(decoding: utf16[match.start ..< match.start + match.length], as: UTF16.self) == "canal", "ranges are UTF-16 code units")
        // A surrogate pair before the match: the UTF-16 offset differs from the scalar offset, so this fails if ranges were scalars.
        let astral = try envelope(EntryPage.self, "02", "entries.search.astral")
        let astralEntry = try #require(astral.entries.first)
        let astralMatch = try #require(astralEntry.matches?.first)
        let astralUTF16 = Array(astralEntry.text.utf16)
        #expect(String(decoding: astralUTF16[astralMatch.start ..< astralMatch.start + astralMatch.length], as: UTF16.self) == "canal")
        #expect(astralMatch.start != Array(astralEntry.text.unicodeScalars).firstIndex(of: "c"), "the scalar offset would be one less")

        let took = try envelope(Journal.Took.self, "02", "took")
        #expect(took.items.map(\.sureness) == [.fairlySure, .verySure, .justAHunch])
        #expect(took.isSettled)
        #expect(try !envelope(Journal.Took.self, "02", "took.waiting").isSettled)

        guard case let .applied(echo, target, retired) = try envelope(Journal.CorrectionOutcome.self, "02", "correction.applied") else {
            Issue.record("applied didn't decode as applied")
            return
        }
        #expect(echo.hasPrefix("got it."))
        #expect(target?.kind == .fact)
        #expect(retired == 3)
        #expect(try envelope(Journal.CorrectionOutcome.self, "02", "correction.not") == .notACorrection)
    }

    @Test("an enum value the app doesn't know decodes as unknown, never failing the response")
    func unknownEnumValuesDecode() throws {
        let bytes = Data(#"{"id":"x","kind":"podcast","text":"t","createdAt":"2026-10-21T13:02:11Z","day":"2026-10-21","reading":"skimmed"}"#.utf8)
        let entry = try JSONDecoder.contract.decode(Journal.Entry.self, from: bytes)
        #expect(entry.kind == .unknown)
        #expect(entry.reading == .unknown)
        let outcome = try JSONDecoder.contract.decode(Journal.CorrectionOutcome.self, from: Data(#"{"outcome":"later"}"#.utf8))
        #expect(outcome == .failed(.unknown))
    }

    // MARK: - Helpers

    private func checkFolder(_ folder: String, responses: [String: (Data) throws -> Void], requests: [String: (Data) throws -> Void]) throws {
        let names = try fixtureNames(folder)
        #expect(!names.isEmpty)
        for name in names where !name.hasPrefix("error.") {
            if let check = responses[name] ?? requests[name] {
                do {
                    try check(data(folder, name))
                } catch {
                    Issue.record("\(folder)/\(name): \(error)")
                }
            } else {
                Issue.record("\(folder)/\(name).json has no model: map it in ContractFixtureTests")
            }
        }
        for name in Set(responses.keys).union(requests.keys) where !names.contains(name) {
            Issue.record("\(folder)/\(name).json is mapped but missing")
        }
    }

    private func fixtureNames(_ folder: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: Self.root.appendingPathComponent(folder).path)
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }
    }

    private func data(_ folder: String, _ name: String) throws -> Data {
        try Data(contentsOf: Self.root.appendingPathComponent(folder).appendingPathComponent("\(name).json"))
    }

    private func envelope<Payload: Decodable>(_: Payload.Type, _ folder: String, _ name: String) throws -> Payload {
        let decoded = try JSONDecoder.contract.decode(Envelope<Payload>.self, from: data(folder, name))
        #expect(decoded.success)
        return decoded.data
    }

    private static func decodes<Payload: Decodable>(_: Payload.Type) -> (Data) throws -> Void {
        { bytes in _ = try JSONDecoder.contract.decode(Envelope<Payload>.self, from: bytes) }
    }

    private static func request<Body: Decodable>(_: Body.Type, required: Set<String>, optional: Set<String> = []) -> (Data) throws -> Void {
        { bytes in
            _ = try JSONDecoder.contract.decode(Body.self, from: bytes)
            let object = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            let keys = Set(object.keys)
            #expect(required.isSubset(of: keys), "missing \(required.subtracting(keys))")
            #expect(keys.isSubset(of: required.union(optional)), "unexpected \(keys.subtracting(required.union(optional)))")
        }
    }
}
