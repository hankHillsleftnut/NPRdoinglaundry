@testable import Retrospect
import Testing

/// V2.outside · EX-4: the widgets' words and where their taps land (journey map 96p / 96q).
@MainActor
struct BriefWidgetsTests {
    @Test("the medium widget shows Paper's brief line")
    func brief() {
        #expect(SampleWidgets.brief.label == "today's brief · 4 min")
        #expect(SampleWidgets.brief.line == "a heavier week than usual, and it shows.")
    }

    @Test("small opens talk; medium opens play, then talk")
    func destinations() {
        #expect(BriefWidgetSmall.destination == .talk)
        #expect(BriefWidgetMedium.destinations == [.playBrief, .talk])
    }

    @Test("the widget mark is Paper's 16 with a 9 glyph, and the old marks don't move")
    func mark() {
        #expect(RMark.widget.size == 16)
        #expect(RMark.widget.style == .widget)
        #expect(RMark.header.size == RDimension.sizePlayerHeaderMark)
        #expect(RMark().size == RDimension.sizeMark)
        #expect(RDimension.sizeWidgetMarkGlyph == 9)
    }

    @Test("EX-4 is registered with its one state")
    func registered() {
        #expect(OutsideScreens.screens.first { $0.id == "EX-4" }?.states == ["rest"])
    }
}
