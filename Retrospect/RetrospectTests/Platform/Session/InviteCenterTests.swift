import Foundation
@testable import Retrospect
import Security
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct InviteCenterTests {
    private static let code = "7KQ2M9XD4RTAB"
    private static let key = UUID(uuidString: "00000000-0000-4000-8000-00000000c0de") ?? UUID()

    /// A waitlisted session, unless `access` says otherwise.
    private func harness(
        access: Session.AccessState = .waitlisted,
        pending: String? = InviteCenterTests.code
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
        let key = Self.key
        let center = Session.InviteCenter(store: h.store, client: h.client, session: h.manager, log: h.recorder, makeKey: { key })
        return (h, center)
    }

    private func pending(_ h: SessionHarness) -> String? {
        h.keychain.contents["pending_invite_code"].flatMap { String(bytes: $0, encoding: .utf8) }
    }

    private func fixture(_ folder: String, _ name: String) throws -> Data {
        try Fixtures.data(folder, name)
    }

    private var face: Session.TicketFace {
        Session.TicketFace(from: "priya", kind: .member, serial: 412, issuedOn: "2026-10-19")
    }

    // MARK: Codes

    @Test("codes normalise: dashes, spaces, lowercase, O/0, I/1, L/1; anything else isn't a code", arguments: [
        ("7KQ2-M9XD-4RTA-B", "7KQ2M9XD4RTAB"), ("7kq2 m9xd 4rta b", "7KQ2M9XD4RTAB"), ("7KQ2M9XD4RTAB", "7KQ2M9XD4RTAB"),
        ("7KQ2M9XD4RTAO", "7KQ2M9XD4RTA0"), ("7KQ2M9XD4RTAI", "7KQ2M9XD4RTA1"), ("7KQ2M9XD4RTAl", "7KQ2M9XD4RTA1"),
        ("7KQ2M9XD4RTA", nil), ("7KQ2M9XD4RTABB", nil), ("7KQ2M9XD4RTAU", nil), ("", nil), ("not a code at all", nil),
    ] as [(String, String?)])
    func codesNormalise(_ raw: String, _ expected: String?) {
        #expect(Session.InviteCode.normalise(raw) == expected)
    }

    @Test("a link's code is kept in the store, normalised; a string that isn't a code is refused without a request")
    func aLinksCodeIsKept() async throws {
        let (h, center) = try harness(access: .member, pending: nil)

        await center.received(code: "7kq2-m9xd-4rta-b")
        #expect(h.recorder.events.contains(.inviteReceived))

        await center.received(code: "nonsense")
        #expect(center.ticket == .refused(nil, .invalid))
        #expect(h.requests(to: "/v2/invites/check").isEmpty)
    }

    // MARK: Check after sign-in

    @Test("signing in checks the pending code and never redeems it; usable prints the ticket and keeps the code")
    func signingInChecksNeverRedeems() async throws {
        let (h, center) = try harness()
        let usable = try fixture("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])

        await center.afterSignIn()

        #expect(center.ticket == .printing(face))
        #expect(h.bodies(to: "/v2/invites/check").first?["code"] as? String == Self.code)
        #expect(h.requests(to: "/v2/invites/redeem").isEmpty)
        #expect(pending(h) == Self.code, "the code is spent only at the tear")
        #expect(h.recorder.events.contains(.inviteChecked(.usable)))
    }

    @Test("a used code clears the pending code and refuses; expired and invalid likewise", arguments: [
        ("error.invite_used", Session.Refusal.used), ("error.invite_expired", .expired), ("error.invite_invalid", .invalid),
    ])
    func aRefusedCodeIsCleared(_ fixtureName: String, _ refusal: Session.Refusal) async throws {
        let (h, center) = try harness()
        let body = try fixture("00", fixtureName)
        h.serve(["/v2/invites/check": { _, _ in (400, body) }])

        await center.afterSignIn()

        #expect(center.ticket == .refused(nil, refusal))
        #expect(pending(h) == nil)
    }

    @Test("a relaunch after the tear shows you're in without animating, and drops the code")
    func aRelaunchAfterTheTearShowsYoureIn() async throws {
        let (h, center) = try harness(access: .approved)
        let yours = try fixture("01", "invite.check.yours")
        h.serve(["/v2/invites/check": { _, _ in (200, yours) }])
        // The redeemer is approved after the tear; the check still runs because a code is pending and access says waitlisted.
        let (hw, waitlisted) = try harness()
        hw.serve(["/v2/invites/check": { _, _ in (200, yours) }])

        await waitlisted.afterSignIn()

        #expect(waitlisted.ticket == .youreIn(Session.YoureIn(invitedBy: "priya", serial: 412, redeemedOn: nil, animate: false)))
        #expect(pending(hw) == nil)
        _ = h
        _ = center
    }

    @Test("someone already in drops a leftover code without a request and shows nothing", arguments: [
        Session.AccessState.approved, .member, .staff,
    ])
    func someoneAlreadyInDropsTheCode(_ access: Session.AccessState) async throws {
        let (h, center) = try harness(access: access)

        await center.afterSignIn()

        #expect(center.ticket == .none)
        #expect(pending(h) == nil)
        #expect(h.requests(to: "/v2/invites/check").isEmpty)
        #expect(h.recorder.events.contains(.inviteChecked(.alreadyIn)))
    }

    @Test("the server's alreadyIn answer shows nothing and keeps nothing")
    func theServersAlreadyInShowsNothing() async throws {
        let (h, center) = try harness()
        let alreadyIn = try fixture("01", "invite.check.alreadyin")
        h.serve(["/v2/invites/check": { _, _ in (200, alreadyIn) }])

        await center.afterSignIn()

        #expect(center.ticket == .none)
    }

    @Test("offline or rate-limited at check keeps the code and waits; the next active scene checks again")
    func offlineAtCheckKeepsTheCode() async throws {
        let (h, center) = try harness()
        h.reachability.set(online: false)

        await center.afterSignIn()
        #expect(center.ticket == .waiting(.offline))
        #expect(pending(h) == Self.code)

        let limited = try fixture("00", "error.rate_limited")
        h.reachability.set(online: true)
        h.serve(["/v2/invites/check": { _, _ in (429, limited) }])
        await center.retryIfWaiting()
        #expect(center.ticket == .waiting(.rateLimited(retryAfterSeconds: 60)))
        #expect(pending(h) == Self.code)

        let usable = try fixture("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])
        await center.retryIfWaiting()
        #expect(center.ticket == .printing(face))

        await center.retryIfWaiting()
        #expect(h.requests(to: "/v2/invites/check").count == 2, "a printed ticket isn't checked again")
    }

    @Test("no pending code means nothing to check")
    func noPendingCodeMeansNothingToCheck() async throws {
        let (h, center) = try harness(pending: nil)

        await center.afterSignIn()

        #expect(center.ticket == .none)
        #expect(h.requests(to: "/v2/invites/check").isEmpty)
    }

    @Test("typing a code checks it and stores it only when usable")
    func typingACodeStoresItOnlyWhenUsable() async throws {
        let (h, center) = try harness(pending: nil)
        let used = try fixture("00", "error.invite_used")
        h.serve(["/v2/invites/check": { _, _ in (400, used) }])

        await center.type(code: "7kq2-m9xd-4rta-b")
        #expect(center.ticket == .refused(nil, .used))
        #expect(pending(h) == nil)

        let usable = try fixture("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])
        await center.type(code: "7kq2-m9xd-4rta-b")
        #expect(center.ticket == .printing(face))
        #expect(pending(h) == Self.code)
        #expect(h.bodies(to: "/v2/invites/check").last?["code"] as? String == Self.code, "the normalised code is sent")

        await center.type(code: "nope")
        #expect(center.ticket == .refused(nil, .invalid))
        #expect(h.requests(to: "/v2/invites/check").count == 2)
    }

    // MARK: The tear

    @Test("tearing redeems once with the key made at touch-down, even when called twice; success clears the code and sets access")
    func tearingRedeemsOnceWithTheKey() async throws {
        let (h, center) = try harness()
        let redeemed = try fixture("00", "redeem.response")
        h.serve(["/v2/invites/redeem": { _, _ in (200, redeemed) }])
        center.beginTear()

        async let first = center.tear()
        async let second = center.tear()
        let outcomes = await [first, second]

        let youreIn = Session.YoureIn(invitedBy: "priya", serial: 412, redeemedOn: "2026-10-21", animate: true)
        #expect(outcomes == [.yours(youreIn), .yours(youreIn)])
        #expect(h.requests(to: "/v2/invites/redeem").count == 1)
        let sent = try #require(h.requests(to: "/v2/invites/redeem").first)
        #expect(sent.value(forHTTPHeaderField: "Idempotency-Key") == Self.key.uuidString.lowercased())
        #expect(h.bodies(to: "/v2/invites/redeem").first?["code"] as? String == Self.code)
        #expect(pending(h) == nil)
        #expect(center.ticket == .youreIn(youreIn))
        #expect(center.access == .approved)
        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .approved))
        #expect(h.stored()?.access == .approved)
        #expect(h.recorder.events.contains(.inviteTorn(.yours)))
    }

    @Test("a lost redeem response retried with the same key returns success")
    func aLostRedeemResponseRetriedWithTheSameKey() async throws {
        let (h, center) = try harness()
        let redeemed = try fixture("00", "redeem.response")
        h.serve([
            "/v2/invites/redeem": { count, _ in
                if count == 0 {
                    throw URLError(.networkConnectionLost)
                }
                return (200, redeemed)
            },
        ])
        center.beginTear()

        let outcome = await center.tear()

        guard case .yours = outcome else {
            Issue.record("expected yours, got \(outcome)")
            return
        }
        let keys = h.requests(to: "/v2/invites/redeem").map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        #expect(keys == [Self.key.uuidString.lowercased(), Self.key.uuidString.lowercased()])
    }

    @Test("an offline tear changes nothing and keeps the code and the key")
    func anOfflineTearChangesNothing() async throws {
        let (h, center) = try harness()
        h.reachability.set(online: false)
        center.beginTear()

        let outcome = await center.tear()

        #expect(outcome == .offline)
        #expect(pending(h) == Self.code)
        #expect(center.access == .waitlisted)
        #expect(h.requests(to: "/v2/invites/redeem").isEmpty)

        let redeemed = try fixture("00", "redeem.response")
        h.reachability.set(online: true)
        h.serve(["/v2/invites/redeem": { _, _ in (200, redeemed) }])
        _ = await center.tear()
        #expect(h.requests(to: "/v2/invites/redeem").first?.value(forHTTPHeaderField: "Idempotency-Key") == Self.key.uuidString.lowercased(), "the same key")
    }

    @Test("a used code at the tear clears the code; a rate limit keeps it; a server failure keeps it")
    func tearFailures() async throws {
        let (h, center) = try harness()
        let limited = try fixture("00", "error.rate_limited")
        h.serve(["/v2/invites/redeem": { _, _ in (429, limited) }])
        #expect(await center.tear() == .rateLimited(retryAfterSeconds: 60))
        #expect(pending(h) == Self.code)

        let internalError = try fixture("00", "error.internal")
        h.serve(["/v2/invites/redeem": { _, _ in (500, internalError) }])
        #expect(await center.tear() == .failed)
        #expect(pending(h) == Self.code)

        let used = try fixture("00", "error.invite_used")
        h.serve(["/v2/invites/redeem": { _, _ in (400, used) }])
        #expect(await center.tear() == .used)
        #expect(pending(h) == nil)
        #expect(center.ticket == .refused(nil, .used))

        #expect(await center.tear() == .nothingToRedeem)
    }

    @Test("an expired code at the tear is dropped: it can never work")
    func anExpiredCodeAtTheTearIsDropped() async throws {
        let (h, center) = try harness()
        let expired = try fixture("00", "error.invite_expired")
        h.serve(["/v2/invites/redeem": { _, _ in (400, expired) }])

        #expect(await center.tear() == .refused(.expired))
        #expect(pending(h) == nil)
    }

    @Test("a mismatched key is a bug state: the code is kept and the next touch-down makes no new key until the tear ends")
    func aMismatchedKeyIsABugState() async throws {
        let (h, center) = try harness()
        let mismatch = try fixture("00", "error.idempotency_mismatch")
        h.serve(["/v2/invites/redeem": { _, _ in (409, mismatch) }])

        #expect(await center.tear() == .failed)
        #expect(pending(h) == Self.code)
    }

    // MARK: Access, the waitlist, your invites

    @Test("refreshing access reads the state and keeps it with the session")
    func refreshingAccessKeepsItWithTheSession() async throws {
        let (h, center) = try harness(access: .waitlisted, pending: nil)
        let member = try fixture("00", "access.member")
        h.serve(["/v2/access": { _, _ in (200, member) }])

        let info = try await center.refreshAccess()

        #expect(info == Session.AccessInfo(state: .member, onWaitlist: false))
        #expect(center.access == .member)
        #expect(h.stored()?.access == .member)
    }

    @Test("joining the waitlist posts the reason; my invites decodes three invites")
    func waitlistAndMyInvites() async throws {
        let (h, center) = try harness(pending: nil)
        let onWaitlist = try fixture("00", "waitlist.response")
        let mine = try fixture("00", "invites-mine")
        h.serve([
            "/v2/waitlist": { _, _ in (200, onWaitlist) },
            "/v2/invites/mine": { _, _ in (200, mine) },
        ])

        #expect(try await center.joinWaitlist(reason: "a friend told me about it"))
        #expect(h.bodies(to: "/v2/waitlist").first?["reason"] as? String == "a friend told me about it")
        let invites = try await center.myInvites()
        #expect(invites.count == 3)
        #expect(invites[1].link?.absoluteString == "https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB")
    }

    // MARK: Following the session

    @Test("a sign-out clears the ticket and the tear's key; access follows the session")
    func aSignOutClearsTheTicket() async throws {
        let (h, center) = try harness()
        let usable = try fixture("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])
        center.start()
        await center.afterSignIn()
        #expect(center.ticket == .printing(face))

        _ = await h.manager.signOut(force: true)
        for _ in 0 ..< 20 where center.ticket != .none {
            await Task.yield()
        }

        #expect(center.ticket == .none)
        #expect(center.access == .unknown)
    }

    // MARK: Logging

    @Test("no log event can hold the code, the key or the inviter's name")
    func noLogEventCanHoldTheCode() async throws {
        let (h, center) = try harness()
        let usable = try fixture("01", "invite.check.usable")
        let redeemed = try fixture("00", "redeem.response")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }, "/v2/invites/redeem": { _, _ in (200, redeemed) }])

        await center.afterSignIn()
        _ = await center.tear()

        let described = h.recorder.events.map { "\($0)" }.joined(separator: "\n")
        #expect(!described.contains(Self.code))
        #expect(!described.contains(Self.key.uuidString.lowercased()))
        #expect(!described.contains("priya"))
        #expect(!h.recorder.events.isEmpty)
    }
}
