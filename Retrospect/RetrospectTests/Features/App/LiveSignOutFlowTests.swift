@testable import Retrospect
import Testing

/// APP-ROOT: Log Out on the real platform's terms. Unsent words go first; only an explicit "sign out anyway"
/// erases them (the founder's decision), and cancelling changes nothing.
@MainActor
struct LiveSignOutFlowTests {
    private final class World {
        var unsent: Int
        var waiting: Int?
        var online = true
        var tooOld = false
        var sendsPerDrain = 1
        var logOuts: [Bool] = []
        var drains = 0
        var outcome: Platform.AppEnvironment.LogOutResult = .signedOut

        init(unsent: Int, waiting: Int? = nil) {
            self.unsent = unsent
            self.waiting = waiting ?? unsent
        }
    }

    private func flow(_ world: World) -> LiveSignOutFlow {
        let ports = LiveSignOutFlow.Ports(
            unsent: { world.unsent },
            waiting: { world.waiting },
            drain: {
                world.drains += 1
                guard world.online, !world.tooOld else { return }
                let sent = min(world.sendsPerDrain, world.waiting ?? 0)
                world.waiting = world.waiting.map { $0 - sent }
                world.unsent -= sent
            },
            isOnline: { world.online },
            updateRequired: { world.tooOld },
            logOut: { confirmed in
                world.logOuts.append(confirmed)
                if confirmed {
                    return .signedOut
                }
                return world.unsent > 0 ? .hasUnsent(world.unsent) : world.outcome
            },
            sleep: { _ in await Task.yield() }
        )
        return LiveSignOutFlow(ports: ports, unsent: world.unsent)
    }

    private func settle(_ flow: LiveSignOutFlow, until done: (SignOutState) -> Bool) async {
        for _ in 0 ..< 400 where !done(flow.state) {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    @Test("nothing waiting: signs out at once, without asking the platform to erase")
    func nothingWaiting() async {
        let world = World(unsent: 0)
        let flow = flow(world)
        flow.begin()
        await settle(flow) { $0 == .done }
        #expect(flow.state == .done)
        #expect(world.logOuts == [false])
    }

    @Test("unsent words are sent first, then the session ends, still without erasing")
    func sendsFirst() async {
        let world = World(unsent: 2)
        let flow = flow(world)
        flow.begin()
        await settle(flow) { $0 == .done }
        #expect(flow.state == .done)
        #expect(world.drains >= 2)
        #expect(world.unsent == 0)
        #expect(world.logOuts == [false], "an unconfirmed log out: the platform would have refused had words been left")
    }

    @Test("offline: stuck with the reason and the count; nothing is signed out or erased")
    func offlineIsStuck() async {
        let world = World(unsent: 3)
        world.online = false
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 3, reason: .offline))
        #expect(world.logOuts.isEmpty)
    }

    @Test("a build that is too old says update, and never signs out by itself")
    func tooOld() async {
        let world = World(unsent: 1)
        world.tooOld = true
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 1, reason: .updateRequired))
        #expect(world.logOuts.isEmpty)
    }

    @Test("refused entries (nothing waiting to send) are stuck at once, not after eight tries")
    func refusedRowsStopTheLoop() async {
        let world = World(unsent: 1, waiting: 0)
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 1, reason: .failed))
        #expect(world.drains == 1)
    }

    @Test("only 'sign out anyway' erases, and only from stuck")
    func anywayIsTheOnlyErase() async {
        let world = World(unsent: 2)
        world.online = false
        let flow = flow(world)
        flow.signOutAnyway() // not stuck: ignored
        #expect(world.logOuts.isEmpty)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(world.logOuts.isEmpty)
        flow.signOutAnyway()
        await settle(flow) { $0 == .done }
        #expect(flow.state == .done)
        #expect(world.logOuts == [true])
    }

    @Test("cancelling while stuck keeps everything and returns to the question")
    func cancelKeeps() async {
        let world = World(unsent: 2)
        world.online = false
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        flow.cancel()
        #expect(flow.state == .asking(unsent: 2))
        #expect(world.logOuts.isEmpty)
    }

    @Test("words that arrive while signing out make it stuck rather than erase them")
    func lateWordsAreNotErased() async {
        let world = World(unsent: 0)
        world.outcome = .hasUnsent(1)
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 1, reason: .failed))
        #expect(world.logOuts == [false])
    }

    @Test("an unreadable count is not 'nothing waiting': it keeps trying, then says stuck, never offers a quiet erase")
    func unreadableCountKeepsTrying() async {
        let world = World(unsent: 2)
        world.waiting = nil
        world.online = true
        world.sendsPerDrain = 0
        let flow = flow(world)
        flow.begin()
        await settle(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 2, reason: .failed))
        #expect(world.drains == LiveSignOutFlow.attempts, "it tried every time instead of giving up on the first read error")
        #expect(world.logOuts.isEmpty)
    }
}
