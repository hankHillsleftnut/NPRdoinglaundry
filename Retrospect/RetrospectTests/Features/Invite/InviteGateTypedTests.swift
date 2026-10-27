import AuthenticationServices
@testable import Retrospect
import Testing

/// SI.gate.b: the founder's typed invite gate (26 Oct, over Paper `2IRH-0`). The resting line is the small
/// pill ("type it in"), "the tear unlocks" is gone, the foot is the waitlist as a secondary button (no
/// "one use · yours alone" under the page), a refusal keeps its link and its footer, and the header shows
/// before the check in the sample only: the live page still learns it from the check.
@MainActor
struct InviteGateTypedTests {
    private static let quickly: @Sendable (Duration) async -> Void = { _ in }

    private func typed(_ source: ScriptedInviteSource, face: Session.TicketFace? = nil) -> InviteModel {
        InviteModel(phase: .typed, source: source, signIn: source, face: face, firstName: "sam", sleep: Self.quickly)
    }

    @Test("at rest: the pill says 'type it in', no caption, no footer, the waitlist at the foot")
    func resting() {
        let model = typed(ScriptedInviteSource())
        #expect(model.hint == "the link didn't bring the code? type it in.")
        #expect(model.caption == nil)
        #expect(model.footer == nil)
        #expect(model.waitlistPlace == .foot)
        #expect(model.offersWaitlist)
    }

    @Test("the waitlist foot gives way to the keyboard and returns when it goes; a refusal never has one")
    func footGivesWayToTheKeyboard() {
        #expect(InviteScreen.showsWaitlistFoot(.foot, typing: false))
        #expect(!InviteScreen.showsWaitlistFoot(.foot, typing: true))
        #expect(!InviteScreen.showsWaitlistFoot(.link, typing: false))
        #expect(!InviteScreen.showsWaitlistFoot(nil, typing: false))
    }

    @Test("a notice with no words of its own never blanks both lines: the pill stays")
    func pillAndCaptionExclusive() {
        let model = typed(ScriptedInviteSource())
        model.applySample(InviteSetup(phase: .typed, face: nil, notice: .signInFailed, hasCode: false))
        #expect(model.caption == nil)
        #expect(model.hint == "the link didn't bring the code? type it in.")
    }

    @Test("'the tear unlocks when it's filled' is never shown on the typed ticket")
    func noTearUnlocks() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(nil, .invalid)
        let model = typed(source)
        #expect(model.hint != "the tear unlocks when it's filled")
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.hint != "the tear unlocks when it's filled")
    }

    @Test("a wrong code: its words take the caption, the pill steps aside, the waitlist stays at the foot")
    func wrongCode() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(nil, .invalid)
        let model = typed(source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.caption == "that code didn't work. check it, or ask for a new one.")
        #expect(model.hint == nil)
        #expect(model.waitlistPlace == .foot)
        #expect(model.footer == nil)
    }

    @Test("joined: no waitlist offered, the words say so")
    func joined() async {
        let model = typed(ScriptedInviteSource())
        model.openWaitlist()
        await model.join(reason: nil)
        #expect(model.waitlistPlace == nil)
        #expect(!model.offersWaitlist)
        #expect(model.hint == nil)
        #expect(model.caption == "you're on the list.")
    }

    @Test("a refused code keeps the text link and 'one use · yours alone' as before")
    func refusedUnchanged() async {
        let source = ScriptedInviteSource()
        source.typed = .refused(SampleInvite.face, .used)
        let model = typed(source)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.phase == .refused(.used))
        #expect(model.waitlistPlace == .link)
        #expect(model.footer == "one use · yours alone")
    }

    @Test("live path unchanged: signed in with no code, the ticket has no header until the check")
    func liveHeaderWaitsForTheCheck() async {
        let source = ScriptedInviteSource()
        source.afterSignIn = .none
        let model = InviteModel(phase: .promise, source: source, signIn: source, sleep: Self.quickly)
        await model.appleFinished(.failure(LiveStub()))
        #expect(model.phase == .typed)
        #expect(model.face == nil)
        model.setCode(SampleInvite.code)
        await model.submitTyped()
        #expect(model.face == SampleInvite.face) // the check brought it
    }

    @Test("the sample's typed states wear Paper's header before the check")
    func sampleHeader() {
        for scenario: InviteScenario in [.typed, .typedWrong, .typedFilled, .rateLimited, .waitlistSheet, .waitlisted] {
            let model = InviteModel.sample(scenario)
            #expect(model.phase == .typed, "\(scenario)")
            #expect(model.face == SampleInvite.face, "\(scenario)")
            #expect(TicketText.from(model.face) == "an invitation · from priya")
            #expect(TicketText.serial(model.face?.serial) == "no. 0412")
            #expect(!model.stubDate.isEmpty)
        }
    }
}

private struct LiveStub: Error {}
