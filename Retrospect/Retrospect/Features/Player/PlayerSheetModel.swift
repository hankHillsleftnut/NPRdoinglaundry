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

    /// The chevron-down (26PH-0): the sheet goes, once.
    func collapse() {
        guard !hasCollapsed else { return }
        hasCollapsed = true
        onCollapse()
    }
}
