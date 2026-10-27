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
        let sheet = model(.weeklyEpisodeStill)
        sheet.playback.seek(to: 150)
        #expect(sheet.currentLine == 1)
        sheet.playback.seek(to: 0)
        #expect(sheet.currentLine == 0)
        // chapter 2 and its first line start together: the lit line and the scrubber's chapter agree
        sheet.playback.seek(to: 176)
        #expect(sheet.currentLine == 2)
        #expect(sheet.playback.currentPart == 1)
        sheet.playback.seek(to: 175.9)
        #expect(sheet.currentLine == 1)
        #expect(sheet.playback.currentPart == 0)
        sheet.playback.seek(to: 300)
        #expect(sheet.currentLine == 3)
        sheet.playback.seek(to: 690)
        #expect(sheet.currentLine == 4)
        #expect(sheet.state == .ended)
    }

    @Test("the downloaded stretch ends inside chapter 2, as drawn; the tease stays fully downloaded")
    func buffered() throws {
        let weekly = SamplePlayback(scenario: .weeklyEpisodeStill, clock: clock)
        let fraction = try #require(weekly.buffered)
        #expect(abs(fraction - 391.0 / 690.0) < 0.0001)
        #expect(SamplePlayback(scenario: .teaseStill, clock: clock).buffered == 1)
    }

    @Test("a weekly player that loads another episode reports that episode's download, never the weekly's")
    func bufferedFollowsTheLoadedEpisode() async {
        let player = SamplePlayback(scenario: .weeklyEpisodeStill, clock: clock)
        await player.load(SamplePlayback.tease)
        #expect(player.buffered == 1)
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

    @Test("PC-2 is in the launcher with Paper's one drawn state, live and held still, and a line tap hands over to why this is here")
    func launcher() {
        let screen = ScreenRegistry.groupScreens.first { $0.id == "PC-2" }
        #expect(screen?.states == ["playing", "playing-still"])
        #expect(EpisodePlayerExit.whyThisIsHere(line: 2).standIn == "why this is here · line 3")
        for scenario in EpisodePlayerScenario.allCases {
            #expect(SamplePlayback.weeklyScenarios.contains(scenario.playback))
        }
    }

    // Paper 1FV9-0's column is 513 tall; its lines' middles sit at 53, 131, 238, 345 and 423 (QA batch 4).
    private static let column: CGFloat = 513
    private static let middles: [CGFloat] = [53, 131, 238, 345, 423]

    @Test("at rest, as Paper draws it: the first and last lines blur under the bands, the middle three stay sharp")
    func edgesBlurTheFirstAndLastLine() {
        let edges = TranscriptEdges()
        let strengths = Self.middles.map { edges.strength(mid: $0, viewport: Self.column) }
        #expect(strengths[0] > 0.5)
        #expect(strengths[4] > 0.5)
        #expect(strengths[1 ... 3].allSatisfy { $0 == 0 })
        // the radius peaks at the token's 8 and never goes past it
        #expect(edges.radius(line: CGRect(x: 0, y: 0, width: 10, height: 10), viewport: Self.column) == RDimension.blurTranscriptTopMax)
        #expect(edges.radius(line: CGRect(x: 0, y: 505, width: 10, height: 8), viewport: Self.column) == RDimension.blurTranscriptBottomMax)
    }

    @Test("the blur eases: full only near the edge, sharp at each band's inner edge")
    func edgesEase() {
        let edges = TranscriptEdges()
        #expect(edges.strength(mid: 10, viewport: Self.column) == 1)
        #expect(edges.strength(mid: RDimension.blurTranscriptTopBand, viewport: Self.column) == 0)
        #expect(edges.strength(mid: Self.column - RDimension.blurTranscriptBottomBand, viewport: Self.column) == 0)
        #expect(edges.strength(mid: Self.column - 5, viewport: Self.column) == 1)
        #expect(edges.radius(line: .zero, viewport: nil) == 0)
    }

    @Test("Reduce Transparency: no line blurs (the sheet tint carries the edges)")
    func reduceTransparencyBlursNothing() {
        let edges = TranscriptEdges(reduceTransparency: true)
        #expect(Self.middles.allSatisfy { edges.strength(mid: $0, viewport: Self.column) == 0 })
    }

    @Test("on a short phone the smaller bands blur less of the column")
    func compactBands() {
        let regular = TranscriptEdges()
        let compact = TranscriptEdges(compact: true)
        #expect(compact.strength(mid: 70, viewport: Self.column) == 0)
        #expect(regular.strength(mid: 70, viewport: Self.column) > 0)
    }
}
