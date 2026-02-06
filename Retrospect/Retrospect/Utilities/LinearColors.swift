import SwiftUI

// === ADAPTIVE TERRA-COTTA & CHARCOAL DESIGN SYSTEM ===
// Rich terra-cotta palette with adaptive backgrounds: warm cream (light) / charcoal grey (dark)
struct LinearColors {
    // === FOUNDATION COLORS ===
    static let pureWhite = Color.white
    
    // Light mode foundation colors
    static let warmCream = Color(red: 0.98, green: 0.96, blue: 0.93) // #FBF5ED - Rich warm cream base
    static let softCream = Color(red: 0.96, green: 0.93, blue: 0.89) // #F5EEE3 - Deeper cream variant
    
    // Dark mode foundation colors (25% darker for dramatically richer blacks)
    static let charcoalBase = Color(red: 0.09, green: 0.09, blue: 0.10) // #171719 - Deep charcoal base
    static let charcoalLight = Color(red: 0.12, green: 0.12, blue: 0.13) // #1F1F21 - Lighter charcoal
    static let charcoalCard = Color(red: 0.13, green: 0.13, blue: 0.14) // #212122 - Card charcoal
    static let metalGray = Color(red: 0.17, green: 0.17, blue: 0.18) // #2B2B2E - Metal gray
    
    // === TERRA-COTTA PALETTE (Consistent across themes) ===
    static let terraCottaPrimary = Color(red: 0.85, green: 0.47, blue: 0.35) // #D9785A - Bright terra-cotta main
    static let terraCottaLight = Color(red: 0.90, green: 0.55, blue: 0.45) // #E68C73 - Lighter terra-cotta
    static let terraCottaDark = Color(red: 0.75, green: 0.35, blue: 0.25) // #BF5940 - Deeper terra-cotta
    static let terraCottaSubtle = Color(red: 0.85, green: 0.47, blue: 0.35).opacity(0.15) // Subtle terra-cotta tint
    
    // === WARM NEUTRALS (Light mode) ===
    static let warmCharcoal = Color(red: 0.28, green: 0.24, blue: 0.22) // #473D38 - Warm dark brown
    static let warmGray = Color(red: 0.50, green: 0.45, blue: 0.42) // #80736B - Medium warm gray
    static let softBrown = Color(red: 0.68, green: 0.63, blue: 0.59) // #ADA097 - Light warm gray
    
