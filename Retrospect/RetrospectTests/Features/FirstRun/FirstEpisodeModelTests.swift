import Foundation
import Observation
@testable import Retrospect
import Testing

/// The wall clock the model reads for "slow", set by the test.
private final class TestNow {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }
}

/// A first episode that stays where the test puts it, and counts every refresh.
@MainActor @Observable
private final class HeldFirstEpisode: Flows.FirstEpisode {
    var state: Flows.FirstEpisodeState
    private(set) var refreshes = 0

    init(_ state: Flows.FirstEpisodeState) {
        self.state = state
    }

    func refresh() async {
        refreshes += 1
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FirstEpisodeModelTests {
    private let clock = TestClock()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    private final class Exits {
        var all: [FirstEpisodeModel.Exit] = []
    }

    private let exits = Exits()

    private func make(
        _ source: any Flows.FirstEpisode,
        playback: SamplePlayback? = nil,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_800_000_000) }
    ) -> (FirstEpisodeModel, SamplePlayback) {
        let player = playback ?? SamplePlayback(scenario: .briefPaused, clock: clock)
        let exits = exits
        let model = FirstEpisodeModel(source: source, playback: player, clock: clock, now: now) { exits.all.append($0) }
        return (model, player)
    }

    /// Lets the watch reach its next sleep (or finish) on the test clock.
    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 400 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    /// Moves the clock by `seconds`, waiting for the watch to be asleep first and to act after.
    private func tick(_ seconds: Int, then condition: () -> Bool = { true }) async {
        await settle { clock.pendingSleeps >= 1 }
        clock.advance(by: .seconds(seconds))
        await settle(condition)
    }

    // MARK: Cadence

    @Test("on screen and waiting, the page asks every 10 seconds of the test clock, never sooner")
    func asksEveryTenSeconds() async {
        let source = HeldFirstEpisode(.waiting(since: start))
        let (model, _) = make(source)
        model.appear()
        // at 9 s the watch must still be on its first sleep (a shorter cadence would have asked and slept again)
        await tick(9) { clock.pendingSleeps >= 1 }
        #expect(source.refreshes == 0)
        await tick(1) { source.refreshes == 1 }
        #expect(source.refreshes == 1)
        await tick(10) { source.refreshes == 2 }
        await tick(10) { source.refreshes == 3 }
        #expect(source.refreshes == 3)
        model.leave()
    }

    @Test("a second appear doesn't start a second watch: still one ask per 10 seconds")
    func oneWatchOnly() async {
        let source = HeldFirstEpisode(.waiting(since: start))
        let (model, _) = make(source)
        model.appear()
        model.appear()
        await tick(10) { source.refreshes >= 1 }
        await settle { clock.pendingSleeps >= 1 }
        #expect(source.refreshes == 1)
        #expect(clock.pendingSleeps == 1)
        model.leave()
    }

    @Test("leaving the page stops the asking: the clock moves on and nothing more is asked")
    func stopsOnLeave() async {
        let source = HeldFirstEpisode(.waiting(since: start))
        let (model, _) = make(source)
        model.appear()
        await tick(10) { source.refreshes == 1 }
        model.leave()
        await settle { clock.heldSleeps == 0 }
        #expect(clock.heldSleeps == 0)
        clock.advance(by: .seconds(60))
        await settle { false }
        #expect(source.refreshes == 1)
        #expect(!model.isWatching)
    }

    @Test("coming back after leaving asks again, from a fresh 10 seconds")
    func resumesOnReturn() async {
        let source = HeldFirstEpisode(.waiting(since: start))
        let (model, _) = make(source)
        model.appear()
        await tick(10) { source.refreshes == 1 }
        model.leave()
        model.appear()
        await tick(10) { source.refreshes == 2 }
        #expect(source.refreshes == 2)
        model.leave()
    }

    @Test("once the episode is ready the asking stops")
    func stopsWhenReady() async {
        let source = SampleFirstEpisode(scenario: .becomesReady, now: start)
        let (model, _) = make(source)
        model.appear()
        await tick(10) { source.refreshes == 1 }
        await tick(10) { model.isPlayerLoaded }
        #expect(model.look == .ready)
        await settle { !model.isWatching }
        #expect(!model.isWatching)
        clock.advance(by: .seconds(60))
        await settle { false }
        #expect(source.refreshes == SampleFirstEpisode.refreshesToReady)
    }

    // MARK: Slow

