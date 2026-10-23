import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// The sign-in through the real pieces: `Session.AppleSignIn` -> `/v2/auth/apple` (a stub transport serving the
/// contract fixtures) -> the real `Session.Manager` (memory Keychain). Fails if `install` is not called, the nonce
/// does not match, or the request carries anything the contract does not list.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SignInRealSeamTests {
    /// Real Apple half; the sheet's result is replaced by an invented credential (Apple's sheet cannot run here).
    @MainActor
    private final class Adapter: Session.AppleSigningIn {
        let apple: Session.AppleSignIn
        let credential: Session.AppleCredential

        init(apple: Session.AppleSignIn, credential: Session.AppleCredential) {
            self.apple = apple
            self.credential = credential
        }

        func prepare(_ request: ASAuthorizationAppleIDRequest) { apple.prepare(request) }

        func complete(_: Result<ASAuthorization, any Error>) async throws -> Session.SignInOutcome {
            try await apple.signIn(with: credential)
        }
    }

    private struct SheetClosed: Error {}

    private let raw = "aW52ZW50ZWQtbm9uY2UtMzItYnl0ZXMtYmFzZTY0dXJs"
    private let credential = Session.AppleCredential(
        user: "001234.invented.5678", identityToken: "invented.identity.token", authorizationCode: "invented-code",
        givenName: "sam", familyName: nil, email: nil
    )

    private func make(_ h: SessionHarness) -> Session.SignInCoordinator {
        let raw = raw
        let apple = Session.AppleSignIn(client: h.client, installer: h.manager, log: h.recorder, keeper: h.store) { Session.Nonce(raw: raw) }
        return Session.SignInCoordinator(apple: Adapter(apple: apple, credential: credential), log: h.recorder)
    }

    @Test("signing in installs the session: signed in, the token usable, the Keychain item saved, the request exactly the contract's")
    func signInInstallsTheSession() async throws {
        let h = try SessionHarness(stored: nil)
        let answer = try Fixtures.data("00", "auth.response")
        h.serve(["/v2/auth/apple": { _, _ in (200, answer) }])
        let coordinator = make(h)
        coordinator.prepare(ASAuthorizationAppleIDProvider().createRequest())

        let done = await coordinator.complete(.failure(SheetClosed()))

        guard case let .signedIn(outcome) = done else {
            Issue.record("expected signed in, got \(done)")
            return
        }
        #expect(outcome.userID == "00000000-0000-4000-8000-000000000001")
        #expect(await h.manager.state == .signedIn(userID: outcome.userID, access: .member))
        #expect(try await h.manager.accessToken() == "invented.access.token")
        #expect(h.stored()?.refreshToken == "invented-refresh-token", "saved to the Keychain")
        let request = try #require(h.requests(to: "/v2/auth/apple").first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "a public door: no token")
        let body = try #require(h.bodies(to: "/v2/auth/apple").first)
        #expect(body["rawNonce"] as? String == raw)
        #expect(Set(body.keys) == ["identityToken", "authorizationCode", "rawNonce", "fullName", "email"], "exactly the contract's keys")
        #expect(body["identityToken"] as? String == "invented.identity.token" && body["authorizationCode"] as? String == "invented-code")
        #expect(h.requests(to: "/auth/signin").isEmpty && h.requests(to: "/v2/auth/apple").count == 1)
    }

    @Test("a waitlisted person signs in fine: the access state is waitlisted, not a failure")
    func waitlistedSignsIn() async throws {
        let h = try SessionHarness(stored: nil)
        let answer = try Fixtures.data("00", "auth.response.waitlisted")
        h.serve(["/v2/auth/apple": { _, _ in (200, answer) }])
        let coordinator = make(h)
        coordinator.prepare(ASAuthorizationAppleIDProvider().createRequest())

        _ = await coordinator.complete(.failure(SheetClosed()))

        #expect(coordinator.phase == .idle)
        #expect(coordinator.outcome?.access == .waitlisted)
        if case .signedIn(_, .waitlisted) = await h.manager.state {} else {
            Issue.record("expected signedIn waitlisted")
        }
    }

    @Test("a server refusal leaves the session signed out and says why; the next tap starts clean")
    func refusalLeavesSignedOut() async throws {
        let h = try SessionHarness(stored: nil)
        let refused = try Fixtures.data("00", "error.unauthenticated")
        let good = try Fixtures.data("00", "auth.response")
        h.serve(["/v2/auth/apple": { count, _ in count == 0 ? (401, refused) : (200, good) }])
        let coordinator = make(h)
        coordinator.prepare(ASAuthorizationAppleIDProvider().createRequest())

        _ = await coordinator.complete(.failure(SheetClosed()))
        if case .failed = coordinator.phase {} else {
            Issue.record("expected a failure")
        }
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
        #expect(h.stored() == nil)

        coordinator.prepare(ASAuthorizationAppleIDProvider().createRequest())
        let again = await coordinator.complete(.failure(SheetClosed()))
        if case .signedIn = again {} else {
            Issue.record("second tap should sign in")
        }
    }

    @Test("a Keychain that refuses the save: failed with an unlock message, signed out, nothing mirrored")
    func keychainRefusesTheSave() async throws {
        let h = try SessionHarness(stored: nil)
        let answer = try Fixtures.data("00", "auth.response")
        h.serve(["/v2/auth/apple": { _, _ in (200, answer) }])
        _ = await h.manager.state // read once before the Keychain starts refusing
        h.keychain.failEveryCall(with: errSecInteractionNotAllowed)
        let coordinator = make(h)
        coordinator.prepare(ASAuthorizationAppleIDProvider().createRequest())

        _ = await coordinator.complete(.failure(SheetClosed()))

        if case let .failed(failure) = coordinator.phase {
            #expect(failure.message?.contains("unlock") == true)
        } else {
            Issue.record("expected failed")
        }
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
        #expect(h.mirror().isEmpty)
    }

    @Test("the name and email Apple sends once survive a failed first call and go out with the retry")
    func firstAuthorizationSurvivesAFailure() async throws {
        let h = try SessionHarness(stored: nil)
        let good = try Fixtures.data("00", "auth.response")
        let down = try Fixtures.data("00", "error.internal")
        h.serve(["/v2/auth/apple": { count, _ in count == 0 ? (500, down) : (200, good) }])
        let raw = raw
        let apple = Session.AppleSignIn(client: h.client, installer: h.manager, log: h.recorder, keeper: h.store) { Session.Nonce(raw: raw) }
        let first = Session.AppleCredential(
            user: "001234.invented", identityToken: "t1", authorizationCode: "c1", givenName: "sam", familyName: "ng", email: "sam@invented.test"
        )
        let retry = Session.AppleCredential(
            user: "001234.invented", identityToken: "t2", authorizationCode: "c2", givenName: nil, familyName: nil, email: nil
        )

        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())
        await #expect(throws: (any Error).self) { try await apple.signIn(with: first) }
        #expect(await h.store.kept()?.givenName == "sam", "kept on this phone after the failure")

        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())
        _ = try await apple.signIn(with: retry)

        let bodies = h.bodies(to: "/v2/auth/apple")
        let name = bodies.last?["fullName"] as? [String: Any]
        #expect(name?["givenName"] as? String == "sam" && bodies.last?["email"] as? String == "sam@invented.test", "the retry still carries them")
        #expect(await h.store.kept() == nil, "cleared once a call succeeds")
    }

    @Test("if the Keychain can't keep the name and email, the retry in the same run still carries them")
    func memoryFallbackWhenTheKeychainFails() async throws {
        let h = try SessionHarness(stored: nil)
        let good = try Fixtures.data("00", "auth.response")
        let down = try Fixtures.data("00", "error.internal")
        h.serve(["/v2/auth/apple": { count, _ in count == 0 ? (500, down) : (200, good) }])
        let raw = raw
        let apple = Session.AppleSignIn(client: h.client, installer: h.manager, log: h.recorder, keeper: Refusing()) { Session.Nonce(raw: raw) }
        let first = Session.AppleCredential(
            user: "001234.invented", identityToken: "t1", authorizationCode: "c1", givenName: "sam", familyName: nil, email: "sam@invented.test"
        )
        let retry = Session.AppleCredential(
            user: "001234.invented", identityToken: "t2", authorizationCode: "c2", givenName: nil, familyName: nil, email: nil
        )

        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())
        await #expect(throws: (any Error).self) { try await apple.signIn(with: first) }
        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())
        _ = try await apple.signIn(with: retry)

        let name = h.bodies(to: "/v2/auth/apple").last?["fullName"] as? [String: Any]
        #expect(name?["givenName"] as? String == "sam", "carried from memory although the Keychain kept nothing")
    }

    @Test("what was kept for one Apple id is not sent for another")
    func keptDataIsPerAppleID() async throws {
        let h = try SessionHarness(stored: nil)
        await h.store.keep(Session.KeptFirstAuthorization(appleUser: "someone.else", givenName: "kim", familyName: nil, email: nil))
        let good = try Fixtures.data("00", "auth.response")
        h.serve(["/v2/auth/apple": { _, _ in (200, good) }])
        let raw = raw
        let apple = Session.AppleSignIn(client: h.client, installer: h.manager, log: h.recorder, keeper: h.store) { Session.Nonce(raw: raw) }
        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())

        _ = try await apple.signIn(with: Session.AppleCredential(
            user: "001234.invented", identityToken: "t", authorizationCode: "c", givenName: nil, familyName: nil, email: nil
        ))

        let body = try #require(h.bodies(to: "/v2/auth/apple").first)
        #expect(body["fullName"] == nil || body["fullName"] is NSNull)
    }

    @Test(
        "the new root shows the sign-in screen when signed out, 'please sign in again' after the server ended it, nothing while locked or unread, the app when signed in"
    )
    func rootScreens() {
        #expect(NewAppRoot.screen(for: nil) == .blank)
        #expect(NewAppRoot.screen(for: .locked) == .locked, "a locked phone says so in words")
        #expect(NewAppRoot.screen(for: .signedOut(hasSignedInBefore: false, reason: .none)) == .signIn(endedByServer: false))
        #expect(NewAppRoot.screen(for: .signedOut(hasSignedInBefore: true, reason: .signedOut)) == .signIn(endedByServer: false))
        #expect(NewAppRoot.screen(for: .signedOut(hasSignedInBefore: true, reason: .revoked)) == .signIn(endedByServer: true))
        #expect(NewAppRoot.screen(for: .signedIn(userID: "u", access: .waitlisted)) == .app)
    }
}

/// A Keychain that keeps nothing and finds nothing.
private final class Refusing: Session.FirstAuthorizationKeeping, @unchecked Sendable {
    func kept() async -> Session.KeptFirstAuthorization? { nil }
    func keep(_: Session.KeptFirstAuthorization) async {}
    func clear() async {}
}
