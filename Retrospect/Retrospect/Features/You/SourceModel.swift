//
//  SourceModel.swift
//  V2.you · YO-3: one state (loading, the entry, or gone) and the edit in place (REntryEdit: the draft
//  is filled once when editing starts; save keeps it, cancel leaves the words as they were).
//
import Foundation

@MainActor
@Observable
final class SourceModel {
    enum State: Equatable {
        case loading
        case content(Flows.SourceEntry)
        /// The source doesn't exist (any more).
        case gone
    }

    private(set) var state: State = .loading
    var edit = REntryEdit()
    let sourceID: String
    private let data: any YouData

    /// The launcher's `editing` state opens with the edit begun.
    private var startsEditing: Bool

    init(sourceID: String, data: any YouData, startsEditing: Bool = false) {
        self.sourceID = sourceID
        self.data = data
        self.startsEditing = startsEditing
    }

    /// Loads once: coming back to the page (after YO-5) keeps what is shown, and words just saved.
    func load() async {
        guard state == .loading else { return }
        state = await data.source(id: sourceID).map(State.content) ?? .gone
        if startsEditing {
            startsEditing = false
            beginEditing()
        }
    }

    var entry: Flows.SourceEntry? {
        if case let .content(entry) = state {
            return entry
        }
        return nil
    }

    /// "save" lights only for a real change that still has words in it.
    var canSave: Bool {
        guard edit.editing, let entry else { return false }
        let draft = edit.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !draft.isEmpty && draft != entry.words
    }

    func beginEditing() {
        guard let entry else { return }
        edit.begin(from: entry.words)
    }

    func cancelEditing() {
        edit.cancel()
    }

    func save() async {
        guard canSave, var entry else { return }
        let words = edit.save().trimmingCharacters(in: .whitespacesAndNewlines)
        entry.words = words
        state = .content(entry)
        await data.saveWords(words, source: sourceID)
    }
}
