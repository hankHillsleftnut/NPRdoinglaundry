@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2.topbar-back (founder, 27 Oct): the settings / entry back chevron is onboarding's 11.3pt glyph
/// (Paper ST-1 1GJ7-0, JR-4 1FRX-0 = ON-6 21CA-0), in the top bar's 36 circle.
@MainActor
struct RTopBarBackTests {
    @Test("the top bar's back uses onboarding's chevron scale, not the larger default")
    func backScale() {
        #expect(RTopBar.backGlyphScale == RIconButton.backChevronGlyphScale)
        #expect(RTopBar.backGlyphScale < RSymbol.defaultGlyphScale)
    }

    @Test("the chevron's ink is Paper's 11.3pt (±0.5) at the top bar's 20 frame")
    func inkHeight() throws {
        let points = RIconButton.Role.topBar.glyph.points * RTopBar.backGlyphScale
        let image = try #require(UIImage(
            systemName: "chevron.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: points, weight: .regular)
        ))
        let ink = image.size.height - image.alignmentRectInsets.top - image.alignmentRectInsets.bottom
        #expect(abs(ink - 11.3) <= 0.5, "ink \(ink)")
        // the default scale would draw it larger than Paper (the bug)
        let big = try #require(UIImage(
            systemName: "chevron.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: RIconButton.Role.topBar.glyph.points * RSymbol.defaultGlyphScale, weight: .regular)
        ))
        #expect(big.size.height - big.alignmentRectInsets.top - big.alignmentRectInsets.bottom > ink + 1)
    }

    @Test("the circle stays the top bar's 36 (only the glyph changed)")
    func circle() {
        #expect(RIconButton.Role.topBar.visible == RDimension.sizeControlIcon)
        #expect(RDimension.sizeControlIcon == 36)
    }
}
