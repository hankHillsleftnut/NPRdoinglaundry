import Foundation
@testable import Retrospect
import Testing

/// A request made with one person's token must never be answered with the next person's.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionCrossAccountTests {
    private static let other = Session.Credentials(
        accessToken: "other.access.token", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500),
        refreshToken: "other-refresh", userID: "00000000-0000-4000-8000-000000000002", access: .member
    )

    private func rejected(_ h: SessionHarness, failedToken: String) async -> Bool {
        do {
            _ = try await h.manager.refreshAfterUnauthorized(failedToken: failedToken)
            return false
        } catch let failure as Backend.Failure {
            return failure.kind == .unauthenticated
        } catch {
            return false
        }
    }

    @Test("after sign-out and another person's sign-in, a 401 on the first person's request is not replayed with the second's token")
    func signOutThenAnotherPerson() async throws {
        let h = try SessionHarness()
        let first = try await h.manager.accessToken()
        _ = await h.manager.signOut(force: true)
        try await h.manager.install(Self.other)

        #expect(await rejected(h, failedToken: first))
    }

    @Test("a different person signing in over the first (no sign-out between) also retires the first's token")
    func replacedByAnotherPerson() async throws {
        let h = try SessionHarness()
        let first = try await h.manager.accessToken()
        try await h.manager.install(Self.other)

        #expect(await rejected(h, failedToken: first))
    }

    @Test("an access state set for one person never lands on another (FR.b1.data: a late complete receipt)")
    func accessForOnePersonNeverLandsOnAnother() async throws {
        let h = try SessionHarness()
        try await h.manager.install(Self.other)

        await h.manager.setAccess(.staff, for: SessionHarness.signedIn.userID)
        #expect(await h.manager.state == .signedIn(userID: Self.other.userID, access: .member), "the first person's receipt changed nothing")

        await h.manager.setAccess(.staff, for: Self.other.userID)
        #expect(await h.manager.state == .signedIn(userID: Self.other.userID, access: .staff))
    }

    @Test("the same person's older token still gets the stored one: a refresh by someone else in flight is honoured")
    func samePersonKeepsWorking() async throws {
        let h = try SessionHarness()
        let first = try await h.manager.accessToken()
        let renewed = Session.Credentials(
            accessToken: "renewed.access", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_571_500),
            refreshToken: "renewed-refresh", userID: SessionHarness.signedIn.userID, access: .member
        )
        try await h.manager.install(renewed)

        #expect(try await h.manager.refreshAfterUnauthorized(failedToken: first) == "renewed.access")
    }
}
