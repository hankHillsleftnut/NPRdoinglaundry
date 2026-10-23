import CoreGraphics
@testable import Retrospect
import Testing

/// PI2.2: the tear as a finger does it. Nothing is spent unless the release commits, and a commit
/// spends the code once.
@MainActor
struct InviteStageControllerTests {
    private let width: CGFloat = 354

    private func make(_ scripted: ScriptedInviteSource? = nil) -> (InviteStageController, InviteModel, ScriptedInviteSource) {
        let source = scripted ?? ScriptedInviteSource()
        let model = InviteModel(
            phase: .ready, source: source, signIn: source, preview: SampleInvite.face, face: SampleInvite.face,
            firstName: "sam", sleep: InviteModelTests.quickly
        )
        return (InviteStageController(model: model), model, source)
    }

    @Test("a release at 61% springs back whole and spends nothing")
    func shortDrag() async {
        let (stage, model, source) = make()
        stage.dragChanged(x: 0.61 * width, dy: 0, width: width)
        stage.dragEnded(x: 0.61 * width, velocity: 0, width: width)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.phase == .ready)
        #expect(source.tearCalls == 0)
        #expect(stage.tearProgress == 0)
        #expect(!model.keepGoing)
    }

    @Test("a release at 62% commits: the code is spent once and the person is in")
    func commits() async {
        let (stage, model, source) = make()
        stage.dragChanged(x: 0.62 * width, dy: 0, width: width)
        stage.dragEnded(x: 0.62 * width, velocity: 0, width: width)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(source.tearCalls == 1)
        #expect(source.tearTouchDowns == 1)
        #expect(model.phase == .youreIn)
    }

    @Test("a fast flick at 30% commits; a slow one doesn't")
    func flick() async {
        let (fast, fastModel, fastSource) = make()
        fast.dragChanged(x: 0.3 * width, dy: 0, width: width)
        fast.dragEnded(x: 0.3 * width, velocity: 900, width: width)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(fastSource.tearCalls == 1)
        #expect(fastModel.phase == .youreIn)
        let (slow, _, slowSource) = make()
        slow.dragChanged(x: 0.3 * width, dy: 0, width: width)
        slow.dragEnded(x: 0.3 * width, velocity: 700, width: width)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(slowSource.tearCalls == 0)
    }

    @Test("a finger more than 44pt off the line ends the drag as a release, below the threshold")
    func wandered() async {
        let (stage, _, source) = make()
        stage.dragChanged(x: 0.4 * width, dy: 0, width: width)
        stage.dragChanged(x: 0.5 * width, dy: 60, width: width)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(stage.tearProgress == 0)
        #expect(source.tearCalls == 0)
    }

    @Test("after wandering off the line the drag stays ended until the finger lifts: one touch-down, no tick per frame")
    func wanderedStaysEnded() async {
        let (stage, _, source) = make()
        stage.dragChanged(x: 0.4 * width, dy: 0, width: width)
        stage.dragChanged(x: 0.5 * width, dy: 60, width: width)
        let ticks = stage.ticks
        stage.dragChanged(x: 0.55 * width, dy: 70, width: width) // the next frames, still off the line
        stage.dragChanged(x: 0.9 * width, dy: 0, width: width) // and back on it: still the same, ended drag
        #expect(source.tearTouchDowns == 1)
        #expect(stage.ticks == ticks)
        #expect(stage.tearProgress == 0)
        stage.dragEnded(x: 0.9 * width, velocity: 0, width: width) // the lift: nothing commits
        try? await Task.sleep(for: .milliseconds(50))
        #expect(source.tearCalls == 0)
        stage.dragChanged(x: 0.2 * width, dy: 0, width: width) // a new touch tears again
        #expect(source.tearTouchDowns == 2)
    }

    @Test("a cancelled gesture (a call, the app backgrounding) leaves the ticket whole")
    func cancelled() {
        let (stage, model, source) = make()
        stage.dragChanged(x: 0.5 * width, dy: 0, width: width)
        stage.dragCancelled()
        #expect(stage.tearProgress == 0)
        #expect(model.phase == .ready)
        #expect(source.tearCalls == 0)
    }

    @Test("past the end the tear is held to the line, and each hole passed ticks at most once")
    func ticks() {
        let (stage, _, _) = make()
        let before = stage.ticks
        stage.dragChanged(x: 2 * width, dy: 0, width: width)
        #expect(stage.tearProgress == 1)
        // touch-down is one tick; the fast jump past every hole at the same instant is at most one more
        #expect(stage.ticks - before <= 2)
    }

    @Test("the VoiceOver action tears the whole way without a drag")
    func voiceOver() async {
        let (stage, model, source) = make()
        await stage.tearByAction()
        #expect(source.tearCalls == 1)
        #expect(model.phase == .youreIn)
    }

    @Test("a tear can't start unless the ticket is ready")
    func notReady() {
        let source = ScriptedInviteSource()
        let model = InviteModel(phase: .refused(.used), source: source, signIn: source)
        let stage = InviteStageController(model: model)
        stage.dragChanged(x: 100, dy: 0, width: width)
        #expect(stage.tearProgress == 0)
        #expect(source.tearTouchDowns == 0)
    }

    @Test("the Reduce Motion hold: a release before the hold completes empties the fill and spends nothing")
    func holdReleasedEarly() {
        let (stage, _, source) = make()
        stage.holdBegan()
        #expect(stage.holdProgress == 1) // the fill along the tear line is running
        stage.holdReleased(completed: false)
        #expect(stage.holdProgress == 0) // and empties on an early lift
        #expect(source.tearCalls == 0)
    }

    @Test("the Reduce Motion hold: a full hold commits the tear without the finger lifting")
    func holdCompletes() async {
        let source = ScriptedInviteSource()
        let model = InviteModel(
            phase: .ready, source: source, signIn: source, preview: SampleInvite.face, face: SampleInvite.face,
            firstName: "sam", sleep: InviteModelTests.quickly
        )
        let stage = InviteStageController(model: model, sleep: { _ in try? await Task.sleep(for: .milliseconds(5)) })
        stage.holdBegan() // the touch goes down and stays down: only the controller's own timer can finish it
        try? await Task.sleep(for: .milliseconds(300))
        #expect(source.tearCalls == 1)
        #expect(stage.tearProgress == 1)
    }

    @Test("the Reduce Motion hold: a failed tear empties the fill, and the same finger can't start another hold")
    func holdFailsOffline() async {
        let source = ScriptedInviteSource()
        source.tears = [.offline]
        let model = InviteModel(
            phase: .ready, source: source, signIn: source, preview: SampleInvite.face, face: SampleInvite.face,
            firstName: "sam", sleep: InviteModelTests.quickly
        )
        let stage = InviteStageController(model: model, sleep: { _ in try? await Task.sleep(for: .milliseconds(5)) })
        stage.holdBegan()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(source.tearCalls == 1)
        #expect(model.phase == .ready)
        stage.phaseChanged(reduceMotion: true) // what the page's onChange(of: phase) does
        #expect(stage.holdProgress == 0)
        stage.holdBegan() // the finger never lifted: a jitter must not start a second hold
        try? await Task.sleep(for: .milliseconds(300))
        #expect(source.tearCalls == 1)
        stage.holdReleased(completed: false) // the lift
        stage.holdBegan() // a new touch holds again
        #expect(stage.holdProgress == 1)
    }

    @Test("back from the background mid-print it is simply done: the late animation completion plays no landing")
    func skippedPrintIsSilent() {
        let source = ScriptedInviteSource()
        let model = InviteModel(phase: .printing, source: source, signIn: source, face: SampleInvite.face, sleep: InviteModelTests.quickly)
        let stage = InviteStageController(model: model)
        stage.startPrint(reduceMotion: true)
        stage.finishPrintNow()
        #expect(model.phase == .ready)
        let landed = stage.landings // (the headless test may complete the animation at once)
        stage.printLanded() // the print's withAnimation completion, arriving after the skip
        #expect(stage.landings == landed)
    }

    @Test("a print that runs to the end lands once, with the settle tick")
    func printLandsOnce() {
        let source = ScriptedInviteSource()
        let model = InviteModel(phase: .printing, source: source, signIn: source, face: SampleInvite.face, sleep: InviteModelTests.quickly)
        let stage = InviteStageController(model: model)
        stage.startPrint(reduceMotion: true)
        stage.printLanded()
        stage.printLanded()
        #expect(stage.landings == 1)
        #expect(model.phase == .ready)
    }

    @Test("the tear action is offered only while the ticket is ready")
    func tearActionOnlyWhenReady() {
        let source = ScriptedInviteSource()
        for phase: InviteModel.Phase in [.typed, .printing, .sealing, .torn, .youreIn, .refused(.used)] {
            let stage = InviteStageController(model: InviteModel(phase: phase, source: source, signIn: source))
            #expect(!stage.canTear, "\(phase)")
        }
        let (ready, _, _) = make()
        #expect(ready.canTear)
    }
}
