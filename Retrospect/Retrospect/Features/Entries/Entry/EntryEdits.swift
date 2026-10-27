//
//  EntryEdits.swift
//  V2.journal J2b: where saved edits live until the edit door exists (BE1.5b, PATCH deferred). Owned
//  above the entry pages (the journal's stack), so an entry reopened after a save shows the saved words,
//  not the ones it was loaded with. The wiring PR replaces it with the seam's edit call.
//
import Observation

@MainActor
@Observable
final class EntryEdits {
    /// Saved words by entry id.
    private(set) var words: [String: String] = [:]

    func saved(for id: String) -> String? {
        words[id]
    }

    func save(_ text: String, for id: String) {
        words[id] = text
    }
}
