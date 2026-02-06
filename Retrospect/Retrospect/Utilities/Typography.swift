import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIFont = NSFont
#endif

// Import LinearColors for text color references
// (Colors are accessed via LinearColors struct)

// MARK: - Font Weight Mapping
private extension Font.Weight {
    var libreBaskervilleFontName: String {
        switch self {
        case .ultraLight: return "LibreBaskerville"
        case .thin: return "LibreBaskerville"
        case .light: return "LibreBaskerville"
        case .regular: return "LibreBaskerville"
        case .medium: return "LibreBaskerville"
        case .semibold: return "LibreBaskerville-Bold"
        case .bold: return "LibreBaskerville-Bold"
        case .heavy: return "LibreBaskerville-Bold"
        case .black: return "LibreBaskerville-Bold"
        default: return "LibreBaskerville"
        }
    }
    
    var interFontName: String {
        switch self {
        case .ultraLight: return "Inter-Thin"
        case .thin: return "Inter-Thin"
        case .light: return "Inter-Light"
        case .regular: return "Inter-Regular"
        case .medium: return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold: return "Inter-Bold"
        case .heavy: return "Inter-ExtraBold"
        case .black: return "Inter-Black"
        default: return "Inter-Regular"
        }
    }
}

// === TYPOGRAPHY SYSTEM ===
// Elegant serif typography with vintage charm and modern readability (Libre Baskerville)
// Clean, modern sans-serif typography for subtitles and UI elements (Inter)
extension Font {
    // === CORE LIBRE BASKERVILLE SYSTEM ===
    private static func libreBaskerville(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit) || canImport(AppKit)
        // Try to load the specific weight variant first
        let fontName = weight.libreBaskervilleFontName
        if let customFont = UIFont(name: fontName, size: size) {
            return Font(customFont)
        }
        
        // Fall back to regular weight if specific weight isn't available
        if fontName != "LibreBaskerville", 
           let regularFont = UIFont(name: "LibreBaskerville", size: size) {
            return Font(regularFont).weight(weight)
        }
        
        // Fall back to system serif font
        return .system(size: size, weight: weight, design: .serif)
        #else
        // Fall back to system serif font for other platforms
        return .system(size: size, weight: weight, design: .serif)
        #endif
    }
    
    // === CORE INTER SYSTEM ===
    private static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit) || canImport(AppKit)
        // Try to load the specific weight variant first
        let fontName = weight.interFontName
        if let customFont = UIFont(name: fontName, size: size) {
            return Font(customFont)
        }
        
        // Fall back to regular weight if specific weight isn't available
        if fontName != "Inter-Regular", 
           let regularFont = UIFont(name: "Inter-Regular", size: size) {
            return Font(regularFont).weight(weight)
        }
        
        // Fall back to system sans-serif font
        return .system(size: size, weight: weight, design: .default)
        #else
        // Fall back to system sans-serif font for other platforms
        return .system(size: size, weight: weight, design: .default)
        #endif
    }
    
    // === EB GARAMOND SYSTEM (FOR TITLES) ===
    private static func ebGaramond(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit) || canImport(AppKit)
        let fontName = "EBGaramond12-Regular" // Using 12pt optical size for titles
        
        if let customFont = UIFont(name: fontName, size: size) {
            return Font(customFont)
        }
        
        // Fall back to system serif font
        return .system(size: size, weight: weight, design: .serif)
        #else
        // Fall back to system serif font for other platforms
        return .system(size: size, weight: weight, design: .serif)
        #endif
    }
    
    // === EB GARAMOND ITALIC SYSTEM (FOR MINIMAL HOME SCREEN) ===
    private static func ebGaramondItalic(size: CGFloat) -> Font {
        #if canImport(UIKit) || canImport(AppKit)
        // Try 08 Italic first (more elegant for display), then 12 Italic
        let fontNames = ["EBGaramond08-Italic", "EBGaramond12-Italic"]
        
        for fontName in fontNames {
            if let customFont = UIFont(name: fontName, size: size) {
                return Font(customFont)
            }
        }
        
        // Fall back to system serif italic
        return .system(size: size, design: .serif).italic()
        #else
        return .system(size: size, design: .serif).italic()
        #endif
    }
    
    // === SF PRO ROUNDED SYSTEM (FOR SUBTITLES) ===
    private static func sfProRounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    // === SEMANTIC FONT HIERARCHY (MIXED SERIF & SANS-SERIF) ===
    // Display - Hero text, large titles (28pt, Regular) - EB Garamond for elegant titles (increased size)
    static let geistDisplay = ebGaramond(size: 28, weight: .regular)
    
    // Title - Page titles, main headers (24pt, Regular) - EB Garamond for elegant titles (increased size)
    static let geistTitle = ebGaramond(size: 24, weight: .regular)
    
    // Headline - Section headers (20pt, Regular) - EB Garamond for elegant titles (increased size)
    static let geistHeadline = ebGaramond(size: 20, weight: .regular)
    
    // Subheadline - Secondary headers (16pt, Medium) - SF Pro Rounded for clean subtitles
    static let geistSubheadline = sfProRounded(size: 16, weight: .medium)
    
    // Body - Main content, descriptions (16pt, Regular) - SF Pro Rounded for clean readability
    static let geistBody = sfProRounded(size: 16, weight: .regular)
    
    // Body Emphasis - Emphasized body text (16pt, Medium) - SF Pro Rounded with medium weight
    static let geistBodyEmphasis = sfProRounded(size: 16, weight: .medium)
    
    // Button - Button text (16pt, Medium) - SF Pro Rounded for modern buttons
    static let geistButton = sfProRounded(size: 16, weight: .medium)
    
    // Caption - Supporting text, metadata (14pt, Regular) - SF Pro Rounded for clean subtitles
    static let geistCaption = sfProRounded(size: 14, weight: .regular)
    
    // Label - Form labels, small text (14pt, Regular) - SF Pro Rounded for clean labels
    static let geistLabel = sfProRounded(size: 14, weight: .regular)
    
    // Small - Very small text, fine print (13pt, Regular) - SF Pro Rounded for consistency
    static let geistSmall = sfProRounded(size: 13, weight: .regular)
    
    // === MINIMAL HOME SCREEN TYPOGRAPHY ===
    // Italic serif for the evocative journaling headline
    static let minimalHeadline = ebGaramondItalic(size: 56)
    static let minimalPageHeader = ebGaramondItalic(size: 46)
    static let minimalInput = sfProRounded(size: 16, weight: .regular)
    static let minimalTabLabel = sfProRounded(size: 11, weight: .medium)
}

