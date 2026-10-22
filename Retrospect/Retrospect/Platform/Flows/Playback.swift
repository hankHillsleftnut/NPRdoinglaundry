//
//  Playback.swift
//  The player's seam (ui-engineer.md §4, the playback row): what the brief player (JR-2),
//  the mini-player and later the episode player read. Views build against SamplePlayback
//  (UI3.0); the Platform engineer builds the live player (PLP.1a) behind the same protocol.
//
import Foundation
import Observation

/// Something that can be played: today's brief now, episodes later (contract 03).
struct PlaybackItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case brief
        case episode
    }

    /// A stretch of the audio with its words: a brief's part, or an episode's chapter.
    struct Part: Identifiable, Hashable, Sendable {
        /// The part's position, from 0.
        let id: Int
        /// Episodes' chapters have titles; brief parts don't.
        let title: String?
        let text: String
        let startSeconds: Double
    }

    let id: String
    let kind: Kind
    let title: String
    let parts: [Part]
    /// From the contract; the player's own `duration` replaces it once audio has loaded.
    let durationSeconds: Double?
}

enum PlaybackState: Hashable, Sendable {
    /// Nothing loaded.
    case idle
    case buffering
    case playing
    case paused
    case ended
    case failed(FlowFailure)
    /// Offline, and this audio isn't on the phone.
    case offline
}

/// The one player in the app. Only one item plays at a time; loading another replaces it.
@MainActor
protocol Playback: AnyObject, Observable {
    var item: PlaybackItem? { get }
    var state: PlaybackState { get }
    /// Seconds from the start.
    var position: Double { get }
    /// Nil until the audio's length is known.
    var duration: Double? { get }
    /// How much is downloaded, 0…1, for episodes; nil for briefs (they're short enough not to show it).
    var buffered: Double? { get }
    /// The part playing now, as an index into `item.parts`.
    var currentPart: Int? { get }

    /// Loads an item, paused at the start (or where the person left it).
    func load(_ item: PlaybackItem) async
    func play()
    func pause()
    /// Clamped to the audio; seeking past the end ends playback.
    func seek(to seconds: Double)
    /// Forward or back by `seconds`, clamped to the audio.
    func skip(by seconds: Double)
}
