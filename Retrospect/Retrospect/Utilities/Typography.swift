import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit

typealias UIFont = NSFont
#endif

// Import LinearColors for text color references
// (Colors are accessed via LinearColors struct)

/// === TYPOGRAPHY SYSTEM ===
/// Hedvig titles with SF Pro Display body/UI typography.
extension Font {
    /// === HEDVIG LETTERS SERIF SYSTEM (FOR TITLES) ===
    private static func hedvigTitle(size: CGFloat) -> Font {
        #if canImport(UIKit) || canImport(AppKit)
        if let customFont = UIFont(name: "HedvigLettersSerif-24ptRegular", size: size) {
            return Font(customFont)
        }
        return .system(size: size, weight: .regular, design: .serif)
        #else
        return .system(size: size, weight: .regular, design: .serif)
        #endif
    }

    /// === SF PRO DISPLAY SYSTEM (FOR BODY/UI) ===
    private static func sfProDisplay(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// === SEMANTIC FONT HIERARCHY ===
    /// Display - Hero text, large titles
    static let geistDisplay = hedvigTitle(size: 26)

    /// Title - Page titles, main headers
    static let geistTitle = hedvigTitle(size: 22)

    /// Headline - Section headers
    static let geistHeadline = hedvigTitle(size: 19)

    /// Subheadline - Secondary headers
    static let geistSubheadline = sfProDisplay(size: 16, weight: .medium)

    /// Body - Main content, descriptions
    static let geistBody = sfProDisplay(size: 16, weight: .regular)

    /// Body Emphasis - Emphasized body text
    static let geistBodyEmphasis = sfProDisplay(size: 16, weight: .medium)

    /// Button - Button text
    static let geistButton = sfProDisplay(size: 16, weight: .medium)

    /// Caption - Supporting text, metadata
    static let geistCaption = sfProDisplay(size: 14, weight: .regular)

    /// Label - Form labels, small text
    static let geistLabel = sfProDisplay(size: 14, weight: .regular)

    /// Small - Very small text, fine print
    static let geistSmall = sfProDisplay(size: 13, weight: .regular)

    /// === MINIMAL HOME SCREEN TYPOGRAPHY ===
    /// Journal hero — tuned closer to large-title scale (~34pt), not poster-sized.
    static let minimalHeadline = hedvigTitle(size: 34)
    /// Tab page titles — compact serif headers (~28pt).
    static let minimalPageHeader = hedvigTitle(size: 28)
    /// Side panel wordmark — compact drawer scale.
    static let minimalSidePanelBrand = hedvigTitle(size: 21)
    static let minimalInput = sfProDisplay(size: 16, weight: .regular)
    static let minimalTabLabel = sfProDisplay(size: 11, weight: .medium)
}

/// === LINE SPACING & KERNING ===
/// Optimized for mixed Hedvig (titles) and SF Pro Display (body/UI) typography.
enum TypographySpacing {
    static let displayLineSpacing: CGFloat = 8
    static let titleLineSpacing: CGFloat = 6
    static let headlineLineSpacing: CGFloat = 5
    static let subheadlineLineSpacing: CGFloat = 2
    static let bodyLineSpacing: CGFloat = 5
    static let captionLineSpacing: CGFloat = 2
    static let labelLineSpacing: CGFloat = 2
}

/// === KERNING OPTIMIZATION ===
/// Strategic kerning for mixed Hedvig titles and SF Pro Display body/UI typography.
enum TypographyKerning {
    static let displayKerning: CGFloat = -0.2
    static let titleKerning: CGFloat = -0.1
    static let headlineKerning: CGFloat = 0
    static let bodyKerning: CGFloat = 0
    static let bodyEmphasisKerning: CGFloat = 0
    static let captionKerning: CGFloat = 0
    static let subheadlineKerning: CGFloat = 0
    static let smallKerning: CGFloat = 0
    static let labelKerning: CGFloat = 0
    static let buttonKerning: CGFloat = 0
}

// === TYPOGRAPHY MODIFIERS ===
// MARK: - View Extensions for Easy Styling

extension View {
    /// Display - For hero text and large titles (emphasis variant with dark color)
    func geistDisplay() -> some View {
        font(.geistDisplay)
            .foregroundColor(LinearColors.textDisplay)
            .kerning(TypographyKerning.displayKerning)
            .lineSpacing(TypographySpacing.displayLineSpacing)
    }

