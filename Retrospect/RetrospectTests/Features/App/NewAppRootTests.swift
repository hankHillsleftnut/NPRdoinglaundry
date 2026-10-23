@testable import Retrospect
import Testing

/// APP-ROOT: which page each session lands on, and that a release build opens the new root.
struct NewAppRootTests {
    private func screen(
        _ state: Session.State?, code: Bool? = false, held: Bool = false, failed: Bool = false, seen: Bool? = true
    ) -> NewAppRoot.Screen {
        NewAppRoot.screen(for: state, pendingCode: code, gateHeld: held, storeOpenFailed: failed, youreInSeen: seen)
    }

    private func signedIn(_ access: Session.AccessState) -> Session.State {
        .signedIn(userID: "u", access: access)
    }

    @Test("nothing read yet is blank; a locked phone says so, and is never taken for signed out")
    func blankAndLocked() {
        #expect(screen(nil) == .blank)
        #expect(screen(.locked) == .locked)
    }

    @Test("signed out lands on sign-in; a waiting code lands on the gate; an unread Keychain waits on a blank page")
    func signedOut() {
        #expect(screen(.signedOut(hasSignedInBefore: false, reason: .none)) == .signIn(returning: false, endedByServer: false))
        #expect(screen(.signedOut(hasSignedInBefore: true, reason: .revoked)) == .signIn(returning: true, endedByServer: true))
        #expect(screen(.signedOut(hasSignedInBefore: false, reason: .none), code: true) == .inviteGate)
        #expect(screen(.signedOut(hasSignedInBefore: false, reason: .none), code: nil) == .blank)
    }

    @Test("a person who is not let in never sees the journal: waitlisted and unknown land on the gate")
    func notLetInGoesToTheGate() {
        #expect(screen(signedIn(.waitlisted)) == .inviteGate)
        #expect(screen(signedIn(.unknown)) == .inviteGate)
        #expect(screen(signedIn(.waitlisted), failed: true) == .inviteGate, "a failed store is not the gate's problem")
    }

    @Test("suspended is the paused page")
    func suspended() {
        #expect(screen(signedIn(.suspended)) == .paused)
    }

    @Test("let in lands on the journal; the tear keeps the gate up until 'begin'")
    func letIn() {
        for access in [Session.AccessState.approved, .member, .staff] {
            #expect(screen(signedIn(access)) == .journal)
        }
        #expect(screen(signedIn(.approved), held: true) == .inviteGate, "the tear made them a member; the page stays until begin")
        #expect(screen(signedIn(.member), held: true) == .journal)
    }

    @Test("approved and not yet seen on this phone shows the moment; unknown waits; a failed store retries")
    func approvedSeenFlag() {
        #expect(screen(signedIn(.approved), seen: false) == .inviteGate)
        #expect(screen(signedIn(.approved), seen: nil) == .blank)
        #expect(screen(signedIn(.approved), seen: true) == .journal)
        #expect(screen(signedIn(.approved), failed: true, seen: nil) == .storeFailed)
        #expect(screen(signedIn(.member), seen: nil) == .journal, "members never wait on the flag")
    }

    @Test("a store that cannot be opened is its own page with a retry, only where the journal would show")
    func storeFailed() {
        #expect(screen(signedIn(.member), failed: true) == .storeFailed)
        #expect(screen(signedIn(.member), failed: false) == .journal)
    }

    @Test("a release build always opens the new root; debug does unless -OldHome")
    func releaseDefault() {
        #expect(NewAppRoot.isDefault(arguments: [], debug: false))
        #expect(NewAppRoot.isDefault(arguments: ["-OldHome"], debug: false), "-OldHome is a debug escape only")
        #expect(NewAppRoot.isDefault(arguments: [], debug: true))
        #expect(!NewAppRoot.isDefault(arguments: ["-OldHome"], debug: true))
    }
}
