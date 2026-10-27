import AuthenticationServices
@testable import Retrospect
import Testing

/// AC1.link: welcome back's "new here? get started" (Paper AC-1 `1GY6-0`) opens the splash (founder, 27 Oct).
@MainActor
struct SignInNewHereTests {
    @Test("welcome back draws the link where the splash has its legal line; the splash has no link")
    func drawnOnWelcomeBackOnly() {
        #expect(SignInModel.newHere == "new here? get started")
        #expect(SignInScreen(model: SignInModel.sample(.returning)).newHereAction != nil)
        #expect(SignInScreen(model: SignInModel.sample(.restoreFailed)).newHereAction != nil)
        #expect(SignInScreen(model: SignInModel.sample(.splash)).newHereAction == nil)
        #expect(SignInModel.sample(.splash).offersNewHere == false)
    }

    @Test("tapping the link turns welcome back into the splash: its title, line and legal line")
    func linkOpensTheSplash() {
        let model = SignInModel.sample(.returning)
        let screen = SignInScreen(model: model)
        screen.newHereAction?()
        #expect(model.look == .splash)
        #expect(model.title == SignInModel.splashTitle)
        #expect(model.restLine == SignInModel.splashLine)
        #expect(model.offersNewHere == false) // the splash shows the legal line, not the link
        #expect(screen.newHereAction == nil)
    }

    @Test("after a failed welcome-back try, the link opens a clean splash: the failure goes, the buttons rest")
    func failureClears() {
        let model = SignInModel.sample(.restoreFailed)
        #expect(model.failure != nil)
        model.startFresh()
        #expect(model.look == .splash)
        #expect(model.phase == .rest)
        #expect(model.failure == nil)
        #expect(model.buttons == .rest)
    }

    @Test("while Apple's answer is being checked the link holds still")
    func heldWhileRestoring() {
        let model = SignInModel.sample(.restoring)
        #expect(model.newHereEnabled == false)
        model.startFresh()
        #expect(model.look == .returning)
        #expect(model.phase == .signingIn)
    }

    @Test("offline, the link still opens the splash, and the splash stays offline")
    func offlineKept() {
        let model = SignInModel.sample(.returning)
        model.setOnline(false)
        model.startFresh()
        #expect(model.look == .splash)
        #expect(model.buttons == .disabled(reason: SignInModel.offlineReason))
    }

    @Test("the splash opened from welcome back signs in like the first-run splash")
    func splashSignsIn() async {
        let model = SignInModel(look: .returning, coordinator: SampleSignIn(script: [.signedIn(firstName: "sam", access: .waitlisted)], sleep: { _ in }))
        var handed: [String?] = []
        model.onSignedIn = { name, _ in handed.append(name) }
        model.startFresh()
        await model.appleFinished(.failure(SampleTapError()))
        #expect(handed == ["sam"])
    }
}

private struct SampleTapError: Error {}