    /// Title - For page titles and main headers (emphasis variant with dark color)
    func geistTitle() -> some View {
        font(.geistTitle)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.titleKerning)
            .lineSpacing(TypographySpacing.titleLineSpacing)
    }

    /// Headline - For section headers (emphasis variant with dark color)
    func geistHeadline() -> some View {
        font(.geistHeadline)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.headlineKerning)
            .lineSpacing(TypographySpacing.headlineLineSpacing)
    }

    /// Subheadline - For secondary headers using Inter (standard color)
    func geistSubheadline() -> some View {
        font(.geistSubheadline)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.subheadlineKerning)
            .lineSpacing(TypographySpacing.subheadlineLineSpacing)
    }

    /// Body - For main content (standard color)
    func geistBody() -> some View {
        font(.geistBody)
            .foregroundColor(LinearColors.textSecondary)
            .kerning(TypographyKerning.bodyKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }

    /// Body Emphasis - For emphasized body text (emphasis variant with dark color and tight kerning)
    func geistBodyEmphasis() -> some View {
        font(.geistBodyEmphasis)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.bodyEmphasisKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }

    /// Button - For button text (standard color)
    func geistButton() -> some View {
        font(.geistButton)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.buttonKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }

    /// Caption - For supporting text and metadata using Inter (tertiary color)
    func geistCaption() -> some View {
        font(.geistCaption)
            .foregroundColor(LinearColors.textTertiary)
            .kerning(TypographyKerning.captionKerning)
            .lineSpacing(TypographySpacing.captionLineSpacing)
    }

    /// Label - For form labels and interactive elements (primary color)
    func geistLabel() -> some View {
        font(.geistLabel)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.labelKerning)
            .lineSpacing(TypographySpacing.labelLineSpacing)
    }

    /// Small - For fine print and legal text (tertiary color)
    func geistSmall() -> some View {
        font(.geistSmall)
            .foregroundColor(LinearColors.textTertiary)
            .kerning(TypographyKerning.smallKerning)
            .lineSpacing(TypographySpacing.captionLineSpacing)
    }
}

// MARK: - Backward Compatibility

// These aliases maintain compatibility with existing code
// while we transition to the new naming convention

// MARK: - Font Aliases

extension Font {
    // === SERIF FONT ALIASES (NOW HEDVIG + SF PRO DISPLAY) ===
    static let serifDisplay = Font.geistDisplay
    static let serifTitle = Font.geistTitle
    static let serifHeadline = Font.geistHeadline
    static let serifSubheadline = Font.geistSubheadline
    static let serifBody = Font.geistBody
    static let serifBodyEmphasis = Font.geistBodyEmphasis
    static let serifButton = Font.geistButton
    static let serifCaption = Font.geistCaption
    static let serifLabel = Font.geistLabel
    static let serifSmall = Font.geistSmall
}

// MARK: - View Extension Aliases

public extension View {
    // === SERIF VIEW EXTENSIONS (NOW HEDVIG + SF PRO DISPLAY) ===
    func serifDisplay() -> some View { geistDisplay() }
    func serifTitle() -> some View { geistTitle() }
    func serifHeadline() -> some View { geistHeadline() }
    func serifSubheadline() -> some View { geistSubheadline() }
    func serifBody() -> some View { geistBody() }
    func serifBodyEmphasis() -> some View { geistBodyEmphasis() }
    func serifButton() -> some View { geistButton() }
    func serifCaption() -> some View { geistCaption() }
    func serifLabel() -> some View { geistLabel() }
    func serifSmall() -> some View { geistSmall() }
}
