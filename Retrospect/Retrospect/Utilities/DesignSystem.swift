import SwiftUI

// === COSTAR-INSPIRED DESIGN SYSTEM ===
// Geometric spacing, sharp corners, and layout constants

/// === SPACING SYSTEM (8-Point Grid) ===
enum Spacing {
    // Core spacing values based on 8-point grid
    static let xs: CGFloat = 4 // Extra small - tight spacing
    static let sm: CGFloat = 8 // Small spacing
    static let md: CGFloat = 16 // Medium spacing (baseline)
    static let lg: CGFloat = 24 // Large spacing
    static let xl: CGFloat = 32 // Extra large spacing
    static let xxl: CGFloat = 48 // Massive spacing

    // === SPECIFIC USE CASES ===
    static let cardPadding: CGFloat = 20 // Internal card padding
    static let buttonPaddingH: CGFloat = 24 // Button horizontal padding
    static let buttonPaddingV: CGFloat = 16 // Button vertical padding
    static let sectionSpacing: CGFloat = 32 // Between major sections
    static let containerMargin: CGFloat = 16 // Screen edge margins - reduced for better left alignment
    static let listItemSpacing: CGFloat = 12 // Between list items
    static let formSpacing: CGFloat = 20 // Between form elements

    // === COMPONENT-SPECIFIC ===
    static let tabBarHeight: CGFloat = 80 // Tab bar height
    static let headerHeight: CGFloat = 60 // Header height
    static let inputHeight: CGFloat = 48 // Single-line input height
    static let buttonHeight: CGFloat = 48 // Standard button height
    static let cardMinHeight: CGFloat = 120 // Minimum card height

    // === SKEUOMORPHIC TILES ===
    static let skeuomorphicTileHeight: CGFloat = 75 // Fixed tile height
    static let skeuomorphicGap: CGFloat = 15 // Element gaps within tiles
}

/// === BORDER RADIUS SYSTEM (Smooth, Organic) ===
enum BorderRadius {
    static let none: CGFloat = 0 // No radius - completely sharp
    static let skeuomorphic: CGFloat = 5 // Skeuomorphic tiles - subtle and refined
    static let subtle: CGFloat = 6 // Very subtle rounding
    static let small: CGFloat = 10 // Small, gentle corners
    static let button: CGFloat = 12 // Button corners - smooth and approachable
    static let card: CGFloat = 16 // Card corners - cool and organic
    static let input: CGFloat = 12 // Input field corners - friendly
    static let large: CGFloat = 20 // Large radius for special elements
    static let pill: CGFloat = 28 // Pill shapes - softer
}

/// === BORDER WIDTH SYSTEM ===
enum BorderWidth {
    static let none: CGFloat = 0 // No border
    static let thin: CGFloat = 0.5 // Ultra-thin border
    static let standard: CGFloat = 1 // Standard border
    static let thick: CGFloat = 1.5 // Thicker mborder
    static let heavy: CGFloat = 2 // Heavy border
}

/// === ADAPTIVE SHADOW SYSTEM (Warm & Dark) ===
enum Shadows {
    /// Card shadows - adaptive and gentle
    static let cardShadow = (
        color: Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.25) // Black shadow for dark mode
                : UIColor(red: 0.75, green: 0.35, blue: 0.25, alpha: 0.08) // Terra-cotta shadow for light
        }),
        radius: CGFloat(16),
        x: CGFloat(0),
        y: CGFloat(8)
    )

    /// Button shadows - adaptive prominence
    static let buttonShadow = (
        color: Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.35) // Stronger black shadow for dark mode
                : UIColor(red: 0.75, green: 0.35, blue: 0.25, alpha: 0.15) // Terra-cotta shadow for light
        }),
        radius: CGFloat(12),
        x: CGFloat(0),
        y: CGFloat(6)
    )

    /// Input shadows - adaptive subtlety
    static let inputShadow = (
        color: Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.15) // Subtle black shadow for dark mode
                : UIColor(red: 0.68, green: 0.63, blue: 0.59, alpha: 0.10) // Warm brown tint for light
        }),
        radius: CGFloat(8),
        x: CGFloat(0),
        y: CGFloat(4)
    )

    /// Elevated elements - for overlays, modals
    static let elevatedShadow = (
        color: Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.45) // Strong black shadow for dark mode
                : UIColor(red: 0.75, green: 0.35, blue: 0.25, alpha: 0.18) // Terra-cotta shadow for light
        }),
        radius: CGFloat(20),
        x: CGFloat(0),
        y: CGFloat(10)
    )

    /// Skeuomorphic shadow - adaptive subtle depth
    static let skeuomorphicShadow = (
        color: Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.20) // Black shadow for dark mode
                : UIColor(red: 0.60, green: 0.45, blue: 0.35, alpha: 0.12) // Warm brown shadow for light
        }),
        radius: CGFloat(2),
        x: CGFloat(0),
        y: CGFloat(1)
    )
}

