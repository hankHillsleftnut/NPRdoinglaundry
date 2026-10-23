import AuthenticationServices
@testable import Retrospect
import Testing

@MainActor
private final class ScriptedCoordinator: SignInCoordinating {
    var result: SignInResult = .signedIn(firstName: "sam", access: .waitlisted)
    private(set) var completions = 0
    var delay: Duration = .zero

    func prepare(_: ASAuthorizationAppleIDRequest) {}
    func complete(_: Result<ASAuthorization, any Error>) async -> SignInResult {
        completions += 1
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }
}

private struct Stub: Error {}

/// PI0: the sign-in page's state (splash and welcome back), and what it says.
@MainActor
struct SignInModelTests {
    @Test("a successful sign-in hands on with the name and where the person stands, once")
    func success() async {
        let coordinator = ScriptedCoordinator()
        let model = SignInModel(look: .splash, coordinator: coordinator)
        var handed: [(String?, Session.AccessState)] = []
        model.onSignedIn = { handed.append(($0, $1)) }
        await model.appleFinished(.failure(Stub()))
        #expect(handed.count == 1)
        #expect(handed.first?.0 == "sam")
        #expect(handed.first?.1 == .waitlisted)
        #expect(model.arrivals == 1)
    }

    @Test("a dismissed sheet changes nothing and says nothing")
    func cancelled() async {
        let coordinator = ScriptedCoordinator()
        coordinator.result = .cancelled
        let model = SignInModel(look: .splash, coordinator: coordinator)
        var handed = 0
        model.onSignedIn = { _, _ in handed += 1 }
        await model.appleFinished(.failure(Stub()))
        #expect(model.phase == .rest)
        #expect(model.failure == nil)
        #expect(model.failures == 0)
        #expect(handed == 0)
    }

    @Test("a failed sign-in keeps the button, says nothing is lost, and the next try works")
    func failed() async {
        let coordinator = ScriptedCoordinator()
        coordinator.result = .failed
        let model = SignInModel(look: .splash, coordinator: coordinator)
        await model.appleFinished(.failure(Stub()))
        #expect(model.phase == .failed)
        #expect(model.failure == "that didn't work. nothing is lost; try again.")
        #expect(model.buttons == .rest)
        #expect(model.failures == 1)
        coordinator.result = .signedIn(firstName: nil, access: .approved)
        var access: Session.AccessState?
        model.onSignedIn = { _, new in access = new }
        await model.appleFinished(.failure(Stub()))
        #expect(access == .approved)
    }

    @Test("welcome back says nothing is lost (Paper AC-1), and restoring names what comes back")
    func returning() {
        let rest = SignInModel(look: .returning, coordinator: ScriptedCoordinator())
        #expect(rest.title == "welcome back.")
        #expect(rest.line == "sign in to pick up where you left off.")
        let restoring = SignInModel(look: .returning, coordinator: ScriptedCoordinator(), phase: .signingIn)
        #expect(restoring.line == "bringing back your entries and episodes…")
        #expect(restoring.buttons == .pending)
        let failed = SignInModel(look: .returning, coordinator: ScriptedCoordinator(), phase: .failed)
        #expect(failed.failure == "that didn't work. nothing is lost; try again.")
    }

    @Test("the splash promises, and the line becomes the wait while signing in")
    func splash() {
        let rest = SignInModel(look: .splash, coordinator: ScriptedCoordinator())
        #expect(rest.title == SignInModel.splashTitle)
        #expect(rest.line == SignInModel.splashLine)
        let signingIn = SignInModel(look: .splash, coordinator: ScriptedCoordinator(), phase: .signingIn)
        #expect(signingIn.line == "signing you in…")
    }

    @Test("offline the button rests disabled with the reason, and comes back with the connection")
    func offline() async {
        let model = SignInModel(look: .splash, coordinator: ScriptedCoordinator(), isOnline: false)
        #expect(model.buttons == .disabled(reason: "connect to sign in"))
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let watching = Task { await model.watch(stream) }
        continuation.yield(true)
        continuation.finish()
        await watching.value
        #expect(model.buttons == .rest)
    }

    @Test("a second Apple result while signing in is ignored")
    func singleFlight() async {
        let coordinator = ScriptedCoordinator()
        coordinator.delay = .milliseconds(100)
        let model = SignInModel(look: .splash, coordinator: coordinator)
        let first = Task { await model.appleFinished(.failure(Stub())) }
        try? await Task.sleep(for: .milliseconds(20))
        await model.appleFinished(.failure(Stub()))
        await first.value
        #expect(coordinator.completions == 1)
    }

    @Test("every scenario builds, and the launcher lists them")
    func scenarios() {
        for scenario in SignInScenario.allCases {
            let model = SignInModel.sample(scenario)
            #expect(model.look == scenario.look)
        }
        #expect(SignInModel.sample(.offline).isOnline == false)
        #expect(ScreenRegistry.screen("PI0")?.states.count == SignInScenario.allCases.count)
    }

    @Test("while signing in the button is disabled and looks it: Paper's opacity.disabled, not the lighter pending")
    func pendingLooksDisabled() {
        let model = SignInModel(look: .splash, coordinator: ScriptedCoordinator(), phase: .signingIn)
        #expect(model.buttons == .pending)
        #expect(RSignInButtons.opacity(.pending) == RNumber.opacityDisabled)
        #expect(RSignInButtons.opacity(.disabled(reason: SignInModel.offlineReason)) == RNumber.opacityDisabled)
        #expect(RSignInButtons.opacity(.rest) == 1)
    }

    @Test("the wait and the rest line are both known up front, so the page can hold room for the taller")
    func lineSlot() {
        for look in [SignInModel.Look.splash, .returning] {
            let rest = SignInModel(look: look, coordinator: ScriptedCoordinator())
            let waiting = SignInModel(look: look, coordinator: ScriptedCoordinator(), phase: .signingIn)
            #expect(rest.line == rest.restLine)
            #expect(waiting.line == waiting.waitLine)
            #expect(rest.restLine == waiting.restLine && rest.waitLine == waiting.waitLine)
        }
    }

    @Test("after a sign-in lands, another Apple result never hands on a second time")
    func handsOnOnce() async {
        let coordinator = ScriptedCoordinator()
        let model = SignInModel(look: .returning, coordinator: coordinator)
        var handed = 0
        model.onSignedIn = { _, _ in handed += 1 }
        await model.appleFinished(.failure(Stub()))
        await model.appleFinished(.failure(Stub()))
        #expect(handed == 1)
        #expect(coordinator.completions == 1)
        #expect(model.buttons == .pending)
    }

    @Test("the launcher reaches every moment: from rest a tap fails, the next try signs in")
    func sampleScript() async {
        let coordinator = SampleSignIn(script: SignInScenario.splash.script, sleep: { _ in })
        let model = SignInModel(look: .splash, coordinator: coordinator)
        var handed = 0
        model.onSignedIn = { _, _ in handed += 1 }
        await model.appleFinished(.failure(Stub()))
        #expect(model.phase == .failed)
        #expect(model.failures == 1)
        await model.appleFinished(.failure(Stub()))
        #expect(handed == 1)
        #expect(SignInScenario.signInFailed.script.count == 1)
    }
}
