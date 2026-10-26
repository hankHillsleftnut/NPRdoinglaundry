import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PlayerSheetModelTests {
    private let clock = TestClock()

    private func model(_ scenario: Flows.PlaybackScenario, onCollapse: @escaping () -> Void = {}) -> PlayerSheetModel {
        PlayerSheetModel(
            playback: SamplePlayback(scenario: scenario, clock: clock),
            transcript: SampleTranscript.tease,
            onCollapse: onCollapse
        )
    }

    @Test("the sheet's state follows the player's, every case", arguments: [
        (Flows.PlaybackState.idle, PlayerSheetModel.State.waiting),
        (.buffering, .waiting),
        (.playing, .playing),
        (.paused, .paused),
        (.ended, .ended),
        (.failed(Flows.Failure(.network)), .failed),
        (.offline, .offline),
    ])
    func stateFromPlayer(playback: Flows.PlaybackState, sheet: PlayerSheetModel.State) {
        #expect(PlayerSheetModel.State(playback) == sheet)
    }

    @Test("as drawn: playing on the line Paper lights (the third, at 0:04) with Paper's title")
    func asDrawn() {
        let sheet = model(.teaseStill)
        #expect(sheet.state == .playing)
        #expect(sheet.playback.position == 4)
        #expect(sheet.currentLine == 2)
        #expect(sheet.title == "the week you started")
    }

    @Test("the lit line follows the player: a seek to 0:02 lights the second line, back 15 the first; the end lights the last")
    func litLineFollowsThePlayer() {
        let sheet = model(.teasePaused)
        sheet.playback.seek(to: 2)
        #expect(sheet.currentLine == 1)
        sheet.playback.seek(to: 1.999)
        #expect(sheet.currentLine == 0)
        sheet.playback.skip(by: -15)
        #expect(sheet.playback.position == 0)
        #expect(sheet.currentLine == 0)
        #expect(model(.teaseEnded).currentLine == 4)
        #expect(model(.teaseEnded).state == .ended)
    }

    @Test("the tease starts at 0:00, playing")
    func teaseStartsAtTheStart() {
        let sheet = model(.tease)
        #expect(sheet.playback.position == 0)
        #expect(sheet.state == .playing)
        #expect(sheet.currentLine == 0)
    }

    @Test("when the player moves on to another item, nothing is lit and the header follows the new item")
    func anotherItemLightsNothing() async {
        let sheet = model(.teasePaused)
        #expect(sheet.currentLine == 2)
        await sheet.playback.load(SamplePlayback.item(for: .briefPaused))
        #expect(sheet.currentLine == nil, "never this episode's line against another item's time")
        #expect(sheet.title == "today's brief", "the header reads the player's item, live")
    }

    @Test("collapse is handed over once, however often it's tapped")
    func collapseOnce() {
        var collapses = 0
        let sheet = model(.teaseStill) { collapses += 1 }
        sheet.collapse()
        sheet.collapse()
        #expect(collapses == 1)
        #expect(sheet.hasCollapsed)
    }

    @Test("the tease is 10 seconds in one part (founder Q5 = B): one capsule, \"00:00 / −00:10\", no chapter name")
    func teaseIsTenSeconds() {
        let item = SamplePlayback.tease
        #expect(item.kind == .episode)
        #expect(item.durationSeconds == 10)
        #expect(item.parts.count == 1)
        #expect(item.parts[0].title == nil)
        let math = ScrubberMath(width: 346, duration: 10, partStarts: item.parts.map(\.startSeconds))
        #expect(math.segments.count == 1)
        #expect(math.segments[0].width == 346)
        #expect(ScrubberWords.clock(0) == "00:00")
        #expect(ScrubberWords.remaining(10) == "\u{2212}00:10")
        #expect(ScrubberWords.partName(0, of: 1, title: item.parts[0].title, style: .title) == "")
        // every line starts inside the episode, so each is lit in its turn
        #expect(SampleTranscript.tease.lines.allSatisfy { ($0.startSeconds ?? -1) >= 0 && ($0.startSeconds ?? 99) < 10 })
    }

    @Test("\"correct this part\" reads Paper's words (26OW-0)")
    func correctThisPartWords() {
        #expect(CorrectThisPart.words == "correct this part")
    }

    @Test("the launcher opens every player state")
    func launcherStates() {
        #expect(ScreenRegistry.screen("player")?.states == ["tease", "tease-still", "tease-paused", "tease-ended"])
        #expect(ScreenRegistry.allIDs.filter { $0 == "player" }.count == 1)
    }
}
