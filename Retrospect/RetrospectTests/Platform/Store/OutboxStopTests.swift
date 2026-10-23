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

    @Test("stop called from a cancelled task still returns once the drain is over, and nothing is re-armed after it")
    func stopFromACancelledTask() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let sender = HangingSender()
        let outbox = Store.Outbox(database: database, sender: sender, log: Platform.Log.Recorder())
        try await outbox.enqueueEntry(#require(Store.EntryDraft(id: id, kind: .typed, text: "private words", createdAt: Date())))
        let drain = Task { await outbox.drain(reason: .manual) }
        for _ in 0 ..< 500 where sender.sends == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }

        let stopper = Task { await outbox.stop() }
        stopper.cancel() // the caller is already cancelled when it waits for the drain
        await stopper.value
        await drain.value

        let row = try await database.writer.read { try Store.OutboxRow.fetchOne($0) }
        #expect(row?.status == .pending)
        #expect(await outbox.retryWakeArmed == false, "a stopped outbox never schedules a retry")
    }
}
