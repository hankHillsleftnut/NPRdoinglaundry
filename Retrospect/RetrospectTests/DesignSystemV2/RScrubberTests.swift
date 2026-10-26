import CoreGraphics
import Foundation
@testable import Retrospect
import Testing

/// Records every command; plays nothing.
@MainActor @Observable
private final class SpyPlayback: Flows.Playback {
    var item: Flows.PlaybackItem?
    var state: Flows.PlaybackState = .paused
    var position: Double = 0
    var duration: Double?
    var buffered: Double? {
        nil
    }

    var currentPart: Int? {
        nil
    }

    var rate: Double = 1
    private(set) var seeks: [Double] = []
    private(set) var skips: [Double] = []
    private(set) var plays = 0
    private(set) var pauses = 0

    init(duration: Double = 130) {
        self.duration = duration
    }

    func load(_ item: Flows.PlaybackItem) async { self.item = item }
    func play() { plays += 1 }
    func pause() { pauses += 1 }
    func seek(to seconds: Double) { seeks.append(seconds) }
    func skip(by seconds: Double) { skips.append(seconds) }
}

@MainActor
struct RScrubberTests {
    /// 130 s over three parts (0, 48, 90) on a 308 track: 300 of time, two 4pt gaps.
    private let math = ScrubberMath(width: 308, duration: 130, partStarts: [0, 48, 90])

    @Test("one capsule per part, gaps excluded from time; under a minute is one capsule")
    func segments() {
        #expect(math.segments.count == 3)
        let total = math.segments.reduce(0) { $0 + $1.width }
        #expect(abs(total - 300) < 0.001)
        #expect(abs(math.segments[1].x - (math.segments[0].width + 4)) < 0.001)
        let short = ScrubberMath(width: 308, duration: 45, partStarts: [0, 25])
        #expect(short.segments.count == 1)
        #expect(short.segments[0].width == 308)
        #expect(short.partStarts == [0, 25], "parts still tick under a minute")
    }

    @Test("a fraction maps to the thumb x across parts with gaps, and x maps back to the same time", arguments: [0.0, 10, 47.9, 48, 60, 89.99, 90, 129, 130])
    func inverse(time: Double) {
        let x = math.x(at: time)
        #expect(abs(math.time(at: x) - time) < 0.001)
        #expect(abs(math.fraction(at: math.x(atFraction: time / 130)) - time / 130) < 0.0001)
    }

    @Test("a time at a part's start sits after the gap, not inside it (no drift at boundaries)")
    func boundaries() {
        let start = math.x(at: 48)
        let endOfFirst = math.x(at: 47.999)
        #expect(start - endOfFirst > 3.9)
        // the gap is no time: anywhere in it is the boundary itself
        #expect(math.time(at: endOfFirst + 1) == 48)
        #expect(math.time(at: start - 1) == 48)
        #expect(math.part(at: math.time(at: start - 1)) == 1)
    }

    @Test("within 12pt of a part's start the scrub lands on it; further away it doesn't")
    func snap() {
        let start = math.x(at: 48)
        #expect(math.snapped(math.time(at: start + 11)) == 48)
        #expect(math.snapped(math.time(at: start - 11)) == 48)
        let away = math.time(at: start + 13)
        #expect(math.snapped(away) == away)
    }

    @Test("vertical offset slows the scrub: halves past 50pt, quarters past 100pt", arguments: [
        (CGFloat(0), CGFloat(1)), (40, 1), (60, 0.5), (-60, 0.5), (100, 0.5), (120, 0.25),
    ])
    func rate(offset: CGFloat, expected: CGFloat) {
        #expect(ScrubberMath.rate(forVerticalOffset: offset) == expected)
    }

    @Test("dragging 60pt off the line moves the thumb half as far as the finger")
    func fineScrub() {
        var drag = ScrubDrag(math: math, finger: CGPoint(x: 20, y: 0))
        _ = drag.move(to: CGPoint(x: 60, y: 60))
        #expect(abs(drag.x - 40) < 0.001)
    }

    @Test("crossing two parts in one move ticks twice; back across one ticks once")
    func ticks() {
        let scrub = ScrubController()
        scrub.touch(at: CGPoint(x: 10, y: 0), now: CGPoint(x: 10, y: 0), math: math)
        #expect(scrub.ticks == 0)
        scrub.touch(at: CGPoint(x: 10, y: 0), now: CGPoint(x: 290, y: 0), math: math)
        #expect(scrub.ticks == 2)
        scrub.touch(at: CGPoint(x: 10, y: 0), now: CGPoint(x: 200, y: 0), math: math)
        #expect(scrub.ticks == 3)
        var paid = 0
        while scrub.payTick() {
            paid += 1
        }
        #expect(paid == 3, "one haptic per part crossed, no more")
    }

    @Test("no seek while dragging: the one seek comes on release, at the thumb's time")
    func seeksOnlyOnRelease() {
        let spy = SpyPlayback()
        let scrub = ScrubController()
        for x in stride(from: CGFloat(10), through: 250, by: 20) {
            scrub.touch(at: CGPoint(x: 10, y: 0), now: CGPoint(x: x, y: 0), math: math)
            #expect(spy.seeks.isEmpty)
        }
        #expect(scrub.isHeld)
        let expected = scrub.heldTime
        scrub.release(seeking: spy)
        #expect(spy.seeks.count == 1)
        #expect(spy.seeks.first == expected)
        #expect(!scrub.isHeld)
        scrub.release(seeking: spy)
        #expect(spy.seeks.count == 1, "a second release seeks nothing")
    }

    @Test("a tap on the track is a hold and a release: one seek there")
    func tap() {
        let spy = SpyPlayback()
        let scrub = ScrubController()
        scrub.touch(at: CGPoint(x: 150, y: 0), now: CGPoint(x: 150, y: 0), math: math)
        scrub.release(seeking: spy)
        #expect(spy.seeks.count == 1)
        #expect(abs((spy.seeks.first ?? 0) - math.snapped(math.time(at: 150))) < 0.001)
    }

    @Test("times read as Paper draws them, with a true minus; VoiceOver hears whole words")
    func words() {
        #expect(ScrubberWords.clock(48) == "00:48")
        #expect(ScrubberWords.remaining(202) == "\u{2212}03:22")
        #expect(ScrubberWords.clock(3725) == "1:02:05")
        #expect(ScrubberWords.partName(0, of: 3, title: nil) == "1 of 3")
        #expect(ScrubberWords.partName(0, of: 3, title: "the article") == "1 of 3 · the article")
        #expect(ScrubberWords.spoken(position: 252, duration: 690, part: 1, parts: 3) == "4 minutes 12 seconds of 11 minutes 30, part 2 of 3")
        #expect(ScrubberWords.spoken(position: 61, duration: 40, part: 0, parts: 1) == "1 minute 1 second of 40 seconds")
    }

    @Test("a titled label is the chapter's title alone (ON-11 26OI-0); nothing when it has no title; counted stays as it was")
    func titledPartLabel() {
        #expect(ScrubberWords.partName(1, of: 4, title: "the first thing i noticed", style: .title) == "the first thing i noticed")
        #expect(ScrubberWords.partName(0, of: 4, title: nil, style: .title) == "", "no invented \"1 of 4\"")
        #expect(ScrubberWords.partName(1, of: 4, title: "the article", style: .counted) == "2 of 4 · the article")
    }
}
