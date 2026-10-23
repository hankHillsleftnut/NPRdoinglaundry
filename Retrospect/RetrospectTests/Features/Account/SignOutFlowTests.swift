@testable import Retrospect
import Testing

/// P33: the sign-out flow as the sheet drives it. Entries that haven't sent go first; "sign out anyway"
/// exists only when stuck and only an explicit call forces it; cancelling loses nothing.
@MainActor
struct SignOutFlowTests {
    /// A clock that waits a real millisecond, so every step happens after a suspension (live timing).
    private static let ticking: @Sendable (Duration) async -> Void = { _ in try? await Task.sleep(for: .milliseconds(5)) }

    private func finish(_ flow: SampleSignOutFlow, until done: @MainActor (SignOutState) -> Bool) async {
        for _ in 0 ..< 200 where !done(flow.state) {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("nothing waiting: signing out goes straight to done, and was not forced")
    func nothingWaiting() async {
        let flow = SampleSignOutFlow(unsent: 0, sleep: Self.ticking)
        #expect(flow.state == .asking(unsent: 0))
        flow.begin()
        await finish(flow) { $0 == .done }
        #expect(flow.state == .done)
        #expect(!flow.forced)
    }

    @Test("unsent entries go first: the count rolls down, then signingOut, then done")
    func sendsThenSignsOut() async {
        let flow = SampleSignOutFlow(unsent: 2, sleep: Self.ticking)
        flow.begin()
        var seen: [SignOutState] = []
        for _ in 0 ..< 400 where flow.state != .done {
            if seen.last != flow.state {
                seen.append(flow.state)
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        #expect(seen.contains(.sending(remaining: 2)))
        #expect(seen.contains(.sending(remaining: 1)))
        #expect(seen.contains(.signingOut))
        #expect(flow.state == .done)
        #expect(!flow.forced)
    }

    @Test("offline: stuck with the count, and NOT signed out")
    func stuckOffline() async {
        let flow = SampleSignOutFlow(unsent: 2, script: .offline, sleep: Self.ticking)
        flow.begin()
        await finish(flow) { $0 != .asking(unsent: 2) && $0 != .sending(remaining: 2) }
        #expect(flow.state == .stuck(remaining: 2, reason: .offline))
        #expect(!flow.forced)
    }

    @Test("sign out anyway forces the sign-out only from stuck, and only on the call")
    func anyway() async {
        let flow = SampleSignOutFlow(unsent: 2, script: .offline, sleep: Self.ticking)
        flow.signOutAnyway()
        #expect(flow.state == .asking(unsent: 2))
        #expect(!flow.forced)
        flow.begin()
        await finish(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(!flow.forced)
        flow.signOutAnyway()
        #expect(flow.state == .done)
        #expect(flow.forced)
    }

    @Test("wait (cancel) from stuck keeps everything and stays signed in")
    func waitKeepsEverything() async {
        let flow = SampleSignOutFlow(unsent: 3, script: .offline, sleep: Self.ticking)
        flow.begin()
        await finish(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        flow.cancel()
        #expect(flow.state == .asking(unsent: 3))
        #expect(!flow.forced)
    }

    @Test("cancelling mid-send stops the send and a late finish does nothing")
    func cancelMidSend() async {
        let flow = SampleSignOutFlow(unsent: 2, sleep: { _ in try? await Task.sleep(for: .milliseconds(40)) })
        flow.begin()
        try? await Task.sleep(for: .milliseconds(10))
        flow.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(flow.state == .asking(unsent: 2))
        #expect(!flow.forced)
    }

    @Test("a second begin while sending does nothing")
    func singleBegin() async {
        let flow = SampleSignOutFlow(unsent: 2, sleep: { _ in try? await Task.sleep(for: .milliseconds(20)) })
        flow.begin()
        try? await Task.sleep(for: .milliseconds(5))
        let during = flow.state
        flow.begin()
        #expect(flow.state == during)
    }

    @Test("an old build says update, not 'can't send'")
    func updateRequired() async {
        let flow = SampleSignOutFlow(unsent: 1, script: .updateRequired, sleep: Self.ticking)
        flow.begin()
        await finish(flow) {
            if case .stuck = $0 {
                true
            } else {
                false
            }
        }
        #expect(flow.state == .stuck(remaining: 1, reason: .updateRequired))
        #expect(SignOutSheet.stuckTitle(remaining: 1, reason: .updateRequired) == "1 entry is waiting for an update")
    }

    @Test("the words count honestly and are plural-correct")
    func words() {
        #expect(SignOutSheet.unsentTitle(1) == "1 entry hasn't sent yet")
        #expect(SignOutSheet.unsentTitle(3) == "3 entries haven't sent yet")
        #expect(SignOutSheet.stuckTitle(remaining: 2, reason: .offline) == "2 entries can't send right now")
    }

    @Test("the launcher lists the sheet's states and the account page")
    func launcher() {
        #expect(ScreenRegistry.screen("AC-2")?.states.count == AccountScenario.allCases.count)
        #expect(ScreenRegistry.screen("account") != nil)
    }
}
