import Network
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ReachabilityTests {
    @Test("only a satisfied path is online")
    func onlyASatisfiedPathIsOnline() {
        #expect(Backend.PathReachability.isOnline(.satisfied))
        #expect(!Backend.PathReachability.isOnline(.unsatisfied))
        #expect(!Backend.PathReachability.isOnline(.requiresConnection))
    }

    @Test("reachability publishes the current value, then each change once")
    func reachabilityPublishesChanges() async {
        let reachability = Backend.PathReachability(monitor: nil)
        await reachability.receive(.satisfied)
        var changes = reachability.changes().makeAsyncIterator()

        #expect(await changes.next() == true)
        await reachability.receive(.unsatisfied)
        await reachability.receive(.requiresConnection)
        await reachability.receive(.satisfied)

        #expect(await changes.next() == false)
        #expect(await changes.next() == true)
        #expect(await reachability.isOnline)
    }

    @Test("monitor updates are applied in the order they arrive")
    func monitorUpdatesAreAppliedInOrder() async {
        let reachability = Backend.PathReachability(monitor: nil)
        var changes = reachability.changes().makeAsyncIterator()
        #expect(await changes.next() == true)
        let sent = (0 ..< 200).map { $0.isMultiple(of: 2) ? NWPath.Status.unsatisfied : .satisfied } + [.unsatisfied]

        sent.forEach(reachability.enqueue)

        var seen: [Bool] = []
        for _ in sent {
            if let value = await changes.next() {
                seen.append(value)
            }
        }
        #expect(seen == sent.map(Backend.PathReachability.isOnline))
        #expect(await reachability.isOnline == false)
    }
}