// === LINE SPACING & KERNING ===
// Optimized for mixed Libre Baskerville (serif) and Inter (sans-serif) typography
struct TypographySpacing {
    // Line spacing (points) - Increased for serif readability
    static let displayLineSpacing: CGFloat = 8      // More generous for serif display
    static let titleLineSpacing: CGFloat = 6        // Enhanced for serif titles
    static let headlineLineSpacing: CGFloat = 5     // Better for serif headers
    static let subheadlineLineSpacing: CGFloat = 2  // Tighter for Inter (sans-serif)
    static let bodyLineSpacing: CGFloat = 5         // Enhanced readability for serif body
    static let captionLineSpacing: CGFloat = 2      // Tighter for Inter (sans-serif)
    static let labelLineSpacing: CGFloat = 2        // Better spacing for serif labels
}

// === KERNING OPTIMIZATION ===
// Strategic kerning for mixed Libre Baskerville (serif) and Inter (sans-serif) typography
struct TypographyKerning {
    // Adjusted kerning for serif elegance and readability
    static let displayKerning: CGFloat = -0.5    // Tighter for emphasis text
    static let titleKerning: CGFloat = -0.4      // Tighter for emphasis titles
    static let headlineKerning: CGFloat = -0.3   // Tighter for emphasis headlines
    
    // Balanced kerning for serif body text
    static let bodyKerning: CGFloat = 0.1        // Slight opening for serif readability
    
    // Emphasis text gets tighter kerning for visual weight
    static let bodyEmphasisKerning: CGFloat = -0.2  // Tighter for emphasized body text
    
    // Inter-specific kerning for subtitles
    static let captionKerning: CGFloat = -0.1    // Slightly tighter for Inter (sans-serif)
    static let subheadlineKerning: CGFloat = -0.1 // Slightly tighter for Inter (sans-serif)
    
    // Serif-specific kerning
    static let smallKerning: CGFloat = 0.4       // Extra opening for small serif text
    static let labelKerning: CGFloat = 0.2       // Better spacing for serif labels
    
    // Buttons with serif need slightly more space
    static let buttonKerning: CGFloat = 0.1      // Slight opening for serif buttons
}