    @Test("the wait turns slow at 15 minutes, not before, and offers the journal")
    func slowAtFifteenMinutes() async {
        let now = TestNow(start)
        let source = HeldFirstEpisode(.waiting(since: start))
        let (model, player) = make(source, now: { now.date })
        model.appear()
        now.date = start.addingTimeInterval(FirstEpisodeModel.slowAfter - 10)
        await tick(10) { source.refreshes == 1 }
        #expect(model.look == .waiting)
        now.date = start.addingTimeInterval(FirstEpisodeModel.slowAfter)
        await tick(10) { model.isSlow }
        #expect(model.look == .slow)
        player.play()
        model.journalTapped()
        #expect(exits.all == [.journal])
        #expect(player.state == .paused)
        #expect(!model.isWatching)
    }

    @Test("a wait that began 16 minutes ago is slow as soon as the page appears")
    func slowOnArrival() async {
        let source = SampleFirstEpisode(scenario: .slow, now: start)
        let (model, _) = make(source)
        // before appear (the page's first frame) and with no await: never a flash of the plain line
        #expect(model.look == .slow)
        model.appear()
        #expect(model.look == .slow)
        await settle { model.isSlow }
        #expect(model.look == .slow)
        model.leave()
    }

    // MARK: Ready

    @Test("ready loads the episode paused: play is offered, nothing plays until the tap, then continue")
    func readyOffersPlayAndContinue() async {
        let source = SampleFirstEpisode(scenario: .ready, now: start)
        let (model, player) = make(source)
        model.appear()
        await settle { model.isPlayerLoaded }
        #expect(model.look == .ready)
        #expect(model.episodeTitle == SampleFirstEpisode.title)
        #expect(player.item?.id == SampleFirstEpisode.item.id)
        #expect(player.state == .paused)
        #expect(RTransport.look(for: player.state).well == .play)
        // nothing plays on its own, however long the page is open
        clock.advance(by: .seconds(30))
        await settle { false }
        #expect(player.state == .paused)
        #expect(player.position == 0)
        model.continueTapped()
        model.continueTapped()
        #expect(exits.all == [.continued])
    }

    @Test("leaving the page pauses the player, so audio never plays without a control on screen")
    func leavingPauses() async {
        let source = SampleFirstEpisode(scenario: .ready, now: start)
        let (model, player) = make(source)
        model.appear()
        await settle { model.isPlayerLoaded }
        player.play()
        #expect(player.state == .buffering)
        model.leave()
        #expect(player.state == .paused)
    }

    @Test("continue pauses the player before the host moves on")
    func continuePauses() async {
        let source = SampleFirstEpisode(scenario: .ready, now: start)
        let (model, player) = make(source)
        model.appear()
        await settle { model.isPlayerLoaded }
        player.play()
        model.continueTapped()
        #expect(player.state == .paused)
        #expect(exits.all == [.continued])
    }

    // MARK: Unavailable

    @Test("an episode without its audio shows the title and continue, and no play control")
    func unavailableHasNoPlay() async {
        let source = SampleFirstEpisode(scenario: .unavailable, now: start)
        let (model, player) = make(source)
        model.appear()
        await settle { !model.isWatching }
        #expect(model.look == .unavailable)
        #expect(model.episodeTitle == SampleFirstEpisode.title)
        // the page draws the scrubber and transport only for a loaded, ready episode
        #expect(!model.isPlayerLoaded)
        #expect(player.item?.id != SampleFirstEpisode.item.id)
        #expect(source.refreshes == 0)
        model.continueTapped()
        #expect(exits.all == [.continued])
    }

    // MARK: VoiceOver

    @Test("VoiceOver hears the turn to slow (both lines), to ready, and an audio-less title; not the plain wait")
    func announcesTheTurn() {
        let title = SampleFirstEpisode.title
        #expect(FirstEpisodeModel.announcement(for: .waiting, title: nil) == nil)
        let slow = FirstEpisodeModel.announcement(for: .slow, title: nil)
        #expect(slow?.contains(FirstEpisodeModel.slowLine) == true)
        #expect(slow?.contains(FirstEpisodeModel.slowDescription) == true)
        #expect(FirstEpisodeModel.announcement(for: .ready, title: title) == FirstEpisodeModel.readyLine)
        #expect(FirstEpisodeModel.announcement(for: .unavailable, title: title) == title)
    }

    // MARK: Privacy

    @Test("a first-episode state written into a line never carries the episode's title")
    func stateNeverPrintsTitle() {
        let ready = SampleFirstEpisode.readyState
        let unavailable = Flows.FirstEpisodeState.unavailable(title: SampleFirstEpisode.title)
        for state in [ready, unavailable, .waiting(since: start)] {
            let printed = "\(state)"
            let reflected = String(reflecting: state)
            #expect(!printed.contains(SampleFirstEpisode.title))
            #expect(!reflected.contains(SampleFirstEpisode.title))
        }
        #expect("\(ready)" == "ready")
        #expect("\(unavailable)" == "unavailable")
    }
}
