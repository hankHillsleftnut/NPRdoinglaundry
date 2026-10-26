//
//  PlayerSheetModel.swift
//  PS.sheet.a: the player sheet's decisions, apart from the view so they can be tested (Paper ON-11
//  26NO-0, the same sheet as PC-2 1FV9-0). It reads one player through `Flows.Playback` and the
//  episode's lines through `Flows.Transcript`, says what state the sheet is in and which line is being
//  read, and hands the collapse to whoever showed the sheet, once. Nothing here plays on its own yet
//  (autoplay is PS.sheet.c), follows the time with motion (PS.sheet.b) or logs anything.
//
import Foundation
import Observation

@MainActor @Observable
final class PlayerSheetModel {
    /// What the sheet is showing, from the player's state alone.
    enum State: Equatable {
        /// Nothing loaded yet, or waiting for audio.
        case waiting
        case playing
        case paused
        /// Played to the end: the last line stays lit.
        case ended
        /// The audio couldn't be loaded (the transport says so and offers retry).
        case failed
        /// Offline and not on the phone (the transport says so).
        case offline

        init(_ playback: Flows.PlaybackState) {
            switch playback {
            case .idle, .buffering: self = .waiting
            case .playing: self = .playing
            case .paused: self = .paused
            case .ended: self = .ended
            case .failed: self = .failed
            case .offline: self = .offline
            }
        }
    }

    /// The "…" menu's rows (build note 20 Oct: "chapters ›, download"). Founder Q2 = B (26 Oct): drawn
    /// ahead of their destinations, so choosing one only closes the menu, and VoiceOver hears
    /// `notAvailableYet`.
    enum MoreItem: String, CaseIterable {
        case chapters, download

        var title: String {
            rawValue
        }

        var symbol: String {
            switch self {
            case .chapters: "list.bullet"
            case .download: "arrow.down.circle"
            }
        }

        /// Chapters pushes a list (the build note's "›"); download acts in place.
        var opensMore: Bool {
            self == .chapters
        }
    }

    /// What VoiceOver adds to anything drawn before its destination exists.
    static let notAvailableYet = "not available yet"

    let playback: any Flows.Playback
    let transcript: Flows.Transcript
    @ObservationIgnored private let onCollapse: () -> Void
    /// The collapse is handed over once; a second tap while the sheet leaves does nothing.
    private(set) var hasCollapsed = false

    init(playback: any Flows.Playback, transcript: Flows.Transcript, onCollapse: @escaping () -> Void) {
        self.playback = playback
        self.transcript = transcript
        self.onCollapse = onCollapse
    }

    /// The header's line: the episode's title (26PP-0), read live so a late `load(_:)` still fills it.
    var title: String {
        playback.item?.title ?? ""
    }

    /// What share hands the system share sheet (founder Q3 = B: a line of text until episodes have links).
    var shareText: String {
        title.isEmpty ? "retrospect" : "\(title) · retrospect"
    }

    var state: State {
        State(playback.state)
    }

    /// The line being read now: dark (`text.primary`); every other line is dim (founder c-lsyb3w).
    /// Nil (nothing lit) when the player has moved on to another item than these lines' episode, or
    /// when the lines aren't timed: never the wrong line.
    var currentLine: Int? {
        guard playback.item?.id == transcript.itemID else { return nil }
        return transcript.lineIndex(at: playback.position)
    }

    /// The chevron-down (26PH-0): the sheet goes, once. In the first run the host raises the paywall
    /// early (PS.sheet.c); until the paywall exists it only hands the sheet back.
    func collapse() {
        guard !hasCollapsed else { return }
        hasCollapsed = true
        onCollapse()
    }
}
