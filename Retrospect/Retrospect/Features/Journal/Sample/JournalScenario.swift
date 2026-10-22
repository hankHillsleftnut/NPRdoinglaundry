//
//  JournalScenario.swift
//  UI1.0: one case per state a journal screen draws (docs/team/ui/UI1.0.md). The raw values are
//  the screen launcher's `-State` names (T02), so a scenario can be opened from the command line.
//
import Foundation

enum JournalScenario: String, CaseIterable, Sendable {
    /// Six entries today, all sent and acknowledged; the brief ready; one guess; three days in the drawer.
    case full
    /// No entries; the brief being made, ready by 8:30; no guesses.
    case dayOne
    /// The brief is off: no card at all.
    case briefOff
    case briefMaking
    case briefQuiet
    /// The brief is ready. Played is the player's state, not the journal's (contract 02 has no
    /// played flag), so this slot is the same as `full`'s; the player sample (UI3.0) plays it.
    case briefPlayed
    case briefError
    /// The last entry is sending, and never finishes.
    case sending
    /// The last entry didn't send; `retry` sends it after one second of the clock.
    case notSent
    /// Offline: the last two entries wait; the brief is the cached one.
    case offline
    /// Everything stays loading.
    case loading
    case errorNetwork = "error.network"
    case errorServer = "error.server"
    case guessOffered
    case guessConfirmed
    /// Answering never finishes.
    case guessPending
    /// Answering fails.
    case guessError
    /// A 1,200-character entry, a three-line brief headline and 60 entries in the drawer.
    case long
    /// The drawer's search, with matches (preset query "canal").
    case searchHit
    /// The drawer's search, nothing found (preset query "kayak").
    case searchEmpty
    /// JR-4: what Retro took, read.
    case tookRead
    /// JR-4: Retro hasn't read it yet, and is still reading.
    case tookWaiting
    /// JR-4: a correction already noted.
    case tookNoted
    case correctionApplied = "correction.applied"
    case correctionConfirm = "correction.confirm"
    case correctionAskOwnWords = "correction.askOwnWords"
    case correctionNotACorrection = "correction.notACorrection"
    /// JR-4 for a voice entry.
    case voice
    /// JR-4 opened on its delete dialog (a view state; the data is `full`'s).
    case deleteDialog
    /// JR-4 opened editing (a view state; the data is `full`'s).
    case editing

    /// The drawer search the launcher types in for this scenario.
    var presetQuery: String? {
        switch self {
        case .searchHit: "canal"
        case .searchEmpty: "kayak"
        default: nil
        }
    }

    /// The entry JR-4 opens on for this scenario.
    var focusEntryId: String {
        switch self {
        case .voice: SampleJournalContent.voiceEntryId
        case .tookWaiting: SampleJournalContent.waitingEntryId
        default: SampleJournalContent.firstEntryId
        }
    }
}
