import Foundation
@testable import Retrospect
import Testing

/// PC-2, the player sheet in episode mode (Paper 1FV9-0), on the sample weekly episode.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct EpisodePlayerTests {
    private let clock = TestClock()

    private func model(_ scenario: Flows.PlaybackScenario) -> PlayerSheetModel {
        PlayerSheetModel(
            playback: SamplePlayback(scenario: scenario, clock: clock),
            transcript: SampleEpisodeTranscript.weekly,
            onCollapse: {}
        )
    }

    @Test("as drawn: playing at 04:12 in chapter 2 of 4, 07:18 left, on the third line, with Paper's title")
    func asDrawn() throws {
        let sheet = model(.weeklyEpisodeStill)
        #expect(sheet.state == .playing)
        #expect(sheet.playback.position == 252)
        #expect(sheet.playback.currentPart == 1)
        #expect(sheet.currentLine == 2)
        #expect(sheet.title == "the week you kept choosing the river")
        let duration = try #require(sheet.playback.duration)
        #expect(ScrubberWords.clock(sheet.playback.position) == "04:12")
        #expect(ScrubberWords.remaining(duration - sheet.playback.position) == "\u{2212}07:18")
        let parts = try #require(sheet.playback.item?.parts)
        #expect(parts.count == 4)
        #expect(ScrubberWords.partName(1, of: parts.count, title: parts[1].title, style: .counted) == "2 of 4 · the river")
    }

    @Test("the five lines are Paper's, in order, and only the line being read is lit")
    func linesAndLitLine() {
        #expect(SampleEpisodeTranscript.weekly.lines.map(\.text) == SamplePlayback.weeklyLines)
        #expect(SampleEpisodeTranscript.weekly.isTimed)
        let sheet = model(.weeklyEpisodePaused)
        sheet.playback.seek(to: 150)
        #expect(sheet.currentLine == 1)
        sheet.playback.seek(to: 0)
        #expect(sheet.currentLine == 0)
        sheet.playback.seek(to: 300)
        #expect(sheet.currentLine == 3)
        #expect(model(.weeklyEpisodeEnded).currentLine == 4)
        #expect(model(.weeklyEpisodeEnded).state == .ended)
    }

    @Test("the downloaded stretch ends inside chapter 2, as drawn; the tease stays fully downloaded")
    func buffered() throws {
        let weekly = SamplePlayback(scenario: .weeklyEpisodeStill, clock: clock)
        let fraction = try #require(weekly.buffered)
        #expect(abs(fraction - 391.0 / 690.0) < 0.0001)
        #expect(SamplePlayback(scenario: .teaseStill, clock: clock).buffered == 1)
    }

    @Test(
        "the weekly episode's failed and offline states never play, whatever is tapped",
        arguments: [Flows.PlaybackScenario.weeklyEpisodeFailed, .weeklyEpisodeOffline]
    )
    func unplayable(scenario: Flows.PlaybackScenario) {
        let sheet = model(scenario)
        let before = sheet.state
        sheet.playback.play()
        #expect(sheet.state == before)
        #expect(sheet.state == (scenario == .weeklyEpisodeFailed ? .failed : .offline))
    }

    @Test("the weekly episode plays from 04:12 on the clock")
    func playsFromTheLitLine() {
        let sheet = model(.weeklyEpisode)
        #expect(sheet.state == .playing)
        #expect(sheet.playback.position == SamplePlayback.weeklyLitLine)
    }

    @Test("ON-11 is untouched: the sheet names the part by its title alone and its lines are not tappable by default")
    func teaseDefaults() {
        let sheet = PlayerSheet(model: PlayerSheetModel(
            playback: SamplePlayback(scenario: .teaseStill, clock: clock),
            transcript: SampleTranscript.tease,
            onCollapse: {}
        ))
        #expect(sheet.partLabel == .title)
        #expect(sheet.onTapLine == nil)
    }

    @Test("PC-2 is in the launcher with its six states, and a line tap hands over to why this is here")
    func launcher() {
        let screen = ScreenRegistry.groupScreens.first { $0.id == "PC-2" }
        #expect(screen?.states == ["playing", "playing-still", "paused", "ended", "failed", "offline"])
        #expect(EpisodePlayerExit.whyThisIsHere(line: 2).standIn == "why this is here · line 3")
        for scenario in EpisodePlayerScenario.allCases {
            #expect(SamplePlayback.weeklyScenarios.contains(scenario.playback))
        }
    }
}
