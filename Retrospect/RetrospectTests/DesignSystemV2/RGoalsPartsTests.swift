@testable import Retrospect
import SwiftUI
import Testing

/// V2.goals.parts: two additive variants (GL-D8, GL-D9). The existing cases keep their shape.
@MainActor
struct RGoalsPartsTests {
    @Test("an evidence row with an action opens (draws ›, is a button), as before")
    func evidenceRowWithAction() {
        let row = REvidenceRow(leading: .kind(symbol: "doc.text"), meta: "14 oct · your words", words: "up at 6:40") {}
        #expect(row.opens)
    }

    @Test("an evidence row without an action opens nothing (no ›, not a button)")
    func evidenceRowWithoutAction() {
        let row = REvidenceRow(leading: .kind(symbol: "calendar"), meta: "tue 14 oct · calendar", words: "2 hours of deep work")
        #expect(!row.opens)
        #expect(row.action == nil)
    }

    @Test("the entry bar's back-only case calls back, and rest still carries edit")
    func entryBack() {
        var backs = 0
        let bar = RTopBar.Entry.back { backs += 1 }
        if case let .back(back) = bar {
            back()
        }
        #expect(backs == 1)
        var edits = 0
        let rest = RTopBar.Entry.rest(back: {}, edit: { edits += 1 })
        if case let .rest(_, edit) = rest {
            edit()
        }
        #expect(edits == 1)
    }
}
