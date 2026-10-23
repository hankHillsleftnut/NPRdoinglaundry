import AVFoundation
import Foundation
@testable import Retrospect
import Testing

@MainActor
private final class FakeEngine: Platform.Media.Engine {
    let events: AsyncStream<Platform.Media.EngineEvent>
    let feed: AsyncStream<Platform.Media.EngineEvent>.Continuation
    private(set) var loaded: [URL] = []
    private(set) var playedAt: [Double] = []
    private(set) var pauses = 0
    private(set) var clears = 0
    private(set) var seeks: [Double] = []
    private(set) var rates: [Double] = []

    init() {
        (events, feed) = AsyncStream.makeStream(of: Platform.Media.EngineEvent.self, bufferingPolicy: .unbounded)
    }

    func replaceItem(with url: URL) { loaded.append(url) }
    func play(rate: Double) { playedAt.append(rate) }
    func pause() { pauses += 1 }
    func setRate(_ rate: Double) { rates.append(rate) }
    func seek(to seconds: Double) async { seeks.append(seconds) }
    func clear() { clears += 1 }
}

@MainActor
private final class FakeSession: Platform.Media.AudioSession {
    let interruptions: AsyncStream<Platform.Media.InterruptionEvent>
    let routeLosses: AsyncStream<Void>
    let mediaServicesResets: AsyncStream<Void>
    let interrupt: AsyncStream<Platform.Media.InterruptionEvent>.Continuation
    let route: AsyncStream<Void>.Continuation
    let reset: AsyncStream<Void>.Continuation
    private(set) var prepares = 0
    private(set) var activations = 0
    private(set) var deactivations = 0
    var failing: Step?

    enum Step { case prepare, activate }
    struct Broken: Error {}

