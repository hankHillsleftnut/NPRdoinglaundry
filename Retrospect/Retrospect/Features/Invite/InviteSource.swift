//
//  InviteSource.swift
//  PI1/PI2: what the invite screens need from the app, as one seam. The live one wraps
//  `Session.InviteCenter` (LiveInviteSource); Sign in with Apple is the shared `SignInCoordinating` (PI0); the sample one plays the
//  scenarios (SampleInviteSource). The screens never talk to the network or the Keychain.
//
import Foundation

@MainActor
protocol InviteSource: AnyObject {
    /// After sign-in (and on a retry): the pending code is checked, never spent.
    func ticketAfterSignIn() async -> Session.Ticket
    /// A typed code: checked, and kept as the pending code only when it can be used.
    func type(code: String) async -> Session.Ticket
    /// Touch-down on the handle: one key for this tear, reused by a retry.
    func beginTear()
    /// The stub separates: the code is spent, once.
    func tear() async -> Session.TearOutcome
    /// True when the person is now on the list.
    func joinWaitlist(reason: String?) async -> Bool
    /// The code waiting to be torn, for the stub's tiles (a link's code; the person's own typed one is on the tiles).
    func pendingCode() async -> String?
    /// "begin": the person has seen "you're in" on this phone.
    func begin()
}