// === TYPOGRAPHY MODIFIERS ===
// MARK: - View Extensions for Easy Styling
extension View {
    // Display - For hero text and large titles (emphasis variant with dark color)
    func geistDisplay() -> some View {
        self.font(.geistDisplay)
            .foregroundColor(LinearColors.textDisplay)
            .kerning(TypographyKerning.displayKerning)
            .lineSpacing(TypographySpacing.displayLineSpacing)
    }
    
    // Title - For page titles and main headers (emphasis variant with dark color)
    func geistTitle() -> some View {
        self.font(.geistTitle)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.titleKerning)
            .lineSpacing(TypographySpacing.titleLineSpacing)
    }
    
    // Headline - For section headers (emphasis variant with dark color)
    func geistHeadline() -> some View {
        self.font(.geistHeadline)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.headlineKerning)
            .lineSpacing(TypographySpacing.headlineLineSpacing)
    }
    
    // Subheadline - For secondary headers using Inter (standard color)
    func geistSubheadline() -> some View {
        self.font(.geistSubheadline)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.subheadlineKerning)
            .lineSpacing(TypographySpacing.subheadlineLineSpacing)
    }
    
    // Body - For main content (standard color)
    func geistBody() -> some View {
        self.font(.geistBody)
            .foregroundColor(LinearColors.textSecondary)
            .kerning(TypographyKerning.bodyKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }
    
    // Body Emphasis - For emphasized body text (emphasis variant with dark color and tight kerning)
    func geistBodyEmphasis() -> some View {
        self.font(.geistBodyEmphasis)
            .foregroundColor(LinearColors.textEmphasis)
            .kerning(TypographyKerning.bodyEmphasisKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }
    
    // Button - For button text (standard color)
    func geistButton() -> some View {
        self.font(.geistButton)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.buttonKerning)
            .lineSpacing(TypographySpacing.bodyLineSpacing)
    }
    
    // Caption - For supporting text and metadata using Inter (tertiary color)
    func geistCaption() -> some View {
        self.font(.geistCaption)
            .foregroundColor(LinearColors.textTertiary)
            .kerning(TypographyKerning.captionKerning)
            .lineSpacing(TypographySpacing.captionLineSpacing)
    }
    
    // Label - For form labels and interactive elements (primary color)
    func geistLabel() -> some View {
        self.font(.geistLabel)
            .foregroundColor(LinearColors.textPrimary)
            .kerning(TypographyKerning.labelKerning)
            .lineSpacing(TypographySpacing.labelLineSpacing)
    }
    
    // Small - For fine print and legal text (tertiary color)
    func geistSmall() -> some View {
        self.font(.geistSmall)
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
    // === SERIF FONT ALIASES (NOW MIXED TYPOGRAPHY) ===
    // Titles use EB Garamond (larger sizes), All body text and subtitles use SF Pro Rounded
    static let serifDisplay = Font.geistDisplay      // EB Garamond (28pt)
    static let serifTitle = Font.geistTitle          // EB Garamond (24pt)
    static let serifHeadline = Font.geistHeadline    // EB Garamond (20pt)
    static let serifSubheadline = Font.geistSubheadline // SF Pro Rounded
    static let serifBody = Font.geistBody            // SF Pro Rounded
    static let serifBodyEmphasis = Font.geistBodyEmphasis // SF Pro Rounded
    static let serifButton = Font.geistButton        // SF Pro Rounded
    static let serifCaption = Font.geistCaption      // SF Pro Rounded
    static let serifLabel = Font.geistLabel          // SF Pro Rounded
    static let serifSmall = Font.geistSmall          // SF Pro Rounded
}

// MARK: - View Extension Aliases
public extension View {
    // === SERIF VIEW EXTENSIONS (NOW MIXED TYPOGRAPHY) ===
    // Titles use EB Garamond (larger sizes), All body text and subtitles use SF Pro Rounded
    func serifDisplay() -> some View { self.geistDisplay() }
    func serifTitle() -> some View { self.geistTitle() }
    func serifHeadline() -> some View { self.geistHeadline() }
    func serifSubheadline() -> some View { self.geistSubheadline() }
    func serifBody() -> some View { self.geistBody() }
    func serifBodyEmphasis() -> some View { self.geistBodyEmphasis() }
    func serifButton() -> some View { self.geistButton() }
    func serifCaption() -> some View { self.geistCaption() }
    func serifLabel() -> some View { self.geistLabel() }
    func serifSmall() -> some View { self.geistSmall() }
} 