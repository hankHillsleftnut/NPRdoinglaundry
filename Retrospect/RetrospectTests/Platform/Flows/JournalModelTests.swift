import Foundation
@testable import Retrospect
import Testing

struct JournalModelTests {
    typealias Journal = Flows.Journal

    @Test("an entry keeps its row identity from waiting to sent, so a list never replaces the row")
    func entryIdentityIsStable() throws {
        let key = "00000000-0000-4000-8000-000000000901"
        let local = Journal.Entry(local: key, kind: .typed, text: "dentist at 3", createdAt: .distantPast, day: "2026-10-21", delivery: .waiting)
        let json = #"{"id":"s-101","clientEntryId":"\#(key)","kind":"typed","text":"dentist at 3","#
            + #""createdAt":"2026-10-21T13:02:11.410Z","day":"2026-10-21","reading":"waiting"}"#
        let sent = try JSONDecoder.contract.decode(Journal.Entry.self, from: Data(json.utf8))
        #expect(local.id == key)
        #expect(sent.id == local.id)
        #expect(sent.serverId == "s-101")
        #expect(local.serverId == nil)
        #expect(sent.delivery == .sent)
    }

    @Test("an entry the app didn't send is identified by the server's id")
    func importedEntryUsesServerId() throws {
        let json = #"{"id":"s-1","kind":"imported","text":"t","createdAt":"2026-10-21T13:02:11Z","day":"2026-10-21","reading":"read"}"#
        let entry = try JSONDecoder.contract.decode(Journal.Entry.self, from: Data(json.utf8))
        #expect(entry.id == "s-1")
        #expect(entry.clientEntryId == nil)
    }

    @Test("the acknowledgement never repeats twice in a row over 100 sends")
    func acknowledgementNeverRepeats() {
        var previous: String?
        var seed: UInt64 = 7
        for _ in 0 ..< 100 {
            let next = Journal.Acknowledgements.next(after: previous) { count in
                seed = seed &* 6_364_136_223_846_793_005 &+ 1
                return Int(seed >> 33) % count
            }
            #expect(next != nil)
            #expect(next != previous)
            previous = next
        }
    }

    @Test("failures are equal by kind, whatever the server's message")
    func failureEquality() {
        #expect(Flows.Failure(.network, message: "no signal") == .network)
        #expect(Flows.Failure(.server) != .network)
        #expect(Flows.Failure.rateLimited(retryAfterSeconds: 60) == Flows.Failure(.rateLimited(retryAfterSeconds: 60), message: "give it a minute"))
    }

    @Test("only failures that trying again can fix are retryable")
    func failureRetryability() {
        #expect(Flows.Failure.network.isRetryable)
        #expect(Flows.Failure.server.isRetryable)
        #expect(Flows.Failure.rateLimited(retryAfterSeconds: 30).isRetryable)
        #expect(!Flows.Failure.inviteRequired.isRetryable)
        #expect(!Flows.Failure.suspended.isRetryable)
        #expect(!Flows.Failure.invalid.isRetryable)
        #expect(!Flows.Failure.spendLimited(retryAfterSeconds: 3600).isRetryable)
        #expect(!Flows.Failure.updateRequired.isRetryable)
    }
}
