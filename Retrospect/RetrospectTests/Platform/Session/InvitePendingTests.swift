import Foundation
@testable import Retrospect
import Security
import Testing

/// INVITE-FLAGS: `InviteCenter.hasPendingCode` mirrors the pending slot (the
/// Keychain item), from every path that writes or reads it.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct InvitePendingTests {
    private static let code = "7KQ2M9XD4RTAB"

    private func harness(
        access: Session.AccessState = .waitlisted,
        pending: String? = InvitePendingTests.code
    ) throws -> (SessionHarness, Session.InviteCenter) {
        let stored = Session.Credentials(
            accessToken: SessionHarness.signedIn.accessToken, accessTokenExpiresAt: SessionHarness.signedIn.accessTokenExpiresAt,
            refreshToken: SessionHarness.signedIn.refreshToken, userID: SessionHarness.signedIn.userID,
            access: access, firstName: "sam", provider: .apple, appleUserID: "001234.invented"
        )
        let h = try SessionHarness(stored: stored)
        if let pending {
            try h.keychain.write(Data(pending.utf8), account: "pending_invite_code")
        }
        let center = Session.InviteCenter(store: h.store, client: h.client, session: h.manager, log: h.recorder)
        return (h, center)
    }

    private func pending(_ h: SessionHarness) -> String? {
        h.keychain.contents["pending_invite_code"].flatMap { String(bytes: $0, encoding: .utf8) }
    }

    private func settle(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("a code kept by an earlier launch counts as soon as the center starts, signed in or out")
    func aStoredCodeCountsAtStart() async throws {
        let (h, center) = try harness()
        h.reachability.set(online: false)
        #expect(!center.hasPendingCode, "nothing is known before start")

        center.start()
        try await settle { center.hasPendingCode }

        #expect(center.hasPendingCode)
        let (_, empty) = try harness(pending: nil)
        await empty.sync()
        #expect(!empty.hasPendingCode)
    }

    @Test("a link's code sets it; a successful tear spends the code and clears it")
    func aLinkSetsItAndTheTearClearsIt() async throws {
        let (h, center) = try harness(pending: nil)
        let usable = try Fixtures.data("01", "invite.check.usable")
        let redeemed = try Fixtures.data("00", "redeem.response")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }, "/v2/invites/redeem": { _, _ in (200, redeemed) }])

        await center.received(code: "7kq2-m9xd-4rta-b")
        #expect(center.hasPendingCode)
        #expect(pending(h) == Self.code)

        center.beginTear()
        guard case .yours = await center.tear() else {
            Issue.record("expected yours")
            return
        }
        #expect(!center.hasPendingCode)
        #expect(pending(h) == nil)
    }

    @Test("a typed code sets it only when usable")
    func aTypedCodeSetsItOnlyWhenUsable() async throws {
        let (h, center) = try harness(pending: nil)
        let used = try Fixtures.data("00", "error.invite_used")
        h.serve(["/v2/invites/check": { _, _ in (400, used) }])
        await center.type(code: Self.code)
        #expect(!center.hasPendingCode)

        let usable = try Fixtures.data("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])
        await center.type(code: Self.code)
        #expect(center.hasPendingCode)
    }

    @Test("the server dropping the code clears it: already in, used, expired, invalid", arguments: [
        ("01", "invite.check.alreadyin", 200), ("00", "error.invite_used", 400), ("00", "error.invite_expired", 400),
        ("00", "error.invite_invalid", 400),
    ])
    func aDroppedCodeClearsIt(_ folder: String, _ name: String, _ status: Int) async throws {
        let (h, center) = try harness()
        let body = try Fixtures.data(folder, name)
        h.serve(["/v2/invites/check": { _, _ in (status, body) }])
        await center.sync()
        #expect(center.hasPendingCode)

        await center.afterSignIn()

        #expect(!center.hasPendingCode)
        #expect(pending(h) == nil)
    }

    @Test("a check that waits (offline) keeps the code and the flag")
    func aWaitingCheckKeepsIt() async throws {
        let (h, center) = try harness()
        h.reachability.set(online: false)

        await center.afterSignIn()

        #expect(center.ticket == .waiting(.offline))
        #expect(center.hasPendingCode)
    }

    @Test("the code belongs to the phone: signing out keeps it, and it is still there for the next sign-in")
    func signingOutKeepsIt() async throws {
        let (h, center) = try harness()
        h.reachability.set(online: false)
        center.start()
        try await settle { center.hasPendingCode }

        _ = await h.manager.signOut(force: true)
        try await settle { center.access == .unknown }

        #expect(center.access == .unknown)
        #expect(center.hasPendingCode, "a sign-out does not clear the pending code")
        #expect(pending(h) == Self.code)
    }

    @Test("a Keychain write that fails leaves the flag as the slot is: unset after a failed save, set after a failed clear")
    func aFailedWriteKeepsTheOldValue() async throws {
        let (h, center) = try harness(access: .member, pending: nil)
        h.keychain.failEveryCall(with: errSecInteractionNotAllowed)
        await center.received(code: Self.code)
        #expect(!center.hasPendingCode)
        #expect(pending(h) == nil)
        #expect(h.recorder.events.contains(.keychainWriteFailed(.pendingInvite, status: errSecInteractionNotAllowed)))

        let (h2, center2) = try harness()
        let redeemed = try Fixtures.data("00", "redeem.response")
        let keychain = h2.keychain
        // The redeem lands, then the Keychain stops answering: the clear fails and the code is still there.
        h2.serve(["/v2/invites/redeem": { _, _ in
            keychain.failEveryCall(with: errSecInteractionNotAllowed)
            return (200, redeemed)
        }])
        await center2.sync()
        center2.beginTear()
        _ = await center2.tear()
        keychain.failEveryCall(with: nil)

        #expect(pending(h2) == Self.code)
        #expect(center2.hasPendingCode, "the flag follows the slot, not the attempt")
    }

    @Test("the flag carries no code: no log event holds it")
    func theLogHoldsNoCode() async throws {
        let (h, center) = try harness(pending: nil)
        h.reachability.set(online: false)
        await center.received(code: Self.code)
        #expect(h.recorder.events.allSatisfy { !String(describing: $0).contains(Self.code) })
    }
}
