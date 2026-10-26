@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · the settings row's quick pick (decision 04: ↕ for a quick pick, › for a page; Paper DNO-0).
@MainActor
struct RSettingsRowPickTests {
    @Test("the ↕ glyph exists, and the pick row builds beside the value row")
    func pick() {
        #expect(UIImage(systemName: "chevron.up.chevron.down") != nil)
        let row = RSettingsRow(title: "talk or read", symbol: "waveform", trailing: .pick("talk"))
        if case let .pick(value) = row.trailing {
            #expect(value == "talk")
        } else {
            Issue.record("expected a pick trailing")
        }
    }
}
