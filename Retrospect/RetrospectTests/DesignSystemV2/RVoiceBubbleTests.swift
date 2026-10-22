@testable import Retrospect
import Testing

/// C30.3: the played bars follow playback and never run ahead of it; the length reads as a
/// figure on the bubble and as words to VoiceOver.
struct RVoiceBubbleTests {
    @Test("a bar darkens only once playback has passed it")
    func playedBarsFollowPlayback() {
        #expect(RVoiceBubble.playedBars(progress: 0, count: 16) == 0)
        #expect(RVoiceBubble.playedBars(progress: 0.49, count: 16) == 7)
        #expect(RVoiceBubble.playedBars(progress: 0.5, count: 16) == 8)
        #expect(RVoiceBubble.playedBars(progress: 1, count: 16) == 16)
    }

    @Test("progress outside 0…1 is clamped")
    func playedBarsClamped() {
        #expect(RVoiceBubble.playedBars(progress: -1, count: 16) == 0)
        #expect(RVoiceBubble.playedBars(progress: 3, count: 16) == 16)
    }

    @Test("the length shows minutes and two-place seconds")
    func lengthFigure() {
        #expect(RVoiceBubble.length(seconds: 102) == "1:42")
        #expect(RVoiceBubble.length(seconds: 65.9) == "1:05")
        #expect(RVoiceBubble.length(seconds: 7) == "0:07")
        #expect(RVoiceBubble.length(seconds: -3) == "0:00")
    }

    @Test("VoiceOver hears the length in words")
    func spokenLength() {
        #expect(RVoiceBubble.spokenLength(seconds: 102) == "1 minute 42")
        #expect(RVoiceBubble.spokenLength(seconds: 12) == "12 seconds")
        #expect(RVoiceBubble.spokenLength(seconds: 120) == "2 minutes")
        #expect(RVoiceBubble.spokenLength(seconds: 125) == "2 minutes 5")
    }

    @Test("Paper's resting shape has sixteen bars within the box")
    func restingShape() {
        #expect(RVoiceBubble.restingLevels.count == 16)
        #expect(RVoiceBubble.restingLevels.allSatisfy { $0 > 0 && $0 <= 1 })
    }
}
