import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct BriefSheetModelTests {
    private let clock = TestClock()

    private func model(
        _ scenario: Flows.PlaybackScenario,
        content: BriefSheetContent = SampleBrief.heavierWeek,
        onCollapse: @escaping () -> Void = {}
    ) -> BriefSheetModel {
        BriefSheetModel(playback: SamplePlayback(scenario: scenario, clock: clock), content: content, onCollapse: onCollapse)
    }

    @Test("playing, as Paper draws it (1FMG-0): part 1 now at 0:48 of 4:10, parts 2 and 3 next, the headline")
    func playingAsDrawn() {
        let sheet = model(.briefPaperPlaying)
        #expect(sheet.playback.state == .playing)
        #expect(sheet.playback.position == 48)
        #expect(sheet.playback.duration == 250)
        #expect(sheet.title == "a heavier week than usual, and it shows.")
        #expect(sheet.nowLabel == .playingNow)
        #expect(sheet.place == "1 of 3")
        #expect(sheet.now?.title == "the fundraise article you sent")
        #expect(sheet.now?.why == "here for your goal: raise the seed")
        #expect(sheet.now?.source == "from the link you sent yesterday, 9:14")
        #expect(sheet.next.map(\.number) == [2, 3])
        #expect(sheet.next.map(\.part.title) == ["four meetings before noon", "five hours of sleep, two nights running"])
    }

    @Test("paused (GLN-0): the playing part stays raised, still \"playing now\"")
    func pausedKeepsThePart() {
        let sheet = model(.briefPaperPaused)
        #expect(sheet.playback.state == .paused)
        #expect(sheet.nowLabel == .playingNow)
        #expect(sheet.place == "1 of 3")
        #expect(sheet.next.count == 2)
    }

    @Test("played (GNY-0): the last part, \"played\", nothing next")
    func played() {
        let sheet = model(.briefPaperPlayed)
        #expect(sheet.playback.state == .ended)
        #expect(sheet.nowLabel == .played)
        #expect(sheet.nowLabel.words == "played")
        #expect(sheet.place == "3 of 3")
        #expect(sheet.now?.why == "here for your goal: sleep before midnight")
        #expect(sheet.now?.source == "from your watch, monday and tuesday")
        #expect(sheet.next.isEmpty)
    }

    @Test("the card follows the audio: a seek into part 2 makes it now, with only part 3 next")
    func followsTheAudio() {
        let sheet = model(.briefPaperPaused)
        sheet.playback.seek(to: 100)
        #expect(sheet.place == "2 of 3")
        #expect(sheet.now?.title == "four meetings before noon")
        #expect(sheet.next.map(\.number) == [3])
        sheet.playback.seek(to: 200)
        #expect(sheet.place == "3 of 3")
        #expect(sheet.nowLabel == .playingNow)
        #expect(sheet.next.isEmpty)
    }

    @Test("played, then play: back to part 1 and \"playing now\"")
    func playAfterTheEnd() {
        let sheet = model(.briefPaperPlayed)
        sheet.playback.play()
        #expect(sheet.playback.position == 0)
        #expect(sheet.nowLabel == .playingNow)
        #expect(sheet.place == "1 of 3")
    }

    @Test("quiet (GQ9-0): no parts, Paper's line and note, playing at 0:12 of 0:40")
    func quiet() {
        let sheet = model(.briefPaperQuiet, content: SampleBrief.quietTuesday)
        #expect(sheet.isQuiet)
        #expect(sheet.parts.isEmpty)
        #expect(sheet.now == nil)
        #expect(sheet.next.isEmpty)
        #expect(sheet.title == "a quiet tuesday")
        #expect(sheet.playback.position == 12)
        #expect(sheet.playback.duration == 40)
        #expect(sheet.content.kind == .quiet(line: "nothing much moved. enjoy the quiet.", note: "a short brief today · 40 seconds"))
    }

    @Test("a part index past the brief's parts never reads out of range")
    func clampsToParts() {
        let short = BriefSheetContent(kind: .brief(parts: [.init(title: "only one", why: nil, source: nil)]))
        let sheet = model(.briefPaperPaused, content: short)
        sheet.playback.seek(to: 200)
        #expect(sheet.now?.title == "only one")
        #expect(sheet.place == "1 of 1")
        #expect(sheet.next.isEmpty)
    }

    @Test("collapse goes back once; a second tap does nothing")
    func collapseOnce() {
        var collapses = 0
        let sheet = model(.briefPaperPlaying) { collapses += 1 }
        sheet.collapse()
        sheet.collapse()
        #expect(collapses == 1)
        #expect(sheet.hasCollapsed)
    }

    @Test("share hands over the headline")
    func share() {
        #expect(model(.briefPaperPlaying).shareText == "a heavier week than usual, and it shows. · retrospect")
    }

    @Test("every JR-2 launcher state opens", arguments: BriefScenario.allCases)
    func launcherStates(scenario: BriefScenario) {
        #expect(ScreenRegistry.all["JR-2"]?.states.contains(scenario.rawValue) == true)
        let sheet = model(scenario.playback, content: scenario.content)
        #expect(sheet.isQuiet == (scenario == .quiet))
    }
}
