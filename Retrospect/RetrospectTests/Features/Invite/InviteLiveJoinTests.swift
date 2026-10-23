import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// PI1 on the REAL `Session.InviteCenter` (stubbed URL session, real client, real store), through
/// `LiveInviteSource`: the join the sample source can't see. The model's tests run on a script;
/// these prove the page and the platform agree on what a typed code does on the wire.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct InviteLiveJoinTests {
    private static let code = "7KQ2M9XD4RTAB"

    @MainActor
    private final class NoSignIn: SignInCoordinating {
        func prepare(_: ASAuthorizationAppleIDRequest) {}
        func complete(_: Result<ASAuthorization, any Error>) async -> SignInResult {
            .cancelled
        }
    }

    /// A waitlisted person, signed in, with no code waiting: the typed ticket.
    private func typedPage() throws -> (SessionHarness, InviteModel) {
        let stored = Session.Credentials(
            accessToken: SessionHarness.signedIn.accessToken, accessTokenExpiresAt: SessionHarness.signedIn.accessTokenExpiresAt,
            refreshToken: SessionHarness.signedIn.refreshToken, userID: SessionHarness.signedIn.userID,
            access: .waitlisted, firstName: "sam", provider: .apple, appleUserID: "001234.invented"
        )
        let h = try SessionHarness(stored: stored)
        let center = Session.InviteCenter(store: h.store, client: h.client, session: h.manager, log: h.recorder, makeKey: { UUID() })
        let source = LiveInviteSource(center: center, onBegin: {})
        let model = InviteModel(phase: .typed, source: source, signIn: NoSignIn(), sleep: { _ in })
        return (h, model)
    }

    @Test("a typed code is checked once on the real door, normalised, and a usable answer is ready with the inviter's face")
    func typedUsable() async throws {
        let (h, model) = try typedPage()
        let usable = try Fixtures.data("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])

        model.setCode("7kq2-m9xd-4rta-b") // the 13th character starts the check
        await model.submitTyped() // joins the one already running
        #expect(model.phase == .ready)
        #expect(model.face?.from == "priya")
        #expect(h.requests(to: "/v2/invites/check").count == 1, "one check, not one per path into it")
        #expect(h.bodies(to: "/v2/invites/check").first?["code"] as? String == Self.code)
        #expect(h.requests(to: "/v2/invites/redeem").isEmpty, "typing never spends the code")
    }

    @Test("a code the server calls invalid shakes and clears the tiles; nothing is spent")
    func typedInvalid() async throws {
        let (h, model) = try typedPage()
        let invalid = try Fixtures.data("00", "error.invite_invalid")
        h.serve(["/v2/invites/check": { _, _ in (400, invalid) }])

        model.setCode(Self.code)
        await model.submitTyped()
        #expect(model.phase == .typed)
        #expect(model.notice == .wrongCode)
        #expect(model.wrongCodes == 1)
        #expect(model.tiles.isEmpty)
        #expect(h.requests(to: "/v2/invites/check").count == 1)
    }

    @Test("a used code from the real door refuses the ticket with the waitlist offered")
    func typedUsed() async throws {
        let (h, model) = try typedPage()
        let used = try Fixtures.data("00", "error.invite_used")
        h.serve(["/v2/invites/check": { _, _ in (400, used) }])

        model.setCode(Self.code)
        await model.submitTyped()
        #expect(model.phase == .refused(.used))
        #expect(model.offersWaitlist)
    }

    @Test("typed while offline keeps the 13 characters and sends them once when the connection returns")
    func typedOfflineThenOnline() async throws {
        let (h, model) = try typedPage()
        h.reachability.set(online: false)
        let usable = try Fixtures.data("01", "invite.check.usable")
        h.serve(["/v2/invites/check": { _, _ in (200, usable) }])

        model.setCode(Self.code)
        await model.submitTyped()
        #expect(model.phase == .typed)
        #expect(model.notice == .typeOffline)
        #expect(model.tiles == Self.code, "the person's characters stay on the tiles")
        #expect(h.requests(to: "/v2/invites/check").isEmpty, "offline sends nothing")

        h.reachability.set(online: true)
        await model.connection(true)
        #expect(model.phase == .ready)
        #expect(h.requests(to: "/v2/invites/check").count == 1)
    }
}

/// VoiceOver hears every failure in the words the page shows (checklist 2), and nothing at rest.
@MainActor
struct InviteSpokenFailureTests {
    @Test("each failure or refusal is spoken in the page's own words; rest states say nothing", arguments: [
        (InviteScenario.typedWrong, true), (.used, true), (.expired, true), (.offline, true), (.signInFailed, true),
        (.rateLimited, true), (.promise, false), (.typed, false), (.waitlisted, false), (.suspended, false),
    ] as [(InviteScenario, Bool)])
    func spoken(_ scenario: InviteScenario, _ speaks: Bool) {
        let model = InviteModel.sample(scenario)
        if speaks {
            let shown = model.phase == .promise || model.isRefusedOrWaiting && model.caption == nil ? model.promiseLine : model.caption
            #expect(model.spokenFailure != nil)
            #expect(model.spokenFailure == shown)
        } else {
            #expect(model.spokenFailure == nil)
        }
    }
}
