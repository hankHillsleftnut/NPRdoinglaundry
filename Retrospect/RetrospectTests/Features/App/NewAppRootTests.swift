@testable import Retrospect
import Testing

/// APP-ROOT: which page each session lands on, and that a release build opens the new root.
struct NewAppRootTests {
    private typealias Flags = Store.PersonFlags.FirstRun
    /// The flags of a person whose first run is over: the rows below that are about the journal, not the first run.
    private let done = Flags(started: true, done: true)

    private func screen(
        _ state: Session.State?, code: Bool? = false, held: Bool = false, failed: Bool = false, seen: Bool? = true,
        flags: Store.PersonFlags.FirstRun? = Flags(started: true, done: true), updateRequired: Bool = false
    ) -> NewAppRoot.Screen {
        NewAppRoot.screen(
            for: state, pendingCode: code, gateHeld: held, storeOpenFailed: failed, youreInSeen: seen, firstRun: flags, updateRequired: updateRequired
        )
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

    @Test("FR.b1.root: begin leads into the first run; done leads out; flags not known yet hold the canvas; the store's failure wins")
    func firstRun() {
        let mid = Flags(started: true, done: false)
        #expect(screen(signedIn(.approved), seen: true, flags: mid) == .firstRun)
        #expect(screen(signedIn(.approved), seen: true, flags: Flags(started: false, done: false)) == .firstRun)
        #expect(screen(signedIn(.approved), seen: true, flags: nil) == .blank, "never the first question for someone past it, never the journal")
        #expect(screen(signedIn(.approved), seen: true, flags: done) == .journal)
        #expect(screen(signedIn(.approved), seen: false, flags: mid) == .inviteGate, "the moment comes first")
        #expect(screen(signedIn(.approved), held: true, flags: mid) == .inviteGate, "the gate stays up until begin")
        #expect(screen(signedIn(.approved), failed: true, flags: mid) == .storeFailed)
        #expect(screen(signedIn(.approved), seen: true, flags: mid, updateRequired: true) == .updateRequired)
    }

    @Test("FR.b1.root: an existing member never sees the first run; one made member mid-flow finishes it")
    func membersAndTheFirstRun() {
        for access in [Session.AccessState.member, .staff] {
            #expect(screen(signedIn(access), flags: nil) == .journal, "flags unknown: members never wait")
            #expect(screen(signedIn(access), flags: Flags(started: false, done: false)) == .journal)
            #expect(screen(signedIn(access), flags: done) == .journal)
            #expect(screen(signedIn(access), flags: Flags(started: true, done: false)) == .firstRun)
            #expect(screen(signedIn(access), failed: true, flags: Flags(started: true, done: false)) == .storeFailed)
        }
        #expect(screen(signedIn(.waitlisted), flags: Flags(started: true, done: false)) == .inviteGate)
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

    @Test("PLP.1b: the old podcast hooks are off under the new root and on only for debug -OldHome")
    func oldPodcastHooks() {
        #expect(!RetrospectApp.oldHooksActive(usesNewApp: true), "the new root: no old podcast cover, observer or scheduling")
        #expect(RetrospectApp.oldHooksActive(usesNewApp: false), "the old home keeps them as before")
        let release = NewAppRoot.isDefault(arguments: [], debug: false)
        #expect(!RetrospectApp.oldHooksActive(usesNewApp: release), "a release build never runs them")
        let oldHome = NewAppRoot.isDefault(arguments: ["-OldHome"], debug: true)
        #expect(RetrospectApp.oldHooksActive(usesNewApp: oldHome), "debug -OldHome behaves exactly as before")
    }
}
