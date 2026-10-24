import Foundation
@testable import Retrospect
import Testing

/// A reading the test ends by hand: `finish()` makes `read()` return true; `stop()` makes it
/// return false. Counts the stops.
@MainActor
private final class HeldReadAloud: PrivacyReadAloud {
    private var continuation: CheckedContinuation<Bool, Never>?
    private(set) var stops = 0
    private(set) var isReading = false

    func read() async -> Bool {
        isReading = true
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish() {
        isReading = false
        continuation?.resume(returning: true)
        continuation = nil
    }

    func stop() {
        stops += 1
        isReading = false
        continuation?.resume(returning: false)
        continuation = nil
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PrivacyModelTests {
    @MainActor
    private final class Exits {
        var advances = 0
        var backs = 0
    }

    private let exits = Exits()
    private let reading = HeldReadAloud()

    private func make(_ readAloud: (any PrivacyReadAloud)? = nil) -> PrivacyModel {
        let exits = exits
        return PrivacyModel(
            readAloud: readAloud ?? reading,
            onAdvance: { exits.advances += 1 },
            onBack: { exits.backs += 1 }
        )
    }

    /// Gives the model's tasks a chance to reach `condition`.
    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 400 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Starts the page's run on a task the test can cancel, once Retro is reading.
    private func start(_ model: PrivacyModel) async -> Task<Void, Never> {
        let run = Task { await model.run() }
        await settle { reading.isReading }
        return run
    }

    // MARK: The read-aloud moves the page on

    @Test("when Retro finishes reading the page moves on by itself, once")
    func readingEndAdvances() async {
        let model = make()
        let run = await start(model)
        #expect(exits.advances == 0)
        reading.finish()
        await settle { exits.advances == 1 }
        #expect(exits.advances == 1)
        // a host that reports the end twice moves nothing more
        model.readAloudFinished()
        #expect(exits.advances == 1)
        run.cancel()
    }

    @Test("the sample reading takes 8 s of the test clock, not a moment less, then moves on")
    func sampleReadingTakesEightSeconds() async {
        let clock = TestClock()
        let model = make(SamplePrivacyReadAloud(clock: clock))
        let run = Task { await model.run() }
        await settle { clock.pendingSleeps >= 1 }
        clock.advance(by: .milliseconds(7999))
        await settle { exits.advances == 1 }
        #expect(exits.advances == 0)
        clock.advance(by: .milliseconds(1))
        await settle { exits.advances == 1 }
        #expect(exits.advances == 1)
        run.cancel()
    }

    // MARK: A tap anywhere

    @Test("a tap anywhere moves on early, stops Retro, and the reading's later end adds nothing")
    func tapMovesOnEarly() async {
        let model = make()
        let run = await start(model)
        model.tapAnywhere()
        model.tapAnywhere()
        #expect(exits.advances == 1)
        #expect(reading.stops == 1)
        model.readAloudFinished()
        #expect(exits.advances == 1)
        run.cancel()
    }

    // MARK: Back

    @Test("back reports once, stops Retro, and nothing moves on after it")
    func backOnceAndFinal() async {
        let model = make()
        let run = await start(model)
        model.back()
        model.back()
        #expect(exits.backs == 1)
        #expect(reading.stops == 1)
        model.tapAnywhere()
        model.readAloudFinished()
        #expect(exits.advances == 0)
        run.cancel()
    }

    @Test("after moving on, back does nothing")
    func advanceBlocksBack() {
        let model = make()
        model.tapAnywhere()
        model.back()
        #expect(exits.backs == 0)
        #expect(exits.advances == 1)
    }

    // MARK: Leaving the screen

    @Test("the page going off screen stops Retro, and the cancelled run doesn't move on")
    func leavingTheScreenStopsTheReading() async {
        let model = make()
        let run = await start(model)
        run.cancel()
        model.pageLeft()
        await run.value
        #expect(reading.stops == 1)
        #expect(exits.advances == 0)
        #expect(!model.hasLeft)
    }

    @Test("a reading that ends after the page went off screen moves nothing; back on screen it reads again")
    func lateEndOffScreenMovesNothing() async {
        let model = make()
        let run = await start(model)
        // the voice hands back read() on stop() before SwiftUI cancels the run (the m4 race)
        model.pageLeft()
        await run.value
        model.readAloudFinished()
        #expect(exits.advances == 0)
        #expect(model.phase == .offScreen)
        // the page returns: Retro reads again, and that reading's end moves on, once
        let again = await start(model)
        #expect(model.phase == .reading)
        reading.finish()
        await again.value
        #expect(exits.advances == 1)
        #expect(model.phase == .left)
    }

    @Test("one phase: reading → finished (held) → left, the holds beside it")
    func phaseWalk() {
        let model = make()
        #expect(model.phase == .reading)
        #expect(model.holds.isEmpty)
        model.voiceOver(running: true)
        model.openPolicy()
        #expect(model.holds == [.assistiveTech, .policy])
        model.readAloudFinished()
        #expect(model.phase == .finished)
        // the policy is open over a finished page: not yet the VoiceOver wait
        #expect(!model.isWaitingForVoiceOver)
        model.policyClosed()
        #expect(model.holds == [.assistiveTech])
        #expect(model.isWaitingForVoiceOver)
        model.voiceOver(running: false)
        #expect(model.phase == .left)
        #expect(model.hasLeft)
        #expect(exits.advances == 1)
        // left is terminal: nothing reopens or fires
        model.openPolicy()
        model.back()
        #expect(!model.isPolicyOpen)
        #expect(exits.backs == 0)
    }

    @Test("a reading cut short from outside (a call, Siri) still moves the page on: never stuck")
    func interruptedReadingAdvances() async {
        let model = make()
        let run = await start(model)
        // the voice ends early on its own: read() returns false, the page isn't cancelled
        reading.stop()
        await run.value
        #expect(exits.advances == 1)
    }

    @Test("an interrupted reading under VoiceOver is held like a finished one")
    func interruptedReadingUnderVoiceOver() async {
        let model = make()
        model.voiceOver(running: true)
        let run = await start(model)
        reading.stop()
        await run.value
        #expect(exits.advances == 0)
        #expect(model.isWaitingForVoiceOver)
    }

    // MARK: VoiceOver

    @Test("with VoiceOver on, the end of the reading never moves the page; the move on action does")
    func voiceOverHoldsTheAdvance() {
        let model = make()
        model.voiceOver(running: true)
        model.readAloudFinished()
        #expect(exits.advances == 0)
        #expect(model.isWaitingForVoiceOver)
        model.moveOn()
        #expect(exits.advances == 1)
        #expect(!model.isWaitingForVoiceOver)
    }

    @Test("VoiceOver turned off after Retro finished: the held page moves on then")
    func voiceOverOffReleases() {
        let model = make()
        model.voiceOver(running: true)
        model.readAloudFinished()
        model.voiceOver(running: false)
        #expect(exits.advances == 1)
    }

    @Test("VoiceOver going on and off before Retro finishes changes nothing")
    func voiceOverBeforeTheEnd() {
        let model = make()
        model.voiceOver(running: true)
        model.voiceOver(running: false)
        #expect(exits.advances == 0)
        #expect(!model.isWaitingForVoiceOver)
    }

    // MARK: The policy

    @Test("a reading that ends while the policy is open waits for the sheet to close")
    func policyHoldsTheAdvance() {
        let model = make()
        model.openPolicy()
        #expect(model.isPolicyOpen)
        model.readAloudFinished()
        #expect(exits.advances == 0)
        model.policyClosed()
        #expect(!model.isPolicyOpen)
        #expect(exits.advances == 1)
    }

    @Test("closing the policy before Retro finishes doesn't move on")
    func policyCloseAlone() {
        let model = make()
        model.openPolicy()
        model.policyClosed()
        #expect(exits.advances == 0)
    }

    @Test("policy closed while VoiceOver is on: still held for the move on action")
    func policyAndVoiceOver() {
        let model = make()
        model.voiceOver(running: true)
        model.openPolicy()
        model.readAloudFinished()
        model.policyClosed()
        #expect(exits.advances == 0)
        #expect(model.isWaitingForVoiceOver)
    }

    // MARK: Progress and words

    @Test("the page's place in the flow is 41% → 48% (Paper), and a range is clamped to 0…1")
    func progressRange() {
        #expect(PrivacyModel.progress == FlowProgress(from: 0.41, to: 0.48))
        let wild = FlowProgress(from: -0.2, to: 1.4)
        #expect(wild.from == 0)
        #expect(wild.to == 1)
    }

    @Test("the copy is Paper's, word for word")
    func copyIsPapers() {
        #expect(PrivacyModel.title == "what you tell me stays yours.")
        #expect(PrivacyModel.body == "i only read what you connect and tell me. a few trusted companies help me "
            + "understand it, and more of it moves onto your phone over time. i never sell it. delete everything, anytime.")
        #expect(PrivacyModel.policyLink == "read the privacy policy")
    }
}
