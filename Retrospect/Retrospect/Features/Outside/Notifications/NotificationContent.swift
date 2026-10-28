//
//  NotificationContent.swift
//  V2.outside · EX-3 notifications (Paper 1H3E-0). The banners are the system's; the app gives each
//  kind its words and where a tap lands (handoff deep links: episode → PC-2, brief → JR-2, question →
//  YO-4). Content only: no permission prompt, no scheduling, no push (the push entitlement is founder
//  paperwork, EX-D4). The system shows "retrospect" and the time; Paper's caption "at most one a day.
//  the other two kinds:" is a note on the board, not words in a banner.
//
import Foundation

/// Where a notification's tap lands. Wired to the app's routes by a wiring PR.
enum NotificationDestination: Equatable, Sendable {
    /// PC-2, the episode in the player.
    case episode
    /// JR-2, today's brief.
    case brief
    /// YO-4, the waiting question.
    case question
}

enum NotificationKind: String, CaseIterable, Sendable {
    case episode, brief, question

    /// The banner's words, exactly as Paper writes them.
    func body(briefMinutes: Int = 4) -> String {
        switch self {
        case .episode: "this week's episode is here."
        case .brief: "your brief is ready · \(briefMinutes) min"
        case .question: "one question for you, when you have a minute."
        }
    }

    var destination: NotificationDestination {
        switch self {
        case .episode: .episode
        case .brief: .brief
        case .question: .question
        }
    }

    /// Banners of one kind stack together.
    var threadID: String {
        "retrospect.\(rawValue)"
    }
}
