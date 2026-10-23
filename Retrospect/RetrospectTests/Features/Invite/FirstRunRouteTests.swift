@testable import Retrospect
import Testing

/// Contract 01 §3: which page each (session, access, pending code, seen) row lands on.
struct FirstRunRouteTests {
    private func route(_ session: Session.State, code: Bool = false, seen: Bool = false) -> FirstRunRoute {
        FirstRunRoute.route(session: session, hasPendingCode: code, youreInSeen: seen)
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

    @Test("approved sees you're in until begin was pressed on this phone, then the journal")
    func approved() {
        #expect(route(signedIn(.approved)) == .youreIn)
        #expect(route(signedIn(.approved), seen: true) == .journal)
    }

    @Test("members and staff go straight to the journal")
    func members() {
        #expect(route(signedIn(.member)) == .journal)
        #expect(route(signedIn(.staff)) == .journal)
    }

    @Test("locked is the blank canvas")
    func locked() {
        #expect(route(.locked, code: true) == .blank)
    }
}
