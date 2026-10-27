//
//  NowPlayingContent.swift
//  V2.outside · EX-2 lock screen · now playing (Paper 1H2J-0). The lock screen's player is the system's;
//  the app gives it only these values (title, the line under it, length, where it is, the two skips).
//  Content only: nothing here writes to MPNowPlayingInfoCenter or registers remote commands. The player
//  does that when it is wired (the player sheet is a core file; a wiring PR), and a device check
//  confirms it (EX-D1). Skips match the transport: back 15, forward 30.
//
import Foundation

struct NowPlayingContent: Equatable, Sendable {
    /// "the fundraise article you sent".
    let title: String
    /// "retrospect · tuesday's brief · part 2 of 3".
    let subtitle: String
    /// Seconds.
    let duration: TimeInterval
    let elapsed: TimeInterval
    var skipBack: TimeInterval = 15
    var skipForward: TimeInterval = 30

    /// What the system's scrubber shows on the left: "1:12".
    var elapsedLabel: String {
        Self.clock(elapsed)
    }

    /// What it shows on the right: "−2:48" (a true minus sign).
    var remainingLabel: String {
        "\u{2212}" + Self.clock(max(duration - elapsed, 0))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.down))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    /// One part of a brief, as the lock screen names it.
    static func briefPart(title: String, day: String, part: (index: Int, of: Int), duration: TimeInterval, elapsed: TimeInterval) -> Self {
        NowPlayingContent(
            title: title,
            subtitle: "retrospect · \(day)'s brief · part \(part.index) of \(part.of)",
            duration: duration,
            elapsed: elapsed
        )
    }

    /// Paper's lock screen: part 2 of tuesday's brief, 1:12 in, 2:48 to go.
    static let paper = briefPart(title: "the fundraise article you sent", day: "tuesday", part: (2, 3), duration: 240, elapsed: 72)
}
