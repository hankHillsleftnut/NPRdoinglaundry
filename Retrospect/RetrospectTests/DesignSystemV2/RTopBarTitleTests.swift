@testable import Retrospect
import SwiftUI
import Testing

/// V2 lane 0 · the tab pages' top bar (c:top-bar/title/rest: PC-1 FZM-0, GL-1 1G3J-0, YO-1 1G7X-0):
/// no leading button; Paper's trailing inset follows what sits there.
@MainActor
struct RTopBarTitleTests {
    @Test("trailing inset: 16 beside nothing or a 44 button, 24 beside 36-tall content (Paper)")
    func insets() {
        #expect(RTopBar.trailingInset(.none) == 16)
        #expect(RTopBar.trailingInset(.iconButton(symbol: "plus", label: "add a goal") {}) == 16)
        #expect(RTopBar.trailingInset(.content(AnyView(EmptyView()))) == 24)
        #expect(RDimension.spaceScreenMargin == 24)
    }
}
