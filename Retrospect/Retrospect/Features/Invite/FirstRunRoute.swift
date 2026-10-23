//
//  FirstRunRoute.swift
//  Which page a person lands on: contract 01 §3's launch table as one pure function, so the app root
//  (the wiring PR) only has to mount what this says. A signed-in person who is not let in yet lands on the
//  invite gate, never the journal; an access state the app doesn't know fails closed (the gate, which
//  re-reads access), never the journal.
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
    /// JR-1.
    case journal

    static func route(
        session: Session.State, hasPendingCode: Bool, youreInSeen: Bool
    ) -> Self {
        switch session {
        case .locked:
            .blank
        case let .signedOut(hasSignedInBefore, _):
            hasPendingCode ? .inviteGate : .signIn(returning: hasSignedInBefore)
        case let .signedIn(_, access):
            signedIn(access, youreInSeen: youreInSeen)
        }
    }

    private static func signedIn(_ access: Session.AccessState, youreInSeen: Bool) -> Self {
        switch access {
        case .waitlisted, .unknown: .inviteGate
        case .suspended: .paused
        case .approved: youreInSeen ? .journal : .youreIn
        case .member, .staff: .journal
        }
    }
}
