import CoreGraphics
@testable import Retrospect
import Testing

/// TEAR.motion: the controller drives the tear's physics on its own clock, the haptics come from the
/// paper's events (a click per hole, the rip on the snap frame, a landing tap), and Reduce Motion keeps
/// the two-state tear with no physics at all.
@MainActor
struct InviteStageTearTests {
    private let geometry = TicketGeometry(width: 354, compact: false)

    /// A clock the test moves by hand.
    private final class Hands {
        var now = 0.0
    }

    /// The model holds at `.torn` (its 0.9 s beat never ends), so the test sees the rip arrive.
    private static let holdAtTorn: @Sendable (Duration) async -> Void = { _ in try? await Task.sleep(for: .seconds(3600)) }

    private func make(_ hands: Hands, reduceMotion: Bool = false) -> (InviteStageController, InviteModel, ScriptedInviteSource) {
        let source = ScriptedInviteSource()
        let model = InviteModel(
            phase: .ready, source: source, signIn: source, preview: SampleInvite.face, face: SampleInvite.face,
            firstName: "sam", sleep: Self.holdAtTorn
        )
        let stage = InviteStageController(model: model, clock: { hands.now })
        stage.placeTear(geometry, reduceMotion: reduceMotion)
        return (stage, model, source)
    }

    /// Frames at 120 Hz until `end`.
    private func play(_ stage: InviteStageController, _ hands: Hands, to end: Double) {
        while hands.now < end {
            hands.now += 1.0 / 120
            stage.advanceTear()
        }
    }

    private func drag(_ stage: InviteStageController, _ hands: Hands, to share: CGFloat) {
        for step in 0 ... 60 {
            hands.now += 1.0 / 120
            stage.dragChanged(x: share * geometry.width * CGFloat(step) / 60, dy: 6, width: geometry.width)
            stage.advanceTear()
        }
    }

    private func waitForTorn(_ model: InviteModel) async {
        for _ in 0 ..< 200 where model.phase != .torn {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("a committed tear clicks hole by hole, snaps on the redeem's answer, falls and lands, all from the paper's events")
    func committedTear() async {
        let hands = Hands()
        let (stage, model, _) = make(hands)
        #expect(stage.tearFrame == nil) // whole: the two-state drawing, identical at rest
        drag(stage, hands, to: 0.74)
        #expect(stage.clicks >= 8)
        #expect(stage.tearFrame?.separated == false)
        #expect(stage.moving)
        stage.dragEnded(x: 0.74 * geometry.width, velocity: 120, width: geometry.width)
        play(stage, hands, to: hands.now + 0.4) // the run reaches the last bridge and hangs
        #expect(stage.rips == 0)
        await waitForTorn(model)
        #expect(model.phase == .torn)
        stage.phaseChanged(reduceMotion: false)
        #expect(stage.rips == 1) // the snap frame
        #expect(stage.tearFrame?.separated == true)
        play(stage, hands, to: hands.now + 2)
        #expect(stage.stubLandings == 1)
        #expect(stage.rips == 1)
        #expect(!stage.moving) // at rest the clock stops
        let rest = stage.tearFrame?.stub
        #expect(abs((rest?.angle ?? 0) - RNumber.motionTearRestAngle) < 0.1)
        #expect(abs((rest?.offset.height ?? 0) - TicketStage.dropGap(compact: false)) < 0.5)
    }

    @Test("a short release springs the paper back whole, and the clock stops")
    func shortRelease() {
        let hands = Hands()
        let (stage, _, source) = make(hands)
        drag(stage, hands, to: 0.4)
        stage.dragEnded(x: 0.4 * geometry.width, velocity: 0, width: geometry.width)
        play(stage, hands, to: hands.now + 1.5)
        #expect(stage.tearFrame == nil)
        #expect(!stage.moving)
        #expect(source.tearCalls == 0)
    }

    @Test("the handle follows the finger 1:1 while it drags, then rides the run")
    func handle() {
        let hands = Hands()
        let (stage, _, _) = make(hands)
        drag(stage, hands, to: 0.5)
        #expect(abs(stage.handleX(width: geometry.width) - 0.5 * geometry.width) < 0.001)
        stage.dragEnded(x: 0.5 * geometry.width, velocity: 900, width: geometry.width)
        play(stage, hands, to: hands.now + 0.05)
        #expect(stage.handleX(width: geometry.width) > 0.5 * geometry.width)
    }

    @Test("Reduce Motion: no physics, and the rip lands with the cross-fade on the torn phase")
    func reduceMotion() async {
        let hands = Hands()
        let (stage, model, _) = make(hands, reduceMotion: true)
        #expect(stage.tear == nil)
        Task { await stage.tearByAction() } // the model then holds at torn
        await waitForTorn(model)
        stage.phaseChanged(reduceMotion: true)
        #expect(stage.rips == 1)
        #expect(stage.tearFrame == nil)
        #expect(stage.clicks == 0)
    }

    @Test("VoiceOver's 'tear ticket' runs the paper by itself")
    func voiceOverRuns() async {
        let hands = Hands()
        let (stage, model, source) = make(hands)
        Task { await stage.tearByAction() } // the model then holds at torn
        try? await Task.sleep(for: .milliseconds(20))
        #expect(source.tearCalls == 1)
        play(stage, hands, to: 1)
        #expect(stage.clicks >= 6)
        await waitForTorn(model)
        stage.phaseChanged(reduceMotion: false)
        #expect(stage.rips == 1)
    }
}
