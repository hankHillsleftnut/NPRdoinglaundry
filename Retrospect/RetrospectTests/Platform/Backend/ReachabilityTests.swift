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

    @Test("the real monitor starts and reports a value without blocking")
    func theRealMonitorStarts() async {
        let reachability = Backend.PathReachability()
        var changes = reachability.changes().makeAsyncIterator()
        #expect(await changes.next() != nil)
    }
}
