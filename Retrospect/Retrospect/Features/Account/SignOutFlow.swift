//
//  SignOutFlow.swift
//  P33: what the sign-out sheet needs from the app, as one seam. Lane A's PL3.7e (`sendThenSignOut()`:
//  send what hasn't sent, then sign out, and say when it can't) conforms; until it lands the sheet runs
//  on `SampleSignOutFlow` in the launcher. The sheet never erases anything itself and never calls a
//  forced sign-out without the person's explicit tap on "sign out anyway".
//
import Foundation
import Observation

/// Where a sign-out stands.
enum SignOutState: Equatable, Sendable {
    /// The sheet is open and nothing has been pressed. `unsent` is how many entries haven't reached the server.
    case asking(unsent: Int)
    /// Sending them first; `remaining` rolls down.
    case sending(remaining: Int)
    /// Everything sent (or nothing to send): the session is ending.
    case signingOut
    /// Entries can't be sent now. Signing out anyway would lose them from this phone.
    case stuck(remaining: Int, reason: StuckReason)
    /// Signed out: the sheet closes into welcome back.
    case done

    enum StuckReason: Equatable, Sendable {
        case offline, failed
        /// This build is too old to send them: update first.
        case updateRequired
    }
}

@MainActor
protocol SignOutFlowing: AnyObject, Observable {
    var state: SignOutState { get }
    /// "sign out" / "send, then sign out": sends what is unsent, then signs out.
    func begin()
    /// "sign out anyway": a forced sign-out. Only ever offered from `stuck`; ignored from any other state.
    func signOutAnyway()
    /// "cancel" or "wait": nothing is lost and the person stays signed in. Also called when the sheet goes
    /// away by a swipe or a scrim tap, so it must be safe to call twice and must do nothing once signing out
    /// has begun (`signingOut`, `done`).
    func cancel()
}
