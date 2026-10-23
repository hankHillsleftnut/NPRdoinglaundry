import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// APP-ROOT: the joins the root depends on.
@MainActor
struct AppRootWiringTests {
    @Test("the pending code is unread until asked, then follows the Keychain")
    func pendingInviteFollowsTheKeychain() async {
        let slot = Platform.Box<String?>(nil)
        let pending = Platform.PendingInvite(read: { slot.value })
        #expect(pending.hasCode == nil)
        await pending.refresh()
        #expect(pending.hasCode == false)
        slot.value = "7kq2m9xd4rtab"
        await pending.refresh()
        #expect(pending.hasCode == true)
        #expect(await pending.code() == "7kq2m9xd4rtab")
        slot.value = nil
        await pending.refresh()
        #expect(pending.hasCode == false)
    }

    @Test("a store that cannot be opened is reported, and a retry opens it")
    func storeFailureThenRetry() async throws {
        let allowed = Platform.Box(false)
        let env = Platform.AppEnvironment.preview(openDatabase: {
            guard allowed.value else { throw CocoaError(.fileWriteUnknown) }
            return try Store.LocalDatabase.inMemory(ownerUserID: $0)
        })
        try await env.session.install(Session.Credentials(
            accessToken: "invented.access", accessTokenExpiresAt: Date().addingTimeInterval(900),
            refreshToken: "invented-refresh", userID: "user-a", access: .member
        ))
        env.followSessionState()
        env.startSession()
        for _ in 0 ..< 500 where !env.storeOpenFailed {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(env.storeOpenFailed)
        #expect(env.journalData == nil)
        allowed.value = true
        await env.retryOpeningStore()?.value
        #expect(!env.storeOpenFailed)
        #expect(env.journalData != nil)
    }

    @Test("sign-in outcomes reach the screens in their words; a dismissed sheet and a double tap show nothing")
    func signInResults() {
        let outcome = Session.SignInOutcome(userID: "u", firstName: "sam", isNew: true, access: .waitlisted)
        #expect(LiveSignIn.result(of: .signedIn(outcome)) == .signedIn(firstName: "sam", access: .waitlisted))
        #expect(LiveSignIn.result(of: .cancelled) == .cancelled)
        #expect(LiveSignIn.result(of: .alreadyRunning) == .cancelled)
        #expect(LiveSignIn.result(of: .failed(Flows.Failure(.unknown))) == .failed)
    }

    @Test("a gate mounted for a signed-in person checks the waiting code at once")
    func startSignedInChecksTheCode() async {
        let source = ScriptedInviteSource()
        source.afterSignIn = .printing(SampleInvite.face)
        let model = InviteModel(phase: .typed, source: source, signIn: source)
        await model.startSignedIn(access: .waitlisted)
        #expect(model.phase == .printing)
        // a page that is past the typed ticket does not check again
        await model.startSignedIn(access: .waitlisted)
        #expect(model.phase == .printing)
    }

    @Test("a suspended person's gate does not check a code")
    func startSignedInIgnoresSuspended() async {
        let source = ScriptedInviteSource()
        let model = InviteModel(phase: .typed, source: source, signIn: source)
        await model.startSignedIn(access: .suspended)
        #expect(model.phase == .typed)
    }
}
