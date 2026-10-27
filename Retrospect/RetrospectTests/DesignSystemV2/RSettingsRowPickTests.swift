@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · the settings row's quick pick (decision 04: ↕ for a quick pick, › for a page; Paper DNO-0):
/// the row opens RMenu's title menu, the current value carries the check, and choosing hands it back.
@MainActor
struct RSettingsRowPickTests {
    @Test("the ↕ glyph exists; the pick carries its value and options")
    func pick() {
        #expect(UIImage(systemName: "chevron.up.chevron.down") != nil)
        let row = RSettingsRow(title: "talk or read", symbol: "waveform", trailing: .pick("talk", options: ["talk", "read"]) { _ in })
        guard case let .pick(value, options, _) = row.trailing else {
            Issue.record("expected a pick trailing")
            return
        }
        #expect(value == "talk")
        #expect(options == ["talk", "read"])
    }

    @Test("the menu has one RMenu row per option, in order, with only the current value checked")
    func menuRows() {
        let rows = RSettingsRow.pickRows(value: "1x", options: ["0.8x", "1x", "1.2x"]) { _ in }
        #expect(rows.map(\.id) == ["0.8x", "1x", "1.2x"])
        #expect(rows.map(\.title) == ["0.8x", "1x", "1.2x"])
        #expect(rows.map(\.selected) == [false, true, false])
        #expect(rows.allSatisfy { $0.disabledReason == nil && !$0.opensMore })
    }

    @Test("choosing a row hands back that option, and only that one")
    func choosing() {
        var chosen: [String] = []
        let rows = RSettingsRow.pickRows(value: "talk", options: ["talk", "read"]) { chosen.append($0) }
        rows[1].action()
        #expect(chosen == ["read"])
        rows[0].action()
        #expect(chosen == ["read", "talk"])
    }

    @Test("a value that is not among the options checks nothing")
    func unknownValue() {
        let rows = RSettingsRow.pickRows(value: "fast", options: ["talk", "read"]) { _ in }
        #expect(rows.allSatisfy { !$0.selected })
    }
}
