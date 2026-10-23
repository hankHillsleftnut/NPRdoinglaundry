import AuthenticationServices
@testable import Retrospect
import Testing

/// A source whose every answer the test chooses, and whose calls it counts.
@MainActor
final class ScriptedInviteSource: InviteSource {
    var signIn: InviteSignIn = .signedIn(firstName: "sam", access: .waitlisted)
    var afterSignIn: Session.Ticket = .printing(SampleInvite.face)
    var typed: Session.Ticket = .printing(SampleInvite.face)
    var tears: [Session.TearOutcome] = [.yours(SampleInvite.youreIn)]
    var tearDelay: Duration = .zero
    var joins = true
    private(set) var tearCalls = 0
    private(set) var tearTouchDowns = 0
    private(set) var begun = 0
    private(set) var typedCodes: [String] = []

    func prepare(_: ASAuthorizationAppleIDRequest) {}
    func complete(_: Result<ASAuthorization, any Error>) async -> InviteSignIn { signIn }
    func ticketAfterSignIn() async -> Session.Ticket { afterSignIn }
    func type(code: String) async -> Session.Ticket {
        typedCodes.append(code)
        return typed
    }

    func beginTear() { tearTouchDowns += 1 }
    func tear() async -> Session.TearOutcome {
        tearCalls += 1
        if tearDelay > .zero {
            try? await Task.sleep(for: tearDelay)
        }
        return tears.isEmpty ? .failed : tears.removeFirst()
    }

    func pendingCode() async -> String? { SampleInvite.code }
    func joinWaitlist(reason _: String?) async -> Bool { joins }
    func begin() { begun += 1 }
}

private struct AppleStub: Error {}

@MainActor
struct InviteModelTests {
    private func model(_ phase: InviteModel.Phase, _ source: ScriptedInviteSource, name: String? = "sam") -> InviteModel {
        InviteModel(
            phase: phase, source: source, preview: SampleInvite.face, face: SampleInvite.face, firstName: name,
            sleep: { _ in }
        )
    }

    // MARK: Sign in

    @Test("sign-in then a usable check prints the ticket with the inviter's face")
    func signInPrints() async {
        let source = ScriptedInviteSource()
        let model = model(.promise, source)
        await model.appleFinished(.failure(AppleStub()))
        #expect(model.phase == .printing)
        #expect(model.face == SampleInvite.face)
        #expect(model.printAnimates)
        #expect(model.printedCode == SampleInvite.code)
    }

    @Test("a cancelled Apple sheet changes nothing and says nothing")
    func cancelled() async {
        let source = ScriptedInviteSource()
        source.signIn = .cancelled
        let model = model(.promise, source)
        await model.appleFinished(.failure(AppleStub()))
        #expect(model.phase == .promise)
        #expect(model.notice == nil)
        #expect(model.warnings == 0)
    }

    @Test("a failed sign-in says so, warns once, and offers the button again")
    func signInFailed() async {
        let source = ScriptedInviteSource()
        source.signIn = .failed
        let model = model(.promise, source)
        await model.appleFinished(.failure(AppleStub()))
        #expect(model.phase == .promise)
        #expect(model.notice == .signInFailed)
        #expect(model.promiseLine == "that didn't work. nothing is lost; try again.")
        #expect(model.warnings == 1)
    }

    @Test("the inviter's name shows only when the preview said it")
    func neutralPromise() {
        let neutral = InviteModel(phase: .promise, source: ScriptedInviteSource(), preview: nil)
        #expect(neutral.promiseTitle == "a place, kept for you.")
        #expect(neutral.promiseLabel == nil)
        let named = model(.promise, ScriptedInviteSource())
        #expect(named.promiseTitle == "priya kept a place for you.")
    }

    @Test("a suspended account sees only the pause")
    func suspended() async {
        let source = ScriptedInviteSource()
        source.signIn = .signedIn(firstName: "sam", access: .suspended)
        let model = model(.promise, source)
        await model.appleFinished(.failure(AppleStub()))
        #expect(model.phase == .suspended)
    }

    @Test("signed in with no code lands on the typed ticket; a member is already in")
    func noCode() async {
        let source = ScriptedInviteSource()
        source.afterSignIn = .none
        let waitlisted = model(.promise, source)
        await waitlisted.appleFinished(.failure(AppleStub()))
        #expect(waitlisted.phase == .typed)
        source.signIn = .signedIn(firstName: nil, access: .member)
        let member = model(.promise, source)
        await member.appleFinished(.failure(AppleStub()))
        #expect(member.phase == .alreadyIn)
    }

