import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveReportSenderTests {
    typealias Diagnostics = Platform.Diagnostics

    private let database: Store.LocalDatabase
    private let log = Platform.Log.Recorder()
    private let now = Date(timeIntervalSince1970: 1_792_569_604.2)
    private let reachability = StreamingReachability()
    private let outbox: Store.Outbox
    private let recorder: Diagnostics.Recorder

    init() throws {
        let database = try Store.LocalDatabase.inMemory()
        let now = now
        self.database = database
        outbox = Store.Outbox(database: database, now: { now }, log: log)
        recorder = Diagnostics.Recorder(database: database, now: { now }, clock: TestClock(), log: log)
    }

    private func sender() -> Diagnostics.LiveReportSender {
        let now = now
        return Diagnostics.LiveReportSender(
            recorder: recorder, outbox: outbox, reachability: reachability,
            context: {
                Diagnostics.ReportContext(
                    environment: Diagnostics.Environment(sources: .init(
                        info: nil, osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "arm64",
                        locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
                        network: .unknown, freeDiskBytes: nil
                    )),
                    account: .init(provider: .apple, access: .member, entitlement: .trial)
                )
            },
            now: { now }
        )
    }

    private func rows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.fetchAll($0) }
    }

    @Test("the sheet's counts are the report's own")
    func theCountsAreTheReports() async {
        await recorder.record(.event(.appLaunch))
        await recorder.record(.event(.appForeground))
        await recorder.record(.request(.init(method: .get, route: .briefsLatest, status: 504, code: .upstreamTimeout, ms: 30000)))
        await recorder.record(.failure(.init(code: .server, screen: .journal)))
        await recorder.record(.crash(.init(kind: .hang)))

        let included = await sender().included()

        #expect(included.events == 2)
        #expect(included.requests == 1)
        #expect(included.problems == 2)
        #expect(included.unsent == 0)
        #expect(included.days == 1)
    }

    @Test("send queues one diagnostics.send row holding the report and the person's note, and says whether it is going out now")
    func sendQueuesTheReport() async throws {
        await recorder.record(.event(.appLaunch))

        let outcome = await sender().send(note: "  the brief stalled  ")

        guard case let .queued(reportID, online) = outcome else {
            Issue.record("expected the report to be queued, got \(outcome)")
            return
        }
        #expect(online)
        let row = try #require(try rows().first)
        #expect(try rows().count == 1)
        #expect(row.id == reportID)
        #expect(row.operation == .diagnosticsSend)
        let stored = try Backend.Coding.decoder.decode(Diagnostics.Report.self, from: row.payload)
        #expect(stored.note == "the brief stalled")
        #expect(stored.events.count == 1)
    }

    @Test("offline, the same send is saved and says it will go later")
    func offlineSendIsSaved() async throws {
        reachability.send(false)

        let outcome = await sender().send(note: nil)

        guard case let .queued(_, online) = outcome else {
            Issue.record("expected the report to be queued, got \(outcome)")
            return
        }
        #expect(!online)
        #expect(try rows().count == 1)
    }

    @Test("a report's receipt reaches whoever is listening")
    func receiptsAreForwarded() async throws {
        let sender = sender()
        var receipts = sender.receipts().makeAsyncIterator()
        try await Task.sleep(for: .milliseconds(50))

        // The drainer's job is tested with the outbox; here, only the forwarding.
        await outbox.publishForTests(.init(reportID: "r1", reference: "r-7KQ2"))

        #expect(await receipts.next() == Flows.ReportReceipt(reportID: "r1", reference: "r-7KQ2"))
    }
}
