import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveReportMountTests {
    typealias Diagnostics = Platform.Diagnostics

    @MainActor
    final class DeviceSpy {
        var reads = 0

        func read(_ isOnline: Bool) -> Diagnostics.Environment.Sources {
            reads += 1
            return Diagnostics.Environment.Sources(
                info: nil, osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "arm64",
                locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
                network: Diagnostics.Environment.Network(isOnline: isOnline), freeDiskBytes: 8_000_000_000
            )
        }
    }

    private let first: Store.LocalDatabase
    private let second: Store.LocalDatabase
    private let platform: Platform.AppEnvironment
    private let states: AsyncStream<Session.State>.Continuation

    init() throws {
        let first = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let second = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        self.first = first
        self.second = second
        platform = .preview(openDatabase: { $0 == "user-a" ? first : second })
        let (stream, continuation) = AsyncStream.makeStream(of: Session.State.self)
        states = continuation
        platform.followSessionState(stream)
    }

    private func signIn(_ userID: String, access: Session.AccessState = .member) async throws {
        states.yield(.signedIn(userID: userID, access: access))
        for _ in 0 ..< 200 where platform.sessionState != .signedIn(userID: userID, access: access) {
            try await Task.sleep(for: .milliseconds(5))
        }
        await platform.openStore(for: userID)
    }

    private func outboxRows(in database: Store.LocalDatabase) throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.fetchAll($0) }
    }

    @Test("no open outbox, no sender: the page shows no row")
    func noOutboxNoSender() async throws {
        #expect(LiveReportMount.sender(for: platform) == nil)

        states.yield(.signedIn(userID: "user-a", access: .member))
        for _ in 0 ..< 200 where platform.sessionState == nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(platform.outbox == nil)
        #expect(LiveReportMount.sender(for: platform) == nil, "signed in, but the store isn't open yet")
    }

    @Test("signed in with the store open, there is a sender, and the counts never read the phone")
    func theCountsNeverReadThePhone() async throws {
        try await signIn("user-a")
        let spy = DeviceSpy()

        let sender = try #require(LiveReportMount.sender(for: platform, device: spy.read))
        _ = await sender.included()

        #expect(spy.reads == 0, "the free-disk read is for a send only (reason 7D9E.1)")
    }

    @Test("a send after the stack closed writes nothing into any store, and the next person's store gets nothing")
    func aSendAfterTheStackClosedWritesNothing() async throws {
        try await signIn("user-a")
        let spy = DeviceSpy()
        let sender = try #require(LiveReportMount.sender(for: platform, device: spy.read))

        await platform.closeStore(erasing: false)
        let outcome = await sender.send(note: "after the session ended")
        try await signIn("user-b")

        guard case .failed = outcome else {
            Issue.record("expected the sheet's failure, got \(outcome)")
            return
        }
        #expect(spy.reads == 0)
        #expect(try outboxRows(in: second).isEmpty)
        let events = try await second.writer.read { try Store.DiagnosticRow.fetchAll($0) }
        #expect(!events.contains { String(decoding: $0.payload, as: UTF8.self).contains("control_tapped") })
    }

    @Test("the sender is rebuilt for a new outbox and gone without one")
    func theSenderFollowsTheOutbox() async throws {
        try await signIn("user-a")
        let before = try #require(LiveReportMount.sender(for: platform))

        await platform.closeStore(erasing: true)
        #expect(LiveReportMount.sender(for: platform) == nil)
        try await signIn("user-b")
        let after = try #require(LiveReportMount.sender(for: platform))

        #expect(before !== after)
    }

    @Test("the account names the provider and the access only; an access the door can't name reads as member")
    func theAccountIsContentFree() throws {
        #expect(LiveReportMount.account(in: nil) == nil)
        #expect(LiveReportMount.account(in: .signedOut(hasSignedInBefore: true, reason: .none)) == nil)
        #expect(
            LiveReportMount.account(in: .signedIn(userID: "user-a", access: .waitlisted))
                == Diagnostics.Account(provider: .apple, access: .waitlisted, entitlement: .none)
        )
        #expect(LiveReportMount.account(in: .signedIn(userID: "user-a", access: .unknown))?.access == .member)

        let encoded = try JSONSerialization.jsonObject(
            with: Backend.Coding.encoder.encode(#require(LiveReportMount.account(in: .signedIn(userID: "user-a", access: .member))))
        ) as? NSDictionary
        #expect(Set(encoded?.allKeys.compactMap { $0 as? String } ?? []) == ["provider", "access", "entitlement"], "no id, no email, no name")
    }
}
