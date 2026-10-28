import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct EntryDrawnModelTests {
    private func drawn(start: EntryDrawnModel.Start = .rest, onDelete: @escaping () -> Void = {}) -> EntryDrawnModel {
        EntryDrawnModel(claims: SampleTook.claims(for: SampleEntries.hereID), start: start, onDelete: onDelete)
    }

    @Test("the cut has edit only (founder 27 Oct); drawn turns all three on")
    func capabilities() {
        #expect(EntryCapabilities.cut == EntryCapabilities(edit: true, delete: false, took: false))
        #expect(EntryCapabilities.drawn == EntryCapabilities(edit: true, delete: true, took: true))
    }

    @Test("what i took, by where the entry stands (N51-0, N7R-0, N9D-0)")
    func sections() {
        let model = drawn()
        guard case let .claims(claims) = model.section(for: .read) else {
            Issue.record("read shows claims")
            return
        }
        #expect(claims.map(\.words) == ["the monday standup is hard for you", "you feel dread before 9am meetings"])
        #expect(claims.map(\.noted) == [false, true])
        #expect(model.section(for: .sent).line == "retro hasn't read this yet. it will in a minute.")
        #expect(model.section(for: .notSent).line == "nothing yet. retro reads it once it sends.")
        #expect(model.section(for: .waiting).line == "nothing yet. retro reads it once it sends.")
    }

    @Test("not right notes the claim once")
    func notRight() {
        let model = drawn()
        model.notRight("took-monday")
        model.notRight("took-monday")
        model.notRight("took-dread")
        let allNoted = model.claims.allSatisfy(\.noted)
        #expect(allNoted)
        #expect(model.notedCount == 1)
    }

    @Test("edit: the draft starts from the words, save lights only on a real change, cancel keeps the words")
    func edit() {
        let model = drawn()
        let words = "i think it's the 9am standup. i dread it."
        model.beginEdit(from: words)
        #expect(model.edit.editing)
        #expect(!model.canSave(from: words))
        model.edit.draft = "   "
        #expect(!model.canSave(from: words))
        model.edit.draft = "i think it's the 9am standup. i dread it, every monday"
        #expect(model.canSave(from: words))
        model.cancelEdit()
        #expect(model.words(words) == words)
        // words that end in a space or a newline (voice transcripts) don't light save on their own
        model.beginEdit(from: words + "\n")
        #expect(!model.canSave(from: words + "\n"))
        model.cancelEdit()
        model.beginEdit(from: words)
        model.edit.draft = "i dread it, every monday"
        model.save()
        #expect(!model.edit.editing)
        #expect(model.words(words) == "i dread it, every monday")
    }

    @Test("a save goes to the edits owner, and a page reopened on it shows the saved words")
    func saveOutlivesThePage() {
        let edits = EntryEdits()
        let id = SampleEntries.hereID
        let words = "i think it's the 9am standup. i dread it."
        let first = EntryDrawnModel(claims: [], savedWords: edits.saved(for: id), onSave: { edits.save($0, for: id) }, onDelete: {})
        first.beginEdit(from: words)
        first.edit.draft = "i dread it, every monday "
        first.save()
        #expect(edits.saved(for: id) == "i dread it, every monday")
        let reopened = EntryDrawnModel(claims: [], savedWords: edits.saved(for: id), onSave: { edits.save($0, for: id) }, onDelete: {})
        #expect(reopened.words(words) == "i dread it, every monday")
        // an empty save keeps nothing
        reopened.beginEdit(from: words)
        reopened.edit.draft = "  "
        reopened.save()
        #expect(edits.saved(for: id) == "i dread it, every monday")
    }

    @Test("delete: the dialog asks; keep closes it; delete it pops back once, a double tap too")
    func delete() {
        var pops = 0
        let model = drawn { pops += 1 }
        #expect(!model.hidesPageFromVoiceOver)
        model.askDelete()
        #expect(model.showsDelete)
        // the dialog is modal for VoiceOver: the page behind it is hidden while it asks
        #expect(model.hidesPageFromVoiceOver)
        model.keep()
        #expect(!model.showsDelete)
        #expect(!model.hidesPageFromVoiceOver)
        #expect(pops == 0)
        model.askDelete()
        model.confirmDelete()
        model.confirmDelete()
        #expect(!model.showsDelete)
        #expect(pops == 1)
        #expect(model.hasDeleted)
    }

    @Test("the launcher's start applies once: editing begins from the words; the dialog opens")
    func starts() {
        let editing = drawn(start: .editing)
        editing.applyStart(words: "words")
        #expect(editing.edit.editing)
        #expect(editing.edit.draft == "words")
        editing.edit.draft = "typed"
        editing.applyStart(words: "words")
        #expect(editing.edit.draft == "typed")
        let dialog = drawn(start: .deleteDialog)
        dialog.applyStart(words: "words")
        #expect(dialog.showsDelete)
    }

    @Test("every drawn-* launcher state is registered and drawn; the cut states aren't", arguments: EntryScenario.allCases)
    func launcherStates(scenario: EntryScenario) {
        #expect(ScreenRegistry.all["JR-4"]?.states.contains(scenario.rawValue) == true)
        #expect((scenario.drawnStart != nil) == scenario.rawValue.hasPrefix("drawn-"))
    }
}
