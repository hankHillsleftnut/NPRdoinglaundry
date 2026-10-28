//
//  FirstRunRoute.swift
//  Which page a person lands on: contract 01 §3's launch table as one pure function, so the app root
//  (the wiring PR) only has to mount what this says. A signed-in person who is not let in yet lands on the
//  invite gate, never the journal; an access state the app doesn't know fails closed (the gate, which
//  re-reads access), never the journal.
//  FR.b1.root (founder go 28 Oct): the first run (ON-3–9, the questions) sits between "begin" and the journal.
//  It is routed on the person's flags, never on access alone: an approved person who pressed "begin" is in it
//  until it is done; a member is in it only if it was started on this phone and not done (the door made them a
//  member mid-flow), so an existing account never sees it.
//
import Foundation

enum FirstRunRoute: Equatable {
    /// The phone hasn't been unlocked yet: the blank canvas, nothing read as signed out.
    case blank
    /// PI0: Sign in with Apple. `returning` is "welcome back".
    case signIn(returning: Bool)
    /// PI1: the promise (a code waits), the typed ticket, or the print (PI2 takes over from `ready`).
    case inviteGate
    /// "your account is paused."
    case paused
    /// PI2: "you're in", the person was let in and has not pressed "begin" on this phone.
    case youreIn
    /// ON-3–9: the first run's questions (later bites add the steps after them).
    case firstRun
    /// JR-1.
    case journal

    /// `firstRun`: the person's first-run flags; nil while not known. An approved person past "begin" is in the
    /// first run unless it is done; a member only when it was started here and not done.
    static func route(
        session: Session.State, hasPendingCode: Bool, youreInSeen: Bool, firstRun: Store.PersonFlags.FirstRun? = nil
    ) -> Self {
        switch session {
        case .locked:
            .blank
        case let .signedOut(hasSignedInBefore, _):
            hasPendingCode ? .inviteGate : .signIn(returning: hasSignedInBefore)
        case let .signedIn(_, access):
            signedIn(access, youreInSeen: youreInSeen, firstRun: firstRun)
        }
    }

    private static func signedIn(_ access: Session.AccessState, youreInSeen: Bool, firstRun: Store.PersonFlags.FirstRun?) -> Self {
        switch access {
        case .waitlisted, .unknown: .inviteGate
        case .suspended: .paused
        case .approved: youreInSeen ? (firstRun?.done == true ? .journal : .firstRun) : .youreIn
        case .member, .staff: firstRun.map { $0.started && !$0.done } == true ? .firstRun : .journal
        }
    }
}
