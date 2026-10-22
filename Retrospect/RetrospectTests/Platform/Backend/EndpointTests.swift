import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct EndpointTests {
    @Test("meta is a public GET with no body, no key and the default timeout")
    func metaIsAPublicGet() {
        let meta = Backend.Endpoints.Meta()

        #expect(meta.method == .get)
        #expect(meta.path == .meta)
        #expect(meta.path.rawValue == "/v2/meta")
        #expect(!meta.requiresAuth)
        #expect(meta.body == nil)
        #expect(meta.idempotencyKey == nil)
        #expect(meta.pathParameters.isEmpty)
        #expect(meta.query.isEmpty)
        #expect(meta.timeout == .seconds(20))
    }

    @Test("the auth doors: apple and refresh are public POSTs, signout needs the token; refresh and signout wait ten seconds")
    func theAuthDoors() {
        let apple = Backend.Endpoints.AppleSignIn(.init(identityToken: "t", authorizationCode: "c", rawNonce: "n", firstAuthorization: nil))
        let refresh = Backend.Endpoints.Refresh(refreshToken: "r")
        let signOut = Backend.Endpoints.SignOut(refreshToken: "r")

        #expect(apple.method == .post && apple.path.rawValue == "/v2/auth/apple" && !apple.requiresAuth)
        #expect(refresh.method == .post && refresh.path.rawValue == "/v2/auth/refresh" && !refresh.requiresAuth)
        #expect(signOut.method == .post && signOut.path.rawValue == "/v2/auth/signout" && signOut.requiresAuth)
        #expect(refresh.timeout == .seconds(10))
        #expect(signOut.timeout == .seconds(10))
        #expect(refresh.body == Backend.RefreshTokenBody(refreshToken: "r"))
        #expect(signOut.body == Backend.RefreshTokenBody(refreshToken: "r"))
        #expect([apple.idempotencyKey, refresh.idempotencyKey, signOut.idempotencyKey].allSatisfy { $0 == nil }, "sign-in and refresh are sent once")
    }

    @Test("the invite doors: check and redeem are authenticated POSTs with the code; only redeem carries the tear's key")
    func theInviteDoors() {
        let key = UUID()
        let check = Backend.Endpoints.InviteCheck(code: "7KQ2M9XD4RTAB")
        let redeem = Backend.Endpoints.InviteRedeem(code: "7KQ2M9XD4RTAB", key: key)

        #expect(check.method == .post && check.path.rawValue == "/v2/invites/check" && check.requiresAuth)
        #expect(check.idempotencyKey == nil, "a check is sent once and spends nothing")
        #expect(redeem.method == .post && redeem.path.rawValue == "/v2/invites/redeem" && redeem.requiresAuth)
        #expect(redeem.idempotencyKey == key)
        #expect(redeem.body == Backend.InviteCodeBody(code: "7KQ2M9XD4RTAB"))
        #expect(Backend.Endpoints.Access().path.rawValue == "/v2/access")
        #expect(Backend.Endpoints.JoinWaitlist(reason: nil).body == Backend.WaitlistBody(reason: nil))
        #expect(Backend.Endpoints.InvitesMine().method == .get)
    }

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") })
    }
}
