import SwiftUI

/// Geometric tokens, ported from the iOS `DesignSystem` (8pt grid, card radius 16, ~15px gap).
enum Metrics {
    // Spacing — 8pt grid
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    // Card geometry
    static let cardRadius: CGFloat = 16
    static let innerCardRadius: CGFloat = 12
    /// The "card inside a card" breathing gap between outer cream card and inner page.
    static let cardGap: CGFloat = 12
    static let cardPadding: CGFloat = 20

    // Sidebar reveal
    static let sidebarWidth: CGFloat = 248
    static let revealDuration: Double = 0.32

    // Writing measure
    static let writingMaxWidth: CGFloat = 680
    static let writingLineSpacing: CGFloat = 7
}
