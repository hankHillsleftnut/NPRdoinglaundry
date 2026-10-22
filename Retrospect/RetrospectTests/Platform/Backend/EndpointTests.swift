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

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") })
    }
}
