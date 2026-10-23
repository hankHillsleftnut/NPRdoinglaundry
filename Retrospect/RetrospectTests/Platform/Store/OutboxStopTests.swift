import Foundation
import GRDB
@testable import Retrospect
import Testing

/// A send that never finishes by itself: it ends only when its task is cancelled.
private final class HangingSender: Store.OutboxSending, @unchecked Sendable {
    private let lock = NSLock()
    private var started = 0

    var sends: Int {
        lock.withLock { started }
    }

    func send(_: Store.OutboxRow) async throws -> Store.OutboxSendResult {
        lock.withLock { started += 1 }
        try await Task.sleep(for: .seconds(3600))
        return Store.OutboxSendResult()
    }
}

@Suite(.timeLimit(.minutes(1)))
struct OutboxStopTests {
    private let id = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1") ?? UUID()

    @Test("stop cancels the send in flight and returns only once the drain is over: nothing of theirs goes out after it")
    func stopCancelsTheSendInFlight() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let sender = HangingSender()
        let outbox = Store.Outbox(database: database, sender: sender, log: Platform.Log.Recorder())
        try await outbox.enqueueEntry(#require(Store.EntryDraft(id: id, kind: .typed, text: "private words", createdAt: Date())))
        let drain = Task { await outbox.drain(reason: .manual) }
        for _ in 0 ..< 500 where sender.sends == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(sender.sends == 1)

        await outbox.stop()

        let row = try await database.writer.read { try Store.OutboxRow.fetchOne($0) }
        #expect(row?.status == .pending, "put back, no attempt counted")
        #expect(row?.attempts == 0)
        await drain.value
        await outbox.drain(reason: .manual)
        await outbox.start()
        #expect(sender.sends == 1, "a stopped outbox sends nothing more, whatever triggers it")
    }

    @Test("a back-online trigger that arrives during a pass that then pauses offline gets its own pass")
    func aTriggerDuringAPausingPassIsNotLost() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let sender = ScriptedSender()
        let gate = Gate()
        sender.gate = gate
        let outbox = Store.Outbox(database: database, sender: sender, log: Platform.Log.Recorder())
        try await outbox.enqueueEntry(#require(Store.EntryDraft(id: id, kind: .typed, text: "words", createdAt: Date())))
        sender.script(id.uuidString.lowercased(), [.failure(Backend.Failure(.offline))])
        let first = Task { await outbox.drain(reason: .manual) }
        for _ in 0 ..< 500 where gate.waiting == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }

        await outbox.drain(reason: .reachability) // the phone came back online while the send was out
        gate.open() // the send comes back "offline": the pass pauses
        await first.value

        #expect(sender.sends.count == 2, "the trigger that arrived mid-pass was answered, not dropped")
        #expect(try await database.writer.read { try Store.OutboxRow.fetchOne($0) }?.status == .done)
    }
}
