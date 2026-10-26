@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · the settings row's quick pick (decision 04: ↕ for a quick pick, › for a page; Paper DNO-0):
/// the row owns its menu, and choosing an option hands it back.
@MainActor
struct RSettingsRowPickTests {
    @Test("the ↕ glyph exists; the pick carries its value, its options, and hands back the choice")
    func pick() {
        #expect(UIImage(systemName: "chevron.up.chevron.down") != nil)
        var chosen: String?
        let row = RSettingsRow(title: "talk or read", symbol: "waveform", trailing: .pick("talk", options: ["talk", "read"]) { chosen = $0 })
        guard case let .pick(value, options, select) = row.trailing else {
            Issue.record("expected a pick trailing")
            return
        }
        #expect(value == "talk")
        #expect(options == ["talk", "read"])
        select("read")
        #expect(chosen == "read")
    }
}
