//
//  InviteCopy.swift
//  PI1/PI2: every word on the invite pages, in one place for review (lowercase, the founder's).
//  The lean strings from docs/team/flows/first-run/views.md §A; the phase and the notice decide
//  which line shows. The inviter's name appears only when the preview or the check said it.
//
import Foundation

extension InviteModel {

    // MARK: Signed out (T1)

    /// "an invitation · from priya", or nothing when the preview isn't live.
    var promiseLabel: String? {
        guard let name = preview?.from, !name.isEmpty else { return nil }
        return "an invitation · from \(name)"
    }

    var promiseTitle: String {
        guard let name = preview?.from, !name.isEmpty else { return "a place, kept for you." }
        return "\(name) kept a place for you."
    }

    /// The line under the slot while signed out.
    var promiseLine: String {
        switch phase {
        case .signingIn: "signing you in…"
        case let .waiting(wait): wait == .offline ? "waiting for a connection" : "that didn't go through. we'll try again."
        default: notice == .signInFailed ? "that didn't work. nothing is lost; try again." : "sign in and your ticket prints."
        }
    }

    static let legal = "by accepting you agree to the terms · privacy"

    // MARK: Under the ticket

    /// The line under the ticket (SF 17, secondary).
    var caption: String? {
        switch phase {
        case .typed: typedCaption
        case .printing: "printing your ticket…"
        case .ready: readyCaption
        case .sealing: notice == .sealing ? "sealing it…" : "keep going."
        case .torn: "it's yours."
        case let .refused(reason): refusedCaption(reason)
        case .promise, .signingIn, .waiting, .youreIn, .suspended, .alreadyIn: nil
        }
    }

    private var typedCaption: String {
        if waitlist == .joined {
            return "you're on the list."
        }
        switch notice {
        case .wrongCode: return "that code didn't work. check it, or ask for a new one."
        case .rateLimited: return "too many tries. try again in a minute."
        case .typeOffline: return "no connection. nothing was used; try again."
        case .typeFailed: return "that didn't go through. try again."
        default: return "the link didn't bring the code? type it in."
        }
    }

    private var readyCaption: String {
        switch notice {
        case .sealOffline: "waiting for a connection. nothing was used."
        case .sealFailed: "that didn't go through. nothing was used; try again."
        default: keepGoing ? "keep going." : (firstName.map { "it's yours to take, \($0)." } ?? "it's yours to take.")
        }
    }

    private func refusedCaption(_ reason: Session.Refusal) -> String {
        if notice == .justUsed {
            return "someone else used this one just now."
        }
        switch reason {
        case .used: return "this one's been used. ask for another, or join the waitlist."
        case .expired: return "this one has expired. ask for another, or join the waitlist."
        case .invalid: return "that code didn't work. ask for another, or join the waitlist."
        }
    }

    /// The second line under the ticket, when there is one.
    var subcaption: String? {
        if phase == .typed, waitlist == .joined {
            return "if a friend sends you a link first, open it and you're in."
        }
        return nil
    }

    /// The pill under the caption (board `2ISG-0`): not pressable.
    var hint: String? {
        switch phase {
        case .typed where waitlist != .joined: "the tear unlocks when it's filled"
        case .ready where !keepGoing && notice == nil: "swipe along the line to tear →"
        default: nil
        }
    }

    /// The small line where the sign-in buttons were.
    var footer: String? {
        switch phase {
        case .printing, .ready, .sealing: "one use · once it's torn, it's yours"
        case .torn: "the stub stays with you"
        case .typed, .refused: "one use · yours alone"
        default: nil
        }
    }

    var offersWaitlist: Bool {
        switch phase {
        case .typed: waitlist != .joined
        case .refused: true
        default: false
        }
    }

    // MARK: You're in (T5)

    var youreInTitle: String {
        firstName.map { "you're in, \($0)." } ?? "you're in."
    }

    var youreInLine: String {
        if let name = youreIn?.invitedBy ?? face?.from, !name.isEmpty {
            return "\(name) gave you this. make it count."
        }
        return "someone kept this for you. make it count."
    }

    static let pausedTitle = "your account is paused."
    static let alreadyInToast = "you're already in."

    // MARK: The ticket's face

    var stubLabel: RTicketStubLabel {
        switch phase {
        case .refused(.used): .used
        case .refused(.expired): .expired
        default: .admitsOne
        }
    }

    /// The stub's date: when it was torn, else the day the invite was made.
    var stubDate: String {
        TicketText.date(youreIn?.redeemedOn ?? face?.issuedOn)
    }

    /// The code the stub shows: the typed tiles, or the link's code once the check knew it.
    var shownTiles: String {
        phase == .typed || printedCode.isEmpty ? tiles : printedCode
    }
}
