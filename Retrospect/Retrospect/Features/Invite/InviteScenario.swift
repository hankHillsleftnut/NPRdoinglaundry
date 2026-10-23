//
//  InviteScenario.swift
//  PI1 + PI2 on sample data: one case per state a page draws. The raw values are the launcher's
//  `-State` names (T02, `-Screen PI1` or `-Screen PI2`). Invented names only ("priya", "sam");
//  the code is the contract fixture's invented one and never a real code.
//
import Foundation

enum InviteScenario: String, CaseIterable, Sendable {
    // PI1
    case promise, promiseNeutral, signingIn, signInFailed
    case typed, typedWrong, typedFilled
    case used, expired, offline, rateLimited
    case waitlistSheet, waitlisted, suspended
    // PI2
    case printing, ready, tearing, sealing, tearOffline, tearRefused
    case torn, youreIn, youreInStatic, noName
    case reduceMotionReady = "reduceMotion.ready"

    static let pi1: [InviteScenario] = [
        .promise, .promiseNeutral, .signingIn, .signInFailed, .typed, .typedWrong, .typedFilled,
        .used, .expired, .offline, .rateLimited, .waitlistSheet, .waitlisted, .suspended,
    ]
    static let pi2: [InviteScenario] = [
        .printing, .ready, .tearing, .sealing, .tearOffline, .tearRefused, .torn, .youreIn, .youreInStatic, .noName,
        .reduceMotionReady,
    ]
}

/// The fixture's invented values (`fixtures/01/invite.check.usable.json`), and nobody's real code.
enum SampleInvite {
    static let code = "7KQ2M9XD4RTAB"
    static let face = Session.TicketFace(from: "priya", kind: .member, serial: 412, issuedOn: "2026-10-19")
    static let youreIn = Session.YoureIn(invitedBy: "priya", serial: 412, redeemedOn: "2026-10-21", animate: true)
    static let firstName = "sam"
}
