import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ReportBuilderTests {
    typealias Diagnostics = Platform.Diagnostics

    private let database: Store.LocalDatabase
    private let log = Platform.Log.Recorder()
    private let now = Date(timeIntervalSince1970: 1_792_569_604.2)
    private let clock = TestClock()

    init() throws {
        database = try Store.LocalDatabase.inMemory()
    }

    private func recorder() -> Diagnostics.Recorder {
        let now = now
        return Diagnostics.Recorder(database: database, now: { now }, clock: clock, log: log)
    }

    private func environment() -> Diagnostics.Environment {
        Diagnostics.Environment(sources: .init(
            info: nil, osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "arm64",
            locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
            network: .unknown, freeDiskBytes: nil
        ))
    }

    private func build(_ recorder: Diagnostics.Recorder, outbox: Diagnostics.OutboxSummary = .empty) async throws -> Diagnostics.Report {
        try await Diagnostics.ReportBuilder.build(
            now: now,
            inputs: .init(
                note: "it stopped",
                environment: environment(),
                account: .init(provider: .apple, access: .member, entitlement: .trial),
                outbox: outbox
            ),
            recorder: recorder
        )
    }

    /// Synchronous writes: in an async test, `writer.write` picks GRDB's async overload.
    private func execute(_ sql: String, _ arguments: StatementArguments = []) throws {
        try database.writer.write { try $0.execute(sql: sql, arguments: arguments) }
    }

    private func insertOutboxRow(id: String, status: Store.OutboxStatus, createdAt: String, errorCode: String? = nil) throws {
        try execute(
            """
            INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, last_error_code, created_at)
            VALUES (?, 'entry.create', ?, X'7B7D', 0, ?, ?, ?, ?)
            """,
            [id, id, createdAt, status.rawValue, errorCode, createdAt]
        )
    }

    @Test("the report carries every ring, stamped, in order, with what the caller knows")
    func theReportCarriesEveryRing() async throws {
        let recorder = recorder()
        let item = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
        await recorder.record(.event(.appLaunch))
        await recorder.record(.event(.playbackStarted(itemID: item, positionMs: 0)))
        await recorder.record(.request(.init(method: .get, route: .briefsLatest, status: 504, code: .upstreamTimeout, ms: 30000)))
        await recorder.record(.failure(.init(code: .server, screen: .journal)))
        await recorder.record(.crash(.init(kind: .hang)))

        let report = try await build(recorder)

        #expect(report.events.map(\.body) == [.appLaunch, .playbackStarted(itemID: item, positionMs: 0)])
        #expect(report.events.allSatisfy { abs($0.at.timeIntervalSince(now)) < 0.001 })
        #expect(report.network.map(\.body) == [.init(method: .get, route: .briefsLatest, status: 504, code: .upstreamTimeout, ms: 30000)])
        #expect(report.failures.map(\.body) == [.init(code: .server, screen: .journal)])
        #expect(report.crashes.map(\.body) == [.init(kind: .hang)])
        #expect(report.note == "it stopped")
        #expect(report.account == .init(provider: .apple, access: .member, entitlement: .trial))
        #expect(abs(report.createdAt.timeIntervalSince(now)) < 0.001)
        #expect(UUID(uuidString: report.reportId) != nil)
    }

    @Test("a ring row that no longer decodes is skipped, never a failed report")
    func anUndecodableRowIsSkipped() async throws {
        let recorder = recorder()
        await recorder.record(.event(.appLaunch))
        await recorder.flush()
        try execute("INSERT INTO diagnostics (ring, at, payload) VALUES ('events', '2026-10-21T08:00:05.000Z', X'7B7D')")
        await recorder.record(.event(.appForeground))

        let report = try await build(recorder)

        #expect(report.events.map(\.body) == [.appLaunch, .appForeground])
    }

    @Test("an empty outbox reads as all zeros with no oldest age")
    func anEmptyOutboxReadsAsZeros() throws {
        #expect(try Diagnostics.OutboxSummary.read(from: database, now: now) == .empty)
    }

    @Test("the outbox summary counts by status, ages the oldest unsent item, and keeps only contract codes, newest last")
    func theOutboxSummaryReadsTheTable() throws {
        try insertOutboxRow(id: "a", status: .done, createdAt: "2026-10-21T07:00:00.000Z")
        try insertOutboxRow(id: "b", status: .pending, createdAt: "2026-10-21T07:59:00.200Z")
        try insertOutboxRow(id: "c", status: .inFlight, createdAt: "2026-10-21T07:59:30.000Z", errorCode: "timedOut")
        try insertOutboxRow(id: "d", status: .dead, createdAt: "2026-10-21T07:59:40.000Z", errorCode: "invalid_request")
        try insertOutboxRow(id: "e", status: .dead, createdAt: "2026-10-21T07:59:50.000Z", errorCode: "upstream_timeout")
        try insertOutboxRow(id: "f", status: .pending, createdAt: "2026-10-21T08:00:00.000Z")

        let summary = try Diagnostics.OutboxSummary.read(from: database, now: now)

        #expect(summary.queued == 2)
        #expect(summary.sending == 1)
        #expect(summary.sent == 1)
        #expect(summary.failed == 2)
        #expect(summary.oldestAgeSeconds == 64, "the done row doesn't count; b is 64 s old")
        #expect(summary.lastFailureCodes == [.invalidRequest, .upstreamTimeout], "a phone-side kind isn't a contract code")
    }

    @Test("the outbox summary never names more than the last ten codes")
    func theOutboxSummaryKeepsTenCodes() throws {
        for index in 0 ..< 12 {
            try insertOutboxRow(
                id: "r\(index)",
                status: .dead,
                createdAt: "2026-10-21T07:00:\(String(format: "%02d", index)).000Z",
                errorCode: index == 11 ? "not_found" : "internal"
            )
        }

        let summary = try Diagnostics.OutboxSummary.read(from: database, now: now)

        #expect(summary.lastFailureCodes.count == 10)
        #expect(summary.lastFailureCodes.last == .notFound)
    }
}
