import Foundation
@testable import Retrospect
import Testing

/// Records every command; its state is whatever the test says.
@MainActor @Observable
private final class TransportSpy: Flows.Playback {
    var item: Flows.PlaybackItem?
    var state: Flows.PlaybackState
    var position: Double = 0
    var duration: Double?
    var buffered: Double? {
        nil
    }

    var currentPart: Int? {
        nil
    }

    var rate: Double = 1
    private(set) var commands: [String] = []

    init(state: Flows.PlaybackState, duration: Double? = 130) {
        self.state = state
        self.duration = duration
    }

    func load(_: Flows.PlaybackItem) async {}
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func seek(to seconds: Double) { commands.append("seek \(seconds)") }
    func skip(by seconds: Double) { commands.append("skip \(seconds)") }
}

@MainActor
struct RTransportTests {
    @Test("the glyph follows the player's state: pause only while it says playing")
    func glyphFollowsState() {
        #expect(RTransport.look(for: .playing).well == .pause)
        for state in [Flows.PlaybackState.idle, .paused, .buffering, .offline] {
            #expect(RTransport.look(for: state).well == .play, "\(state)")
        }
        #expect(RTransport.look(for: .ended).well == .retry)
        #expect(RTransport.look(for: .failed(Flows.Failure(.network))).well == .retry)
        #expect(RTransport.look(for: .buffering).buffering)
        #expect(!RTransport.look(for: .playing).buffering)
    }

    @Test("a tap on the well asks the player and never draws the answer itself")
    func wellAsksThePlayer() {
        let spy = TransportSpy(state: .paused)
        RTransport.perform(.well, on: spy)
        #expect(spy.commands == ["play"])
        #expect(spy.state == .paused, "still paused until the player says otherwise")
        #expect(RTransport.look(for: spy.state).well == .play)
        spy.state = .buffering
        RTransport.perform(.well, on: spy)
        spy.state = .playing
        RTransport.perform(.well, on: spy)
        #expect(spy.commands == ["play", "pause", "pause"])
    }

    @Test("ended: play again with forward disabled; failed: retry and the line; offline: skips disabled and the line")
    func disabledStates() {
        let ended = RTransport.look(for: .ended)
        #expect(ended.wellLabel == "play again")
        #expect(!ended.forwardEnabled)
        #expect(ended.backEnabled)
        #expect(ended.line == nil)

        let failed = RTransport.look(for: .failed(Flows.Failure(.network)))
        #expect(failed.line == .failed)
        #expect(failed.line?.text == "couldn't load this brief")
        #expect(!failed.backEnabled && !failed.forwardEnabled)

        let offline = RTransport.look(for: .offline)
        #expect(offline.line?.text == "offline · it'll play when you're back online")
        #expect(!offline.backEnabled && !offline.forwardEnabled)

        let playing = RTransport.look(for: .playing)
        #expect(playing.backEnabled && playing.forwardEnabled && playing.line == nil)
    }

    @Test("rapid taps queue one skip per tap, no more")
    func rapidTaps() {
        let spy = TransportSpy(state: .playing)
        for _ in 0 ..< 5 {
            RTransport.perform(.forward, on: spy)
        }
        RTransport.perform(.back, on: spy)
        #expect(spy.commands == Array(repeating: "skip 30.0", count: 5) + ["skip -15.0"])
    }

    @Test("forward is 15 under a minute, 30 otherwise (and when the length is unknown)")
    func forwardStep() {
        #expect(RTransport.forwardStep(duration: 45) == 15)
        #expect(RTransport.forwardStep(duration: 60) == 30)
        #expect(RTransport.forwardStep(duration: nil) == 30)
        let short = TransportSpy(state: .paused, duration: 45)
        RTransport.perform(.forward, on: short)
        #expect(short.commands == ["skip 15.0"])
    }

    @Test("speed cycles the player's rate and reads as Paper draws it")
    func speed() {
        let spy = TransportSpy(state: .playing)
        #expect(RTransport.speedWords(spy.rate) == "1.0\u{00D7}")
        var seen: [Double] = []
        for _ in RTransport.speeds {
            RTransport.perform(.speed, on: spy)
            seen.append(spy.rate)
        }
        #expect(seen == [1.2, 1.5, 2, 0.8, 1])
        #expect(RTransport.speedWords(1.2) == "1.2\u{00D7}")
        #expect(RTransport.nextRate(after: 1.75) == 1, "an unknown rate starts the cycle again")
    }
}
