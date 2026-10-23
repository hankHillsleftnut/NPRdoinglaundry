import Foundation
@testable import Retrospect
import Testing

/// P31.delete: the account page's delete flow over fake ports (what each outcome shows), the dialog's words and
/// statuses, and the launcher's states.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DeleteAccountFlowTests {
    /// Ports that answer `outcome`, counting deletes and finishes; the goodbye's wait returns at once.
    @MainActor
    private final class Fake {
        var outcome: Session.DeletionOutcome
        var online = true
        var unsent = 0
        private(set) var deletes = 0
        private(set) var finishes = 0

        init(_ outcome: Session.DeletionOutcome) {
            self.outcome = outcome
        }

        func ports() -> LiveDeleteAccountFlow.Ports {
            LiveDeleteAccountFlow.Ports(
                unsent: { self.unsent },
                isOnline: { self.online },
                delete: {
                    self.deletes += 1
                    return self.outcome
                },
                finish: { self.finishes += 1 },
                sleep: { _ in }
            )
        }
    }

    private func settle(_ flow: LiveDeleteAccountFlow, until condition: (DeleteAccountState) -> Bool) async throws {
        for _ in 0 ..< 200 where !condition(flow.state) {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition(flow.state), "stuck at \(flow.state)")
    }

    @Test("the row opens the dialog with the unsent count read again; cancel closes it and deletes nothing")
    func cancelDeletesNothing() async throws {
        let fake = Fake(.deleted)
        fake.unsent = 2
        let flow = LiveDeleteAccountFlow(ports: fake.ports())

        flow.open()
        #expect(flow.state == .asking)
        for _ in 0 ..< 100 where flow.unsent != 2 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(flow.unsent == 2)

        flow.cancel()

        #expect(flow.state == .closed)
        #expect(fake.deletes == 0)
        #expect(fake.finishes == 0)
    }

    @Test("deleted: pending, then the goodbye, then the phone is erased and the flow is done; cancel can't stop it")
    func deletedShowsTheGoodbyeThenFinishes() async throws {
        let fake = Fake(.deleted)
        let flow = LiveDeleteAccountFlow(ports: fake.ports())
        flow.open()

        flow.confirm()
        #expect(flow.state == .pending)
        flow.cancel()
        #expect(flow.state == .pending, "nothing stops it once it's out")

        try await settle(flow) { $0 == .done }
        #expect(fake.deletes == 1)
        #expect(fake.finishes == 1)
    }

    @Test("Apple closed: the dialog closes with no message; offline: confirm is held with 'needs a connection'")
    func appleClosedAndOffline() async throws {
        let fake = Fake(.cancelledAtApple)
        let flow = LiveDeleteAccountFlow(ports: fake.ports())
        flow.open()
        flow.confirm()
        try await settle(flow) { $0 == .closed }

        fake.outcome = .offline
        flow.open()
        flow.confirm()
        try await settle(flow) { $0 == .asking && !flow.isOnline }
        #expect(DeleteAccountDialog.status(for: flow.state, isOnline: flow.isOnline) == .offline)
        flow.confirm()
        #expect(flow.state == .asking, "offline, confirm does nothing")
        #expect(fake.finishes == 0)
    }

    @Test("a failure keeps the dialog with its error line, erases nothing, and confirm works again")
    func aFailureCanBeRetried() async throws {
        let fake = Fake(.failed(.notNow))
        let flow = LiveDeleteAccountFlow(ports: fake.ports())
        flow.open()
        flow.confirm()
        try await settle(flow) { $0 == .failed(.notNow) }
        #expect(fake.finishes == 0)

        fake.outcome = .deleted
        flow.confirm()
        try await settle(flow) { $0 == .done }
        #expect(fake.deletes == 2)
    }

    @Test("the dialog says exactly what goes, counts unsent entries, and has one line per failure")
    func theDialogsWords() {
        #expect(DeleteAccountDialog.title == "delete your account?")
        #expect(DeleteAccountDialog.confirmTitle == "delete my account")
        #expect(DeleteAccountDialog.line(unsent: 0) == "your account, entries, episodes and everything retro knows are deleted. this can't be undone.")
        #expect(DeleteAccountDialog.line(unsent: 1).hasSuffix("1 entry that hasn't sent yet goes with it."))
        #expect(DeleteAccountDialog.line(unsent: 3).hasSuffix("3 entries that haven't sent yet go with it."))
        #expect(!DeleteAccountDialog.line(unsent: 0).contains("billing"), "no subscriptions yet: no billing paragraph")
        let problems: [Session.DeletionProblem] = [.differentAppleAccount, .appleRefused, .noAnswer, .notNow]
        #expect(Set(problems.map(DeleteAccountDialog.message(for:))).count == problems.count)
        #expect(!DeleteAccountDialog.message(for: .noAnswer).contains("nothing was deleted"), "unknown is never called nothing")
        #expect(DeleteAccountDialog.status(for: .pending, isOnline: true) == .pending)
        #expect(DeleteAccountDialog.status(for: .asking, isOnline: true) == .rest)
    }

    @Test("the dialog shows while asking, pending or failed; the goodbye covers the page after")
    func whatShows() {
        let open: [DeleteAccountState] = [.asking, .pending, .failed(.notNow)]
        let shut: [DeleteAccountState] = [.closed, .goodbye, .done]
        #expect(open.map(\.showsDialog) == [true, true, true])
        #expect(shut.map(\.showsDialog) == [false, false, false])
        #expect(DeleteAccountState.goodbye.showsGoodbye && DeleteAccountState.done.showsGoodbye)
        #expect(!DeleteAccountState.pending.showsGoodbye)
        #expect(DeletedPage.title == "your account is deleted.")
        #expect(DeletedPage.line == "thank you for trying retrospect.")
        #expect(LiveDeleteAccountFlow.goodbyeHold == .milliseconds(2400))
    }

    @Test("the launcher opens every state of the delete flow")
    func theLauncherStates() {
        #expect(ScreenRegistry.screen("account-delete")?.states == ["rest", "unsent", "pending", "error", "offline", "goodbye"])
    }
}
