@testable import Retrospect
import Testing

/// Contract 01 §3: which page each (session, access, pending code, seen) row lands on.
struct FirstRunRouteTests {
    private func route(_ session: Session.State, code: Bool = false, seen: Bool = false, flags: Store.PersonFlags.FirstRun? = nil) -> FirstRunRoute {
        FirstRunRoute.route(session: session, hasPendingCode: code, youreInSeen: seen, firstRun: flags)
    }

    private func signedIn(_ access: Session.AccessState) -> Session.State {
        .signedIn(userID: "u", access: access)
    }

    @Test("signed out: a waiting code shows the promise, otherwise sign-in (welcome back if signed in here before)")
    func signedOut() {
        #expect(route(.signedOut(hasSignedInBefore: false, reason: .none), code: true) == .inviteGate)
        #expect(route(.signedOut(hasSignedInBefore: false, reason: .none)) == .signIn(returning: false))
        #expect(route(.signedOut(hasSignedInBefore: true, reason: .revoked)) == .signIn(returning: true))
    }

    @Test("a person who is not let in lands on the invite gate, never the journal")
    func waitlistedLandsOnTheGate() {
        #expect(route(signedIn(.waitlisted)) == .inviteGate)
        #expect(route(signedIn(.waitlisted), code: true) == .inviteGate)
    }

    @Test("an access state the app doesn't know fails closed: the gate, never the journal")
    func unknownFailsClosed() {
        #expect(route(signedIn(.unknown), seen: true) == .inviteGate)
    }

    @Test("suspended is paused, whatever else is true")
    func suspended() {
        #expect(route(signedIn(.suspended), code: true, seen: true) == .paused)
    }

    private typealias Flags = Store.PersonFlags.FirstRun

    @Test("approved sees you're in until begin was pressed on this phone, then the first run (FR.b1.root), then the journal once it is done")
    func approved() {
        #expect(route(signedIn(.approved)) == .youreIn)
        #expect(route(signedIn(.approved), seen: true) == .firstRun, "flags not known yet: the root holds; the table says first run")
        #expect(route(signedIn(.approved), seen: true, flags: Flags(started: true, done: false)) == .firstRun)
        #expect(
            route(signedIn(.approved), seen: true, flags: Flags(started: false, done: false)) == .firstRun,
            "begin without the flag (an older phone) still enters"
        )
        #expect(route(signedIn(.approved), seen: true, flags: Flags(started: true, done: true)) == .journal)
        #expect(route(signedIn(.approved), flags: Flags(started: true, done: false)) == .youreIn, "begin not pressed here: the moment first")
    }

    @Test("members and staff go straight to the journal, unless the first run was started on this phone and isn't done (made member mid-flow)")
    func members() {
        for access in [Session.AccessState.member, .staff] {
            #expect(route(signedIn(access)) == .journal)
            #expect(route(signedIn(access), seen: true) == .journal, "an existing account never sees the first run")
            #expect(route(signedIn(access), seen: true, flags: Flags(started: false, done: false)) == .journal)
            #expect(route(signedIn(access), seen: true, flags: Flags(started: true, done: true)) == .journal)
            #expect(route(signedIn(access), seen: true, flags: Flags(started: true, done: false)) == .firstRun)
        }
    }

    @Test("a waitlisted, unknown or suspended person never reaches the first run, whatever the flags say")
    func neverReachedWhenNotLetIn() {
        let mid = Flags(started: true, done: false)
        #expect(route(signedIn(.waitlisted), seen: true, flags: mid) == .inviteGate)
        #expect(route(signedIn(.unknown), seen: true, flags: mid) == .inviteGate)
        #expect(route(signedIn(.suspended), seen: true, flags: mid) == .paused)
        #expect(route(.signedOut(hasSignedInBefore: true, reason: .none), seen: true, flags: mid) == .signIn(returning: true))
    }

    @Test("locked is the blank canvas")
    func locked() {
        #expect(route(.locked, code: true) == .blank)
    }
}