/// === ANIMATION SYSTEM (Premium Feel) ===
enum Animations {
    // Interaction animations
    static let buttonPress = Animation.easeOut(duration: 0.1)
    static let cardHover = Animation.easeOut(duration: 0.2)
    static let focusTransition = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let pageTransition = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let modalPresentation = Animation.spring(response: 0.5, dampingFraction: 0.9)

    // Layout animations
    static let layoutChange = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let contentExpansion = Animation.spring(response: 0.5, dampingFraction: 0.7)

    // Micro-interactions
    static let ripple = Animation.easeOut(duration: 0.15)
    static let bounce = Animation.spring(response: 0.3, dampingFraction: 0.6)
}

/// === ICON SIZE SYSTEM ===
enum IconSize {
    static let small: CGFloat = 16 // Small icons in lists, labels
    static let medium: CGFloat = 24 // Standard UI icons
    static let large: CGFloat = 32 // Prominent UI icons
    static let hero: CGFloat = 48 // Hero/feature icons
    static let massive: CGFloat = 64 // Large showcase icons

    /// Responsive sizing functions
    static func responsive(_ baseSize: CGFloat, screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGFloat {
        let scaleFactor = min(max(screenWidth / Layout.regularWidth, 0.8), 1.2)
        return baseSize * scaleFactor
    }
}

/// === LAYOUT CONSTANTS ===
enum Layout {
    // Screen breakpoints (if needed for responsive design)
    static let compactWidth: CGFloat = 375
    static let regularWidth: CGFloat = 414

    // Safe area adjustments
    static let safeAreaTopOffset: CGFloat = 8
    static let safeAreaBottomOffset: CGFloat = 16

    // Content constraints
    static let maxContentWidth: CGFloat = 600
    static let minTouchTarget: CGFloat = 44

    // Grid system
    static let gridColumns: Int = 2
    static let gridSpacing: CGFloat = 16

    // === UNIFIED CARD SYSTEM ===
    static let cardAspectRatio: CGFloat = 0.75 // More rectangular ratio (width:height)
    static let cardPeekAmount: CGFloat = 6 // Reduced from 8 to 6 for slightly wider cards
    static let cardHorizontalPadding: CGFloat = 10 // Reduced from 12 to 10 for slightly wider cards
}

/// === DESIGN SYSTEM EXTENSIONS ===
extension View {
    /// Apply card styling
    func coStarCard(hasShadow: Bool = true, borderWeight: CGFloat = 1) -> some View {
        background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(LinearColors.cardBorder, lineWidth: borderWeight)
                )
        )
        .if(hasShadow) { view in
            view.shadow(
                color: Shadows.cardShadow.color,
                radius: Shadows.cardShadow.radius,
                x: Shadows.cardShadow.x,
                y: Shadows.cardShadow.y
            )
        }
    }

    /// Conditional modifier helper
    @ViewBuilder func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Standard padding presets
    func standardPadding() -> some View {
        padding(Spacing.containerMargin)
    }

    func cardPadding() -> some View {
        padding(Spacing.cardPadding)
    }

    func sectionSpacing() -> some View {
        padding(.bottom, Spacing.sectionSpacing)
    }

    /// === SKEUOMORPHIC TILE PADDING ===
    func skeuomorphicPadding() -> some View {
        padding(.top, 25)
            .padding(.leading, 30)
            .padding(.bottom, 25)
            .padding(.trailing, 15)
    }
}

/// === SKEUOMORPHIC TILE SYSTEM ===
enum SkeuomorphicTile {
    static let height: CGFloat = 60
    static let cornerRadius: CGFloat = 16 // Increased from 8 to 16 for much rounder appearance
    static let gap: CGFloat = 10 // Reduced from 15 to 10 for tighter spacing between tiles
    static let paddingTop: CGFloat = 18
    static let paddingLeading: CGFloat = 22 // Reduced from 30 to 22 to move elements left
    static let paddingBottom: CGFloat = 18
    static let paddingTrailing: CGFloat = 25 // Increased from 15 to 25 for better balance

    /// Skeuomorphic gradient background (lighter top to darker bottom)
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white, // Pure white top
                Color(red: 0.98, green: 0.98, blue: 0.98), // Very slightly gray bottom
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
