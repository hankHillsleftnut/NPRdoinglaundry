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

    // Paper 1FV9-0's column is 513 tall; its five lines sit at 24, 102, 209, 316 and 394 (1FWZ-0 … 1FWV-0),
    // 58, 87, 87, 58 and 58 tall.
    private static let column: CGFloat = 513
    private static let lines: [CGRect] = [(24, 58), (102, 87), (209, 87), (316, 58), (394, 58)].map {
        CGRect(x: 0, y: $0.0, width: 346, height: $0.1)
    }

    @Test("at rest, as Paper draws it: the first and last lines soften only toward the edge, the middle three are sharp")
    func edgesSoftenOnlyTowardTheEdge() throws {
        let edges = TranscriptEdges()
        let first = edges.softness(line: Self.lines[0], viewport: Self.column)
        let last = edges.softness(line: Self.lines[4], viewport: Self.column)
        // the first line: soft at its top, its bottom row nearly sharp (readable)
        #expect(try #require(first.first) == 1)
        #expect(try #require(first.last) < 0.3)
        // the last line: its top row nearly sharp, soft toward the bottom edge
        #expect(try #require(last.first) < 0.3)
        #expect(try #require(last.last) == 1)
        // the softness falls off down the first line and rises down the last, never jumps
        #expect(first == first.sorted(by: >))
        #expect(last == last.sorted())
        // the middle three stay sharp (the fourth's last pixel grazes the bottom band by 1pt in Paper too)
        #expect(Self.lines[1 ... 3].allSatisfy { (edges.softness(line: $0, viewport: Self.column).max() ?? 0) < 0.05 })
        // the blurred copy is the band's 8; the mask does the easing
        #expect(edges.radius(line: Self.lines[0], viewport: Self.column) == RDimension.blurTranscriptTopMax)
        #expect(edges.radius(line: Self.lines[4], viewport: Self.column) == RDimension.blurTranscriptBottomMax)
    }

    @Test("the line being read never softens, wherever it sits (QA batch 6: tease-ended, SE, AX3)")
    func currentLineStaysSharp() {
        let edges = TranscriptEdges()
        #expect(edges.softness(line: Self.lines[0], viewport: Self.column, isCurrent: true).isEmpty)
        #expect(edges.softness(line: Self.lines[4], viewport: Self.column, isCurrent: true).isEmpty)
        #expect(edges.stops(line: Self.lines[4], viewport: Self.column, isCurrent: true).isEmpty)
    }

    @Test("the masks run the whole line, top to bottom, one stop per sample")
    func masksCoverTheLine() {
        let edges = TranscriptEdges()
        let soft = edges.stops(line: Self.lines[0], viewport: Self.column)
        let sharp = edges.stops(line: Self.lines[0], viewport: Self.column, sharp: true)
        #expect(soft.count == TranscriptEdges.samples + 1)
        #expect(soft.map(\.location) == sharp.map(\.location))
        #expect(soft.first?.location == 0)
        #expect(soft.last?.location == 1)
    }

    @Test("the sheet colour rises over the soft part toward each edge, as Paper's bands lay it, and clears inside")
    func fadeTowardTheEdges() {
        let edges = TranscriptEdges()
        #expect(edges.fade(y: 0, viewport: Self.column) == 1)
        #expect(edges.fade(y: Self.column, viewport: Self.column) == 1)
        #expect(edges.fade(y: RDimension.blurTranscriptTopBand, viewport: Self.column) == 0)
        #expect(edges.fade(y: Self.column / 2, viewport: Self.column) == 0)
        #expect(edges.fade(y: 48, viewport: Self.column) == 0.5)
    }

    @Test("the ramp: full only near the edge, sharp at each band's inner edge")
    func edgesEase() {
        let edges = TranscriptEdges()
        #expect(edges.strength(y: 10, viewport: Self.column) == 1)
        #expect(edges.strength(y: RDimension.blurTranscriptTopBand, viewport: Self.column) == 0)
        #expect(edges.strength(y: Self.column - RDimension.blurTranscriptBottomBand, viewport: Self.column) == 0)
        #expect(edges.strength(y: Self.column - 5, viewport: Self.column) == 1)
    }

    @Test("Reduce Transparency: no line softens (the sheet tint carries the edges)")
    func reduceTransparencySoftensNothing() {
        let edges = TranscriptEdges(reduceTransparency: true)
        #expect(Self.lines.allSatisfy { edges.softness(line: $0, viewport: Self.column).isEmpty })
    }

    @Test("on a short phone the smaller bands soften less of the column")
    func compactBands() {
        #expect(TranscriptEdges(compact: true).strength(y: 70, viewport: Self.column) == 0)
        #expect(TranscriptEdges().strength(y: 70, viewport: Self.column) > 0)
    }
}
