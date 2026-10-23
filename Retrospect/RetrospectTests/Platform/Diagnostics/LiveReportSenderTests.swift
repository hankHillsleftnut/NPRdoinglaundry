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

    /// How many times the sender asked for the device and the account (the free-disk read lives there).
    private let contextReads = Counter()

    @MainActor
    final class Counter {
        var value = 0
    }

    private func sender() -> Diagnostics.LiveReportSender {
        let now = now
        let reads = contextReads
        return Diagnostics.LiveReportSender(
            recorder: recorder, outbox: outbox, reachability: reachability,
            context: { _ in
                reads.value += 1
                return Diagnostics.ReportContext(
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

        #expect(included.events == 3, "the two recorded, and the sheet opening")
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
        #expect(stored.events.count == 2, "the launch, and the send button")
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

    @Test("the counts never read the phone; only a send does, once")
    func theCountsNeverReadThePhone() async {
        let sender = sender()

        _ = await sender.included()
        _ = await sender.included()
        #expect(contextReads.value == 0, "the device (and its free disk) is read for a send only")

        _ = await sender.send(note: nil)
        #expect(contextReads.value == 1)
    }

    @Test("the report's last events say where it came from: the sheet opened, then send on settings")
    func theReportNamesItsOrigin() async throws {
        await recorder.record(.event(.appLaunch))
        let sender = sender()

        _ = await sender.included()
        _ = await sender.send(note: nil)

        let stored = try Backend.Coding.decoder.decode(Diagnostics.Report.self, from: #require(try rows().first).payload)
        #expect(stored.events.map(\.body) == [.appLaunch, .sheetOpened(.sendReport), .controlTapped(.reportSend, on: .settings)])
    }

    @Test("two sends queue two rows, one each")
    func eachSendIsOneRow() async throws {
        let sender = sender()

        _ = await sender.send(note: "one")
        _ = await sender.send(note: "two")

        #expect(try rows().count == 2)
        #expect(try rows().allSatisfy { $0.operation == .diagnosticsSend })
    }

    @Test("after the outbox stopped (sign-out, the session ended), a send fails and writes and records nothing")
    func aSendAfterTheStackClosedWritesNothing() async throws {
        await recorder.record(.event(.appLaunch))
        let sender = sender()
        await outbox.stop()

        let counts = await sender.included()
        let outcome = await sender.send(note: "too late")

        #expect(counts == .empty)
        #expect(outcome == .failed(Flows.Failure(.unknown)))
        #expect(try rows().isEmpty)
        #expect(try await recorder.rows(in: .events).count == 1, "no sheet or tap event waits for the next person")
        #expect(contextReads.value == 0)
    }
}
