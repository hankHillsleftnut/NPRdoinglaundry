//
//  EntryDrawnModel.swift
//  V2.journal J2b (dark) · JR-4's drawn parts, built ahead of their doors (J-19, founder "all the code
//  ready"): "edit" and the editing bar (N8R-0, BE1.5b), "what i took from this" with "not right"
//  (N51-0, N7R-0, N9D-0, BE1.7) and "delete entry" with its dialog (NAB-0, BE1.6). The page shows them
//  only where `EntryCapabilities` turns them on: the app's cut has edit on (founder 27 Oct) and the
//  rest off; the launcher's `drawn-*` states turn them all on. On sample data the actions stay on the phone (no Backend.Client): "not right" strikes the
//  claim and notes it, save keeps the new words, delete pops back.
//
import Foundation
import Observation

/// One thing Retro took from an entry (Paper c:took-row: claim E35-0, noted E3C-0).
struct TookClaim: Identifiable, Equatable, Sendable {
    let id: String
    let words: String
    /// "not right" was said: struck through, "✓ noted".
    var noted = false
}

/// What the took section says, by where the entry stands.
enum TookSection: Equatable, Sendable {
    /// Retro read it and took these (N51-0).
    case claims([TookClaim])
    /// Sent, not read yet (N7R-0).
    case notReadYet
    /// Still on the phone (N9D-0).
    case notSentYet

    /// The quiet line in place of claims.
    var line: String? {
        switch self {
        case .claims: nil
        case .notReadYet: "retro hasn't read this yet. it will in a minute."
        case .notSentYet: "nothing yet. retro reads it once it sends."
        }
    }

    static func forStanding(_ standing: EntryPageModel.Standing, claims: [TookClaim]) -> TookSection {
        switch standing {
        case .read: .claims(claims)
        case .sent: .notReadYet
        case .waiting, .notSent: .notSentYet
        }
    }
}

@MainActor
@Observable
final class EntryDrawnModel {
    /// What the launcher opens the page on (`drawn-editing`, `drawn-deleteDialog`).
    enum Start: Equatable, Sendable {
        case rest, editing, deleteDialog
    }

    static let dialogTitle = "delete this entry?"
    static let dialogLine = "this removes it and what retro took from it. it can't be undone."
    static let dialogConfirm = "delete it"
    static let editingNote = "retro reads it again when you save"
    static let tookTitle = "what i took from this"

    /// The edit: the draft is filled once, when editing starts (REntryEdit).
    var edit = REntryEdit()
    /// The words kept by the last save; nil until a save (the entry's own words show).
    private(set) var savedWords: String?
    var showsDelete = false
    private(set) var claims: [TookClaim]
    /// Bumped on "not right", for the page's haptic. (Delete's warning haptic plays on the host
    /// that survives the pop.)
    private(set) var notedCount = 0
    /// "delete it" goes once: a second tap while the dialog leaves does nothing.
    private(set) var hasDeleted = false

    let start: Start
    @ObservationIgnored private var started = false
    @ObservationIgnored private let onDelete: () -> Void
    /// Hands a save to the entry's data owner, so the words outlive this page (reopened, they're there).
    @ObservationIgnored private let onSave: (String) -> Void

    init(
        claims: [TookClaim],
        start: Start = .rest,
        savedWords: String? = nil,
        onSave: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void
    ) {
        self.claims = claims
        self.start = start
        self.savedWords = savedWords
        self.onSave = onSave
        self.onDelete = onDelete
    }

    /// The words the page shows: the last save's, else the entry's.
    func words(_ entryWords: String) -> String {
        savedWords ?? entryWords
    }

    /// Opens the page in the launcher's state, once, after the entry has loaded.
    func applyStart(words: String) {
        guard !started else { return }
        started = true
        switch start {
        case .rest: break
        case .editing: beginEdit(from: words)
        case .deleteDialog: showsDelete = true
        }
    }

    // MARK: edit

    func beginEdit(from words: String) {
        edit.begin(from: words)
    }

    func cancelEdit() {
        edit.cancel()
    }

    /// Save is lit only once the words changed and aren't empty.
    func canSave(from words: String) -> Bool {
        let draft = edit.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !draft.isEmpty && draft != words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        let kept = edit.save().trimmingCharacters(in: .whitespacesAndNewlines)
        if !kept.isEmpty {
            savedWords = kept
            onSave(kept)
        }
    }

    // MARK: took

    func section(for standing: EntryPageModel.Standing) -> TookSection {
        TookSection.forStanding(standing, claims: claims)
    }

    /// "not right": the claim is struck and noted (once).
    func notRight(_ id: String) {
        guard let index = claims.firstIndex(where: { $0.id == id }), !claims[index].noted else { return }
        claims[index].noted = true
        notedCount += 1
    }

    // MARK: delete

    /// While the dialog asks, the page behind it is out of VoiceOver's reach (the dialog is modal).
    var hidesPageFromVoiceOver: Bool {
        showsDelete
    }

    func askDelete() {
        showsDelete = true
    }

    func keep() {
        showsDelete = false
    }

    /// "delete it": the dialog closes and the page goes back (SCREEN-MAP row 65: pop, J-16).
    func confirmDelete() {
        guard !hasDeleted else { return }
        hasDeleted = true
        showsDelete = false
        onDelete()
    }
}
