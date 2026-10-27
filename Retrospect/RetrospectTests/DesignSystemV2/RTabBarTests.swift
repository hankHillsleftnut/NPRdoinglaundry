@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · the tab bar: four places in Paper's order, lowercase labels, a real SF Symbol for each,
/// and Paper's slot numbers in the tokens (c:tab-bar/item B4A-0: 72 × 48, icon 22). Tokens are additive.
@MainActor
struct RTabBarTests {
    @Test("four tabs, in Paper's order, lowercase")
    func order() {
        #expect(RTab.allCases.map(\.title) == ["journal", "podcasts", "goals", "you"])
        for tab in RTab.allCases {
            #expect(tab.title == tab.title.lowercased())
        }
    }

    @Test("every tab's symbol exists on this iOS")
    func symbolsExist() {
        for tab in RTab.allCases {
            #expect(UIImage(systemName: tab.symbol) != nil, "no SF Symbol \(tab.symbol)")
        }
        #expect(Set(RTab.allCases.map(\.symbol)).count == RTab.allCases.count)
    }

    @Test("Paper's slot numbers, and the existing tab tokens unchanged")
    func tokens() {
        #expect(RDimension.sizeTabItemWidth == 72)
        #expect(RDimension.sizeTabItemHeight == 48)
        #expect(RDimension.sizeTabItemMinWidth == 64)
        #expect(RDimension.sizeTabIcon == 22)
        #expect(RIconSize.tab.points == 22)
        // additive only: what was there before stays
        #expect(RDimension.sizeTabBar == 49)
        #expect(RIconSize.regular.points == RDimension.sizeIconDefault)
        // four slots and three gaps fit an iPhone SE's width with the screen margins to spare
        let row = 4 * RDimension.sizeTabItemWidth + 3 * RDimension.space3
        #expect(row <= 375 - 2 * RDimension.spaceScreenMargin)
    }
}
