import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ReportTests {
    typealias Diagnostics = Platform.Diagnostics

    static let topLevelKeys: Set<String> = [
        "reportId", "createdAt", "note", "environment", "account", "events", "network", "outbox", "failures", "performance", "crashes",
    ]

    private func environment() -> Diagnostics.Environment {
        Diagnostics.Environment(sources: .init(
            info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"],
            osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "iPhone17,1",
            locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt, contentSize: .large,
            reduceMotion: false, voiceOver: false, network: .wifi, freeDiskBytes: 8_000_000_000
        ))
    }

    private func report(
        note: String? = nil,
        events: [Diagnostics.Stamped<Diagnostics.Event>] = [],
        network: [Diagnostics.Stamped<Diagnostics.Request>] = [],
        failures: [Diagnostics.Stamped<Diagnostics.Failure>] = [],
        crashes: [Diagnostics.Stamped<Diagnostics.Crash>] = []
    ) throws -> Diagnostics.Report {
        try Diagnostics.Report(
            reportID: #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000D1")), createdAt: Date(timeIntervalSince1970: 1_792_569_604.2),
            note: note, environment: environment(), account: .init(provider: .apple, access: .member, entitlement: .trial),
            events: events, network: network, outbox: .empty, failures: failures, performance: .none, crashes: crashes
        )
    }

    private func object(_ value: some Encodable) throws -> NSDictionary {
        try #require(try JSONSerialization.jsonObject(with: Backend.Coding.encoder.encode(value)) as? NSDictionary)
    }

    @Test("both contract fixtures decode into a report and encode back to the same JSON", arguments: ["diagnostics.request", "diagnostics.request.minimal"])
    func theFixturesRoundTrip(_ name: String) throws {
        let bytes = try Fixtures.data("00", name)
        let fixture = try #require(try JSONSerialization.jsonObject(with: bytes) as? NSDictionary)

        let decoded = try JSONDecoder.contract.decode(Diagnostics.Report.self, from: bytes)

        #expect(try object(decoded) == fixture)
    }

    @Test("a report has exactly the door's fields, every one present even when empty or null")
    func aReportHasExactlyTheDoorsFields() throws {
        let encoded = try object(report())

        #expect(Set(encoded.allKeys.compactMap { $0 as? String }) == Self.topLevelKeys)
        #expect(encoded["note"] is NSNull)
        let outbox = try #require(encoded["outbox"] as? NSDictionary)
        #expect(Set(outbox.allKeys.compactMap { $0 as? String }) == ["queued", "sending", "sent", "failed", "oldestAgeSeconds", "lastFailureCodes"])
        #expect(outbox["oldestAgeSeconds"] is NSNull)
        let performance = try #require(encoded["performance"] as? NSDictionary)
        #expect(Set(performance.allKeys.compactMap { $0 as? String }) == ["launchMs", "hitchRates", "memoryWarnings", "thermalChanges"])
        #expect(performance["launchMs"] is NSNull)
        let account = try #require(encoded["account"] as? NSDictionary)
        #expect(Set(account.allKeys.compactMap { $0 as? String }) == ["provider", "access", "entitlement"])
    }

    @Test("no free text appears anywhere in a report except the labelled note")
    func noFreeTextExceptTheNote() throws {
        let full = try JSONDecoder.contract.decode(Diagnostics.Report.self, from: Fixtures.data("00", "diagnostics.request"))

        let parts: [Any] = [full.events, full.network, full.failures, full.crashes, full.account, full.outbox, full.performance]
        for part in parts {
            #expect(ContentCheck.values(in: part).isEmpty, "\(type(of: part)) carries text")
        }
        #expect(Diagnostics.Environment.checked(full.environment.appVersion, Diagnostics.Environment.versionPattern) != nil)
        #expect(Diagnostics.Environment.checked(full.environment.deviceModel, Diagnostics.Environment.modelPattern) != nil)
        #expect(Diagnostics.Environment.checked(full.environment.locale, Diagnostics.Environment.localePattern) != nil)
        #expect(Diagnostics.Environment.checked(full.environment.timeZone, Diagnostics.Environment.timeZonePattern) != nil)
        #expect(UUID(uuidString: full.reportId) != nil)
        #expect(full.reportId == full.reportId.lowercased())
        #expect(full.note == "the brief stopped halfway")
    }

    @Test("the note is trimmed, cut to the door's limit, and null when nothing is left")
    func theNoteIsCleaned() throws {
        #expect(try report(note: "  the brief stopped \n").note == "the brief stopped")
        #expect(try report(note: "   ").note == nil)
        #expect(try report(note: nil).note == nil)
        #expect(try report(note: String(repeating: "a", count: 1001)).note?.count == Diagnostics.Report.maxNoteCharacters)
    }

    @Test("an emoji-heavy note is cut in UTF-16 units, as the door counts, so the door takes it")
    func anEmojiNoteFitsTheDoor() throws {
        let built = try report(note: String(repeating: "😀", count: 600))
        let encoded = try object(built)

        // A JSON string's length in the door is NSString's length here: UTF-16 units.
        let sent = try #require(encoded["note"] as? NSString)
        #expect(sent.length == Diagnostics.Report.maxNoteCharacters, "600 emoji are 1200 units; the door takes at most 1000")
        #expect(built.note?.count == 500)
    }

    @Test("the cut never splits a character: one that would cross the limit is left out whole")
    func theCutKeepsWholeCharacters() {
        let family = "👨‍👩‍👧" // one character, 8 UTF-16 units
        let text = "a" + String(repeating: family, count: 125)

        let capped = Diagnostics.Report.capped(text, utf16: 1000)

        #expect(capped.utf16.count == 993)
        #expect(capped == "a" + String(repeating: family, count: 124))
        #expect(Diagnostics.Report.capped("short", utf16: 1000) == "short")
    }

    @Test("each list keeps at most its ring's cap, the newest")
    func eachListIsCapped() throws {
        let at = Date(timeIntervalSince1970: 1_792_569_604)
        let crashes = (0 ... Diagnostics.Ring.crashes.cap).map { index in
            Diagnostics.Stamped(at: at.addingTimeInterval(TimeInterval(index)), body: Diagnostics.Crash(kind: index == 0 ? .hang : .crash))
        }

        let built = try report(crashes: crashes)

        #expect(built.crashes.count == Diagnostics.Ring.crashes.cap)
        #expect(built.crashes.first?.body.kind == .crash, "the oldest (the hang) was dropped")
    }

    @Test("a report with every ring full of its largest records stays under the door's 2 MB")
    func aFullReportStaysUnderTwoMegabytes() throws {
        let at = Date(timeIntervalSince1970: 1_792_569_604.2)
        let item = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
        let events = Array(repeating: Diagnostics.Stamped(at: at, body: Diagnostics.Event.playbackStarted(itemID: item, positionMs: 86_400_000)), count: 2000)
        let request = Diagnostics.Request(
            method: .delete, route: .sourcesByIdConnect, status: 504, code: .idempotencyMismatch, ms: 86_400_000, retries: 20, idempotency: .replayed
        )
        let network = Array(repeating: Diagnostics.Stamped(at: at, body: request), count: 2000)
        let failures = Array(
            repeating: Diagnostics.Stamped(at: at, body: Diagnostics.Failure(code: .invalidCredentials, screen: .legacyOnboarding)),
            count: 500
        )
        let crashes = Array(repeating: Diagnostics.Stamped(at: at, body: Diagnostics.Crash(kind: .crash)), count: 100)

        let bytes = try Backend.Coding.encoder.encode(report(
            note: String(repeating: "x", count: 1000), events: events, network: network, failures: failures, crashes: crashes
        ))

        #expect(bytes.count < 2 * 1024 * 1024)
        #expect(bytes.count > 500_000, "the test really filled the rings")
    }

    @Test("the account and performance lists are the door's")
    func theListsAreTheDoors() {
        #expect(Diagnostics.Account.Provider.allCases.map(\.rawValue) == ["apple", "google"])
        #expect(Diagnostics.Account.Access.allCases.map(\.rawValue) == ["waitlisted", "approved", "member", "staff", "suspended"])
        #expect(Diagnostics.Account.Entitlement.allCases.map(\.rawValue) == ["none", "trial", "active", "expired"])
        #expect(Diagnostics.Performance.ThermalState.allCases.map(\.rawValue) == ["nominal", "fair", "serious", "critical"])
    }

    @Test("the outbox summary keeps the last ten codes and never a negative count")
    func theOutboxSummaryIsBounded() {
        let codes = Array(repeating: Diagnostics.ErrorCode.internal, count: 12) + [.notFound]
        let summary = Diagnostics.OutboxSummary(queued: -1, sending: 0, sent: 3, failed: 0, oldestAgeSeconds: -5, lastFailureCodes: codes)

        #expect(summary.queued == 0)
        #expect(summary.oldestAgeSeconds == 0)
        #expect(summary.lastFailureCodes.count == 10)
        #expect(summary.lastFailureCodes.last == .notFound)
    }
}
