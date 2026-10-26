import CoreGraphics
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

    @Test("as drawn: playing at 0:48 with the third line lit and Paper's title")
    func asDrawn() {
        let sheet = model(.teaseStill)
        #expect(sheet.state == .playing)
        #expect(sheet.playback.position == 48)
        #expect(sheet.currentLine == 2)
        #expect(sheet.title == "the week you started")
    }

    @Test("the lit line follows the player: a skip back to the second chapter lights the second line; the end lights the last")
    func litLineFollowsThePlayer() {
        let sheet = model(.teasePaused)
        sheet.playback.skip(by: -15)
        #expect(sheet.playback.position == 33)
        #expect(sheet.currentLine == 1)
        #expect(model(.teaseEnded).currentLine == 4)
        #expect(model(.teaseEnded).state == .ended)
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

    @Test("the tease draws Paper's scrubber: four capsules 82 : 114 : 62 : 64, \"00:48\" · \"the first thing i noticed\" · \"−01:22\"")
    func teaseScrubberIsPapers() {
        let item = SamplePlayback.tease
        #expect(item.kind == .episode)
        #expect(item.durationSeconds == 130)
        // Paper 26OM-0 is 346 wide with three 4pt gaps
        let math = ScrubberMath(width: 346, duration: 130, partStarts: item.parts.map(\.startSeconds))
        let widths = math.segments.map(\.width)
        let paper: [CGFloat] = [82, 114, 62, 64].map { 334 * $0 / 322 }
        #expect(widths.count == 4)
        for (built, drawn) in zip(widths, paper) {
            #expect(abs(built - drawn) < 1, "each capsule within 1pt of Paper's")
        }
        let part = math.part(at: 48)
        #expect(ScrubberWords.clock(48) == "00:48")
        #expect(ScrubberWords.remaining(130 - 48) == "\u{2212}01:22")
        #expect(ScrubberWords.partName(part, of: 4, title: item.parts[part].title, style: .title) == "the first thing i noticed")
    }

    @Test("the launcher opens every player state")
    func launcherStates() {
        #expect(ScreenRegistry.screen("player")?.states == ["tease", "tease-still", "tease-paused", "tease-ended"])
        #expect(ScreenRegistry.allIDs.filter { $0 == "player" }.count == 1)
    }
}