    init() {
        (interruptions, interrupt) = AsyncStream.makeStream(of: Platform.Media.InterruptionEvent.self, bufferingPolicy: .unbounded)
        (routeLosses, route) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .unbounded)
        (mediaServicesResets, reset) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .unbounded)
    }

    func prepare() throws {
        prepares += 1
        if failing == .prepare {
            throw Broken()
        }
    }

    func activate() throws {
        activations += 1
        if failing == .activate {
            throw Broken()
        }
    }

    func deactivate() { deactivations += 1 }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LivePlaybackTests {
    private let engine = FakeEngine()
    private let session = FakeSession()
    private let log = Platform.Log.Recorder()
    private let clock = TestClock()
    private let center = NotificationCenter()
    private let file = URL(fileURLWithPath: "/tmp/brief.mp3")

    private func item(id: String = "b1", duration: Double? = 90) -> Flows.PlaybackItem {
        Flows.PlaybackItem(
            id: id, kind: .brief, title: "today's brief",
            parts: [
                .init(id: 0, title: nil, text: "one", startSeconds: 0),
                .init(id: 1, title: nil, text: "two", startSeconds: 30),
                .init(id: 2, title: nil, text: "three", startSeconds: 60),
            ],
            durationSeconds: duration
        )
    }

    private func player(resolve: Platform.Media.LivePlayback.Resolve? = nil) -> Platform.Media.LivePlayback {
        let url = file
        return Platform.Media.LivePlayback(
            engine: engine, session: session, resolve: resolve ?? { _, _ in url }, log: log, clock: clock, notifications: center
        )
    }

    /// Lets the player's watching tasks run.
    private func settle(_ condition: () -> Bool = { false }) async {
        for _ in 0 ..< 200 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    private func playing(_ player: Platform.Media.LivePlayback) async {
        await player.load(item())
        player.play()
        engine.feed.yield(.playing)
        await settle { player.state == .playing }
    }

    @Test("play never says playing by itself: buffering, then playing, only when the engine says so")
    func stateComesFromTheEngine() async {
        let p = player()
        await p.load(item())
        #expect(p.state == .paused)

        p.play()
        #expect(p.state == .paused, "asked to play, nothing audible yet")
        engine.feed.yield(.buffering)
        await settle { p.state == .buffering }
        #expect(p.state == .buffering)
        engine.feed.yield(.playing)
        await settle { p.state == .playing }
        #expect(p.state == .playing)
    }

    @Test("a phone call pauses, and its end never resumes on its own, even when the system says it may")
    func interruptionsNeverResume() async {
        let p = player()
        await playing(p)

        session.interrupt.yield(.began)
        await settle { p.state == .paused }
        #expect(p.state == .paused)

        session.interrupt.yield(.ended(shouldResume: true))
        await settle()
        #expect(p.state == .paused)
        #expect(engine.playedAt.count == 1, "only the person's tap played")
    }

    @Test("losing the headphone route pauses")
    func routeLossPauses() async {
        let p = player()
        await playing(p)

        session.route.yield()
        await settle { p.state == .paused }

        #expect(p.state == .paused)
    }

    @Test("starting a recording pauses playback and nothing resumes it")
    func recordingPauses() async {
        let p = player()
        await playing(p)

        center.post(name: Platform.Media.recordingStarted, object: nil)
        await settle { p.state == .paused }

        #expect(p.state == .paused)
        #expect(engine.playedAt.count == 1)
    }

    @Test("the session is set before every play, taken at the first play and not before")
    func sessionIsPreparedBeforeEveryPlay() async {
        let p = player()
        await p.load(item())
        #expect(session.prepares == 0 && session.activations == 0, "not at load, not at launch")

        p.play()
        p.pause()
        p.play()

        #expect(session.prepares == 2)
        #expect(session.activations == 1)
    }

    @Test("a session that can't be prepared or activated fails the player and says so in the log, never silently")
    func sessionFailuresAreVisible() async {
        session.failing = .prepare
        let a = player()
        await a.load(item())
        a.play()
        #expect(a.state == .failed(Flows.Failure(.unknown)))
        #expect(engine.playedAt.isEmpty)

        session.failing = .activate
        a.play()
        #expect(log.events == [.playbackTrouble(.sessionPrepare), .playbackTrouble(.sessionActivate)])
    }

    @Test("the session is given back after five minutes of pause, not before, and a play in between keeps it")
    func sessionIsReleasedAfterAPause() async {
        let p = player()
        await playing(p)
        p.pause()
        await settle { clock.pendingSleeps == 1 }

        clock.advance(by: .seconds(299))
        await settle()
        #expect(session.deactivations == 0)

        p.play()
        clock.advance(by: .seconds(10))
        await settle()
        #expect(session.deactivations == 0, "playing again cancelled the release")

        p.pause()
        await settle { clock.pendingSleeps == 1 }
        clock.advance(by: .seconds(300))
        await settle { session.deactivations == 1 }
        #expect(session.deactivations == 1)
    }

    @Test("seeking past the end ends playback; skipping is clamped to the audio")
    func seekingPastTheEnd() async {
        let p = player()
        await playing(p)
        engine.feed.yield(.duration(90))
        await settle { p.duration == 90 }

        p.skip(by: -15)
        #expect(p.position == 0, "clamped at the start")
        p.seek(to: 45)
        #expect(p.position == 45)
        p.skip(by: 30)
        #expect(p.position == 75)
        p.seek(to: 500)
        #expect(p.state == .ended)
        #expect(p.position == 90)
    }

    @Test("the current part follows the position across part starts")
    func currentPartFollowsPosition() async {
        let p = player()
        await p.load(item())
        #expect(p.currentPart == 0)
        for (second, part) in [(29.9, 0), (30, 1), (59, 1), (60, 2), (400, 2)] {
            engine.feed.yield(.time(second))
            await settle { p.position == second }
            #expect(p.currentPart == part, "at \(second)")
        }
    }

    @Test("a rate change reaches the engine, is clamped, and the next play uses it")
    func rateSurvivesPauseAndPlay() async {
        let p = player()
        await playing(p)

        p.rate = 1.5
        p.pause()
        p.play()
        p.rate = 9

        #expect(engine.rates == [1.5, 2])
        #expect(engine.playedAt == [1, 1.5])
        #expect(p.rate == 2)
    }

    @Test("a failed item reports failed and is never playing")
    func failedItem() async {
        let p = player()
        await playing(p)

        engine.feed.yield(.failed)
        await settle { p.state != .playing }

        #expect(p.state == .failed(Flows.Failure(.network)))
        #expect(log.events == [.playbackTrouble(.itemFailed)])
    }

    @Test("with no network and no file the state is offline, and a tap on play tries again")
    func offlineThenRetry() async {
        let online = Flag()
        let p = player(resolve: { [file] _, _ in
            if online.value {
                return file
            }
            throw Platform.Media.Source.Failure.offline
        })
        await p.load(item())
        #expect(p.state == .offline)

        online.value = true
        p.play()
        await settle { engine.playedAt.count == 1 }

        #expect(engine.loaded == [file])
        #expect(engine.playedAt == [1])
    }

    @Test("a brief that can't be fetched fails with a logged trouble, not a hang")
    func unavailable() async {
        let p = player(resolve: { _, _ in throw Platform.Media.Source.Failure.unavailable })
        await p.load(item())

        #expect(p.state == .failed(Flows.Failure(.unknown)))
        #expect(log.events == [.playbackTrouble(.couldNotLoad)])
    }

    @Test("loading another item replaces the first for good: a slow earlier load never lands")
    func newerLoadWins() async {
        let gate = LoadGate()
        let second = URL(fileURLWithPath: "/tmp/second.mp3")
        let p = player(resolve: { item, _ in
            if item.id == "slow" {
                await gate.wait()
                return URL(fileURLWithPath: "/tmp/slow.mp3")
            }
            return second
        })
        let slow = Task { await p.load(item(id: "slow")) }
        await settle { p.item?.id == "slow" }
        await p.load(item(id: "fast"))
        gate.open()
        await slow.value

        #expect(p.item?.id == "fast")
        #expect(engine.loaded == [second], "the slow item never reached the engine")
    }

    @Test("unload leaves nothing loaded and gives the session back")
    func unloadClearsEverything() async {
        let p = player()
        await playing(p)
        engine.feed.yield(.time(12))
        await settle { p.position == 12 }

        p.unload()

        #expect(p.item == nil && p.state == .idle && p.position == 0 && p.duration == nil)
        #expect(session.deactivations == 1)
        #expect(engine.clears >= 1)
    }

    @Test("after the system rebuilds audio, the item comes back where it was, paused")
    func mediaServicesReset() async {
        let p = player()
        await playing(p)
        engine.feed.yield(.time(42))
        await settle { p.position == 42 }

        session.reset.yield()
        await settle { engine.loaded.count == 2 && engine.seeks.contains(42) }

        #expect(engine.loaded.count == 2)
        #expect(engine.seeks.last == 42)
        #expect(p.state == .paused)
        #expect(p.position == 42)
    }

    @Test("events from before anything was loaded change nothing")
    func eventsWithoutAnItemAreIgnored() async {
        let p = player()
        engine.feed.yield(.playing)
        engine.feed.yield(.time(5))
        await settle()

        #expect(p.state == .idle && p.position == 0)
    }

    // MARK: The real pieces

    @Test("the real engine reports a failed item for a file that isn't there, and never plays it")
    func realEngineFailsOnMissingFile() async {
        let real = Platform.Media.AVPlayerEngine()
        var iterator = real.events.makeAsyncIterator()
        real.replaceItem(with: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).mp3"))
        var failed = false
        for _ in 0 ..< 20 {
            guard let event = await iterator.next() else { break }
            if event == .failed {
                failed = true; break
            }
            #expect(event != .playing)
        }
        #expect(failed)
        real.clear()
    }

    @Test("the system session's interruption userInfo maps to began and ended(shouldResume)")
    func systemInterruptionMapping() {
        let began: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        let ended: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
        ]
        #expect(Platform.Media.SystemAudioSession.interruption(from: began) == .began)
        #expect(Platform.Media.SystemAudioSession.interruption(from: ended) == .ended(shouldResume: true))
        #expect(Platform.Media.SystemAudioSession.interruption(from: [:]) == nil)
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false
    var value: Bool {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private actor LoadGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    nonisolated func open() {
        Task { await release() }
    }

    private func release() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