    @Test("a check that can't finish waits, and a retry prints")
    func waitsThenPrints() async {
        let source = ScriptedInviteSource()
        source.afterSignIn = .waiting(.offline)
        let model = model(.promise, source)
        await model.appleFinished(.failure(AppleStub()))
        #expect(model.phase == .waiting(.offline))
        #expect(model.promiseLine == "waiting for a connection")
        source.afterSignIn = .printing(SampleInvite.face)
        await model.retry()
        #expect(model.phase == .printing)
    }

    // MARK: Typing

    @Test("the 13th character checks the code once; a usable one is ready with no print")
    func typedUsable() async {
        let source = ScriptedInviteSource()
        let model = model(.typed, source)
        model.setCode("7kq2-m9xd-4rta")
        #expect(source.typedCodes.isEmpty)
        model.setCode("7kq2-m9xd-4rta-b")
        await model.submitTyped()
        #expect(model.phase == .ready)
        #expect(!model.printAnimates)
        #expect(model.tiles == SampleInvite.code)
    }

    @Test("a wrong code shakes, clears the tiles right to left and says so")
    func typedWrong() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(nil, .invalid)
        let model = model(.typed, source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.phase == .typed)
        #expect(model.wrongCodes == 1)
        #expect(model.tiles.isEmpty)
        #expect(model.caption == "that code didn't work. check it, or ask for a new one.")
    }

    @Test("typing again after a wrong code clears the words")
    func typingClearsNotice() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(nil, .invalid)
        let model = model(.typed, source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        model.setCode("7")
        #expect(model.notice == nil)
    }

    @Test("a used code prints with 'already used', no tear, and offers the waitlist")
    func typedUsed() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(SampleInvite.face, .used)
        let model = model(.typed, source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.phase == .refused(.used))
        #expect(model.stubLabel == .used)
        #expect(model.offersWaitlist)
        await model.commitTear()
        #expect(source.tearCalls == 0)
    }

    @Test("rate limited: the field locks and the words say when to try again")
    func rateLimited() async {
        let source = ScriptedInviteSource()
        source.typed = .waiting(.rateLimited(retryAfterSeconds: 60))
        let model = model(.typed, source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.codeLocked)
        #expect(model.caption == "too many tries. try again in a minute.")
        model.setCode("")
        #expect(model.tiles == SampleInvite.code)
    }

    // MARK: The tear

    @Test("nothing is yours until the server says so: sealing is not torn")
    func sealingIsNotTorn() async {
        let source = ScriptedInviteSource()
        source.tearDelay = .milliseconds(200)
        let model = model(.ready, source)
        let tearing = Task { await model.commitTear() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.phase == .sealing)
        #expect(model.rips == 0)
        await tearing.value
        #expect(model.phase == .youreIn)
        #expect(model.rips == 1)
        #expect(model.reveals == 1)
        #expect(model.beginVisible)
    }

    @Test("offline at the tear springs back whole, keeps the code and says nothing was used")
    func tearOffline() async {
        let source = ScriptedInviteSource()
        source.tears = [.offline, .yours(SampleInvite.youreIn)]
        let model = model(.ready, source)
        await model.commitTear()
        #expect(model.phase == .ready)
        #expect(model.caption == "waiting for a connection. nothing was used.")
        #expect(model.warnings == 1)
        #expect(model.printedCode == SampleInvite.code)
        // the next try is the same ticket, and it goes through
        await model.commitTear()
        #expect(source.tearCalls == 2)
        #expect(model.phase == .youreIn)
    }

    @Test("someone else used it meanwhile: the ticket is refused with the waitlist")
    func tearUsed() async {
        let source = ScriptedInviteSource()
        source.tears = [.used]
        let model = model(.ready, source)
        await model.commitTear()
        #expect(model.phase == .refused(.used))
        #expect(model.caption == "someone else used this one just now.")
        #expect(model.offersWaitlist)
    }

    @Test("any other failure keeps the ticket and says it didn't go through")
    func tearFailed() async {
        let source = ScriptedInviteSource()
        source.tears = [.failed]
        let model = model(.ready, source)
        await model.commitTear()
        #expect(model.phase == .ready)
        #expect(model.caption == "that didn't go through. nothing was used; try again.")
    }

    @Test("a second tear while one is sealing does nothing")
    func singleTear() async {
        let source = ScriptedInviteSource()
        source.tearDelay = .milliseconds(100)
        let model = model(.ready, source)
        let first = Task { await model.commitTear() }
        try? await Task.sleep(for: .milliseconds(20))
        await model.commitTear()
        await first.value
        #expect(source.tearCalls == 1)
    }

    @Test("a tear over eight seconds springs back, and a late success still lets the person in")
    func timeout() async {
        let source = ScriptedInviteSource()
        source.tearDelay = .milliseconds(300)
        // the injected clock makes the eight seconds instant, so the answer is still in flight
        let model = InviteModel(
            phase: .ready, source: source, preview: SampleInvite.face, face: SampleInvite.face, firstName: "sam",
            sleep: { duration in
                if duration == .seconds(8) {
                    return
                }
                try? await Task.sleep(for: .milliseconds(1))
            }
        )
        await model.commitTear()
        #expect(model.phase == .ready)
        #expect(model.caption == "that didn't go through. nothing was used; try again.")
        try? await Task.sleep(for: .milliseconds(600))
        #expect(model.phase == .youreIn)
    }

    @Test("begin hands on once, and only after the words have landed")
    func begin() async {
        let source = ScriptedInviteSource()
        let model = model(.ready, source)
        var finished = 0
        model.onFinish = { finished += 1 }
        model.begin()
        #expect(source.begun == 0)
        await model.commitTear()
        model.begin()
        #expect(source.begun == 1)
        #expect(finished == 1)
    }

    @Test("the tear key is made at touch-down, only while the ticket is ready")
    func touchDown() {
        let source = ScriptedInviteSource()
        let ready = model(.ready, source)
        ready.tearTouchedDown()
        #expect(source.tearTouchDowns == 1)
        model(.typed, source).tearTouchedDown()
        #expect(source.tearTouchDowns == 1)
    }

    // MARK: Words and relaunch

    @Test("you're in reads with the name, the inviter, and neutral without them")
    func words() {
        let source = ScriptedInviteSource()
        #expect(model(.youreIn, source).youreInTitle == "you're in, sam.")
        #expect(model(.youreIn, source, name: nil).youreInTitle == "you're in.")
        let anonymous = InviteModel(phase: .youreIn, source: source, firstName: "sam")
        #expect(anonymous.youreInLine == "someone kept this for you. make it count.")
    }

    @Test("a relaunch lands on the ticket whole before the tear, and on you're in after it")
    func relaunch() {
        #expect(InviteModel.relaunched(.promise) == .promise)
        for phase in [InviteModel.Phase.printing, .ready, .sealing] {
            #expect(InviteModel.relaunched(phase) == .ready)
        }
        #expect(InviteModel.relaunched(.torn) == .youreIn)
        #expect(InviteModel.relaunched(.youreIn) == .youreIn)
    }

    // MARK: The waitlist

    @Test("joined shows only after the door said so; a failure keeps the sheet")
    func waitlist() async {
        let source = ScriptedInviteSource()
        source.joins = false
        let model = model(.typed, source)
        model.openWaitlist()
        await model.join(reason: "  ")
        #expect(model.waitlist == .failed)
        source.joins = true
        await model.join(reason: nil)
        #expect(model.waitlist == .joined)
        #expect(model.caption == "you're on the list.")
        model.closeWaitlist()
        #expect(model.waitlist == .joined)
    }

    // MARK: Scenarios

    @Test("every scenario builds without a network, and every launcher state is a scenario")
    func scenarios() {
        for scenario in InviteScenario.allCases {
            _ = InviteModel.sample(scenario)
        }
        #expect(Set(InviteScenario.pi1 + InviteScenario.pi2) == Set(InviteScenario.allCases))
    }

    @Test("the sample code is usable and any other is not")
    func sampleSource() async {
        let source = SampleInviteSource(sleep: { _ in })
        #expect(await source.type(code: "7kq2-m9xd-4rta-b") == .printing(SampleInvite.face))
        #expect(await source.type(code: "AAAAAAAAAAAAA") == .refused(nil, .invalid))
    }
}
