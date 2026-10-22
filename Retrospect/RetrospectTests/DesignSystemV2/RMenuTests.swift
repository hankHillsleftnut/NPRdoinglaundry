@testable import Retrospect
import Testing

/// C20: the menu grows out of its source and never off the screen; a finger over the rows maps
/// to one row.
struct RMenuTests {
    @Test("the menu grows toward leading when the source is within its width of the trailing edge")
    func growsTowardLeading() {
        #expect(RMenuPlacement.growsTowardLeading(sourceMinX: 300, containerWidth: 390, menuWidth: 196))
        #expect(!RMenuPlacement.growsTowardLeading(sourceMinX: 24, containerWidth: 390, menuWidth: 196))
    }

    @Test("the panel ends at the source's trailing edge when it grows toward leading")
    func xTowardLeading() {
        let source = CGRect(x: 250, y: 100, width: 100, height: 44)
        #expect(RMenuPlacement.x(source: source, containerWidth: 390, menuWidth: 196) == 350 - 196)
    }

    @Test("the panel starts at the source's leading edge when it fits, and never passes the margins")
    func xInsideMargins() {
        let source = CGRect(x: 24, y: 100, width: 100, height: 44)
        #expect(RMenuPlacement.x(source: source, containerWidth: 390, menuWidth: 196) == 24)
        let wide = CGRect(x: 0, y: 100, width: 100, height: 44)
        #expect(RMenuPlacement.x(source: wide, containerWidth: 390, menuWidth: 196) == RDimension.spaceScreenMargin)
    }

    @Test("the panel sits 4 below the source, or above it when it wouldn't fit below")
    func yBelowOrAbove() {
        let source = CGRect(x: 24, y: 100, width: 100, height: 44)
        #expect(RMenuPlacement.y(source: source, containerHeight: 800, menuHeight: 100) == 144 + RDimension.space1)
        let low = CGRect(x: 24, y: 700, width: 100, height: 44)
        #expect(RMenuPlacement.y(source: low, containerHeight: 800, menuHeight: 100) == 700 - RDimension.space1 - 100)
    }

    @Test("the width hugs the rows between 196 and layout.popoverMax, and fills the margins at accessibility sizes")
    func width() {
        #expect(RMenuPlacement.width(hugging: 150, containerWidth: 390, accessibilitySize: false) == RMenuPlacement.minWidth)
        #expect(RMenuPlacement.width(hugging: 220, containerWidth: 390, accessibilitySize: false) == 220)
        #expect(RMenuPlacement.width(hugging: 600, containerWidth: 390, accessibilitySize: false) == RDimension.layoutPopoverMax)
        #expect(RMenuPlacement.width(hugging: 150, containerWidth: 390, accessibilitySize: true) == 390 - 2 * RDimension.spaceScreenMargin)
    }

    @Test("a finger over the rows maps to one row, and to none outside them")
    func rowUnderFinger() {
        #expect(RMenuPlacement.row(at: 10, rowHeight: 50, count: 3) == 0)
        #expect(RMenuPlacement.row(at: 149, rowHeight: 50, count: 3) == 2)
        #expect(RMenuPlacement.row(at: 150, rowHeight: 50, count: 3) == nil)
        #expect(RMenuPlacement.row(at: -1, rowHeight: 50, count: 3) == nil)
    }

    @Test("the message menu's pill is concentric with its panel")
    func concentric() {
        #expect(RMenuKind.message.pillRadius == RDimension.radiusCard - RDimension.space1)
        #expect(RMenuKind.title.pillRadius == RDimension.radiusPopover - RDimension.space1)
    }
}