    // === ADAPTIVE MAIN DESIGN TOKENS ===
    static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1) // Charcoal base (25% darker)
            : UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1) // Warm cream
    })
    
    static let backgroundLight = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1) // Lighter charcoal (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white
    })
    
    static let accent = terraCottaPrimary // Terra-cotta accent consistent across themes
    
    // === ADAPTIVE CARD SYSTEM ===
    static let cardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1) // Card charcoal (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white
    })
    
    static let cardBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1) // Metal gray border (25% darker)
            : UIColor(red: 0.89, green: 0.85, blue: 0.80, alpha: 1) // Warm border
    })
    
    static let cardShadow = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.25) // Black shadow for dark mode
            : UIColor(red: 0.75, green: 0.35, blue: 0.25, alpha: 0.08) // Terra-cotta shadow for light
    })
    
    // === ADAPTIVE TYPOGRAPHY HIERARCHY ===
    static let textPrimary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1) // Near white for dark mode
            : UIColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1) // Warm charcoal for light
    })
    
    static let textSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1) // Light gray for dark mode
            : UIColor(red: 0.50, green: 0.45, blue: 0.42, alpha: 1) // Warm gray for light
    })
    
    static let textTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1) // Medium gray for dark mode
            : UIColor(red: 0.68, green: 0.63, blue: 0.59, alpha: 1) // Soft brown for light
    })
    
    static let textPlaceholder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1) // Darker gray for dark mode
            : UIColor(red: 0.75, green: 0.70, blue: 0.65, alpha: 1) // Warm placeholder for light
    })
    
    // === ADAPTIVE EMPHASIS TEXT COLORS ===
    static let textEmphasis = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1) // Brightest white for dark mode
            : UIColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 1) // Darker warm brown for light
    })
    
    static let textDisplay = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white for dark mode
            : UIColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1) // Darkest warm brown for light
    })
    
    // === ADAPTIVE INPUT SYSTEM ===
    static let inputBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1) // Lighter charcoal (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white
    })
    
    static let inputBorder = cardBorder // Consistent with card borders
    static let inputFocusBorder = terraCottaPrimary // Terra-cotta focus ring (consistent)
    static let border = cardBorder // Generic border color
    
    // === ADAPTIVE BUTTON SYSTEM ===
    static let buttonBackground = terraCottaPrimary // Terra-cotta primary buttons (consistent)
    static let buttonText = pureWhite // White text on terra-cotta (consistent)
    
    static let buttonBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1) // Metal gray border (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // White border
    })
    
    static let buttonShadow = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.3) // Black shadow
            : UIColor(red: 0.75, green: 0.35, blue: 0.25, alpha: 0.20) // Terra-cotta shadow
    })
    
    static let buttonSecondaryBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) // Metal gray (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // Pure white
    })
    
    static let buttonSecondaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.85, green: 0.47, blue: 0.35, alpha: 1) // Terra-cotta on dark
            : UIColor(red: 0.85, green: 0.47, blue: 0.35, alpha: 1) // Terra-cotta on light
    })
    
    static let buttonSecondaryBorder = terraCottaPrimary // Terra-cotta borders (consistent)
    
    // === ADAPTIVE STATES & INTERACTIONS ===
    static let focusRing = terraCottaPrimary.opacity(0.3) // Warm focus indicators (consistent)
    static let hoverState = terraCottaSubtle // Subtle terra-cotta hover (consistent)
    static let pressedState = terraCottaPrimary.opacity(0.12) // Pressed states (consistent)
    
    static let disabledBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1) // Dark disabled (25% darker)
            : UIColor(red: 0.93, green: 0.90, blue: 0.87, alpha: 1) // Warm disabled
    })
    
    static let disabledText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1) // Dark disabled text
            : UIColor(red: 0.68, green: 0.63, blue: 0.59, alpha: 1) // Soft brown disabled text
    })
    
    // === STATUS COLORS (Consistent warm variants) ===
    static let successGreen = Color(red: 0.45, green: 0.65, blue: 0.40) // #73A666 - Warm green
    static let warningRed = Color(red: 0.80, green: 0.35, blue: 0.30) // #CC594D - Warm red
    static let warningYellow = Color(red: 0.85, green: 0.65, blue: 0.25) // #D9A640 - Warm amber
    
    // === BACKWARDS COMPATIBILITY ===
    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let backgroundGrey = background // For legacy code
    
    static let pureBlack = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // White in dark mode
            : UIColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1) // Warm charcoal in light
    })
    
    static let deepAccent = terraCottaDark // Legacy deep accent mapped to dark terra-cotta
    
    // === ADAPTIVE GRADIENTS & HIGHLIGHTS ===
    static let warmHighlight = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1) // Metal gray highlight (25% darker)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // White highlight
    })
    
    static let gradientStart = terraCottaLight // Warm gradient start (consistent)
    static let gradientEnd = terraCottaPrimary // Warm gradient end (consistent)
    
    // === MINIMAL/DARK UI THEME COLORS ===
    // Static dark theme for the new minimal interface (not adaptive - always dark)
    struct Minimal {
        // === BACKGROUNDS ===
        static let background = Color(red: 0.07, green: 0.07, blue: 0.08) // #121214 - Slightly lighter black
        static let backgroundElevated = Color(red: 0.08, green: 0.08, blue: 0.09) // #141417 - Elevated surfaces
        static let backgroundCard = Color(red: 0.08, green: 0.08, blue: 0.09) // #141417 - Even darker card backgrounds
        static let backgroundCardLight = Color(red: 0.12, green: 0.12, blue: 0.13) // #1F1F21 - Lighter card backgrounds for grouped containers
        static let backgroundCardHover = Color(red: 0.14, green: 0.14, blue: 0.15) // #242426 - Card hover
        static let inputBackground = Color(red: 0.16, green: 0.16, blue: 0.17) // #2A2A2B - Dark charcoal input
        static let tabBarBackground = Color(red: 0.10, green: 0.10, blue: 0.11) // #1A1A1C - Darker tab bar
        static let micButtonBackground = Color(red: 0.22, green: 0.22, blue: 0.23) // #383839 - Mic button
        static let sheetBackground = Color(red: 0.06, green: 0.06, blue: 0.07) // #101012 - Modal/sheet bg
        
        // === TEXT HIERARCHY ===
        static let headlineText = Color(red: 0.77, green: 0.72, blue: 0.65) // #C5B8A5 - Warm cream headline
        static let textPrimary = Color(red: 0.92, green: 0.92, blue: 0.94) // #EBECF0 - Primary text (near white)
        static let textSecondary = Color(red: 0.70, green: 0.70, blue: 0.73) // #B3B3BA - Secondary text
        static let textTertiary = Color(red: 0.53, green: 0.53, blue: 0.56) // #88888F - Tertiary/muted text
        static let placeholderText = Color(red: 0.40, green: 0.40, blue: 0.43) // #66666E - Placeholder text
        static let tabText = Color(red: 0.55, green: 0.55, blue: 0.58) // #8C8C94 - Tab label gray
        static let tabTextSelected = Color(red: 0.92, green: 0.92, blue: 0.94) // #EBECF0 - Selected tab text
        
        // === BORDERS & DIVIDERS ===
        static let border = Color(red: 0.20, green: 0.20, blue: 0.22) // #333338 - Standard border
        static let borderSubtle = Color(red: 0.15, green: 0.15, blue: 0.17) // #26262B - Subtle border
        static let borderFocus = Color(red: 0.85, green: 0.47, blue: 0.35) // Terra-cotta focus
        static let inputBorder = Color(red: 0.25, green: 0.25, blue: 0.26) // #404042 - Input border
        static let divider = Color(red: 0.18, green: 0.18, blue: 0.20) // #2E2E33 - Divider lines
        
        // === ACCENT COLORS ===
        static let accent = Color(red: 0.85, green: 0.47, blue: 0.35) // #D9785A - Terra-cotta accent
        static let accentLight = Color(red: 0.90, green: 0.55, blue: 0.45) // #E68C73 - Light accent
        static let accentDark = Color(red: 0.75, green: 0.35, blue: 0.25) // #BF5940 - Dark accent
        static let accentSubtle = Color(red: 0.85, green: 0.47, blue: 0.35).opacity(0.15) // Subtle accent tint
        
        // === TAB & SELECTION STATES ===
        static let tabSelectedBackground = Color(red: 0.20, green: 0.20, blue: 0.21) // #333336 - Selected tab bg
        static let selectionHighlight = Color(red: 0.85, green: 0.47, blue: 0.35).opacity(0.12) // Selection bg
        
        // === BUTTON SYSTEM ===
        static let buttonPrimary = Color(red: 0.85, green: 0.47, blue: 0.35) // #D9785A - Primary button
        static let buttonPrimaryText = Color.white
        static let buttonSecondary = Color(red: 0.16, green: 0.16, blue: 0.17) // #2A2A2B - Secondary button
        static let buttonSecondaryText = Color(red: 0.92, green: 0.92, blue: 0.94) // #EBECF0
        static let buttonSecondaryBorder = Color(red: 0.25, green: 0.25, blue: 0.27) // #404045
        static let buttonGhost = Color.clear
        static let buttonGhostText = Color(red: 0.70, green: 0.70, blue: 0.73) // #B3B3BA
        static let buttonDisabled = Color(red: 0.12, green: 0.12, blue: 0.13) // #1F1F21
        static let buttonDisabledText = Color(red: 0.35, green: 0.35, blue: 0.38) // #595961
        
        // === STATUS COLORS ===
        static let success = Color(red: 0.35, green: 0.75, blue: 0.55) // #59BF8C - Vibrant green
        static let successSubtle = Color(red: 0.35, green: 0.75, blue: 0.55).opacity(0.15)
        static let warning = Color(red: 0.95, green: 0.70, blue: 0.30) // #F2B34D - Amber warning
        static let warningSubtle = Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.15)
        static let error = Color(red: 0.95, green: 0.40, blue: 0.40) // #F26666 - Red error
        static let errorSubtle = Color(red: 0.95, green: 0.40, blue: 0.40).opacity(0.15)
        static let info = Color(red: 0.40, green: 0.65, blue: 0.95) // #66A6F2 - Blue info
        static let infoSubtle = Color(red: 0.40, green: 0.65, blue: 0.95).opacity(0.15)
        
        // === PODCAST MOOD GRADIENTS (for mesh gradients) ===
        struct Mood {
            static let positive = [
                Color(red: 0.95, green: 0.55, blue: 0.30), // Orange
                Color(red: 0.95, green: 0.75, blue: 0.35), // Yellow-orange
                Color(red: 0.90, green: 0.45, blue: 0.35)  // Warm red
            ]
            static let neutral = [
                Color(red: 0.35, green: 0.55, blue: 0.75), // Slate blue
                Color(red: 0.45, green: 0.65, blue: 0.80), // Light blue
                Color(red: 0.30, green: 0.50, blue: 0.70)  // Ocean blue
            ]
            static let reflective = [
                Color(red: 0.55, green: 0.40, blue: 0.75), // Purple
                Color(red: 0.45, green: 0.35, blue: 0.65), // Deep purple
                Color(red: 0.40, green: 0.45, blue: 0.80)  // Indigo
            ]
            static let energetic = [
                Color(red: 0.95, green: 0.40, blue: 0.45), // Bright red
                Color(red: 0.95, green: 0.60, blue: 0.35), // Orange
                Color(red: 0.95, green: 0.50, blue: 0.55)  // Coral
            ]
            static let calm = [
                Color(red: 0.35, green: 0.65, blue: 0.60), // Teal
                Color(red: 0.40, green: 0.70, blue: 0.65), // Mint
                Color(red: 0.45, green: 0.60, blue: 0.70)  // Soft blue
            ]
            static let mysterious = [
                Color(red: 0.35, green: 0.30, blue: 0.50), // Deep violet
                Color(red: 0.25, green: 0.25, blue: 0.40), // Dark purple
                Color(red: 0.20, green: 0.20, blue: 0.35)  // Near black purple
            ]
            static let happy = [
                Color(red: 0.95, green: 0.80, blue: 0.35), // Golden yellow
                Color(red: 0.95, green: 0.60, blue: 0.40), // Peach
                Color(red: 0.95, green: 0.70, blue: 0.50)  // Light orange
            ]
            static let melancholic = [
                Color(red: 0.40, green: 0.45, blue: 0.60), // Dusty blue
                Color(red: 0.35, green: 0.35, blue: 0.50), // Muted purple
                Color(red: 0.30, green: 0.35, blue: 0.45)  // Gray blue
            ]
        }
        
        // === SHADOWS ===
        static let shadowLight = Color.black.opacity(0.25)
        static let shadowMedium = Color.black.opacity(0.40)
        static let shadowHeavy = Color.black.opacity(0.60)
        
        // === OVERLAYS ===
        static let overlay = Color.black.opacity(0.50)
        static let overlayLight = Color.black.opacity(0.30)
        static let overlayHeavy = Color.black.opacity(0.70)
        
        // === RECORDING STATES ===
        static let recordingActive = Color(red: 0.95, green: 0.30, blue: 0.30) // Bright red
        static let recordingPulse = Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.3)
        
        // === PLAYER COLORS ===
        static let progressTrack = Color(red: 0.20, green: 0.20, blue: 0.22) // #333338
        static let progressFill = Color(red: 0.85, green: 0.47, blue: 0.35) // Terra-cotta
        static let waveformActive = Color(red: 0.85, green: 0.47, blue: 0.35)
        static let waveformInactive = Color(red: 0.30, green: 0.30, blue: 0.32) // #4D4D52
    }
}