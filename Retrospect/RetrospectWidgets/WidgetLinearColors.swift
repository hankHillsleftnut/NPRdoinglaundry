import SwiftUI

/// === WIDGET-SPECIFIC DESIGN SYSTEM ===
/// Copy of LinearColors.Minimal for widget extension (which cannot access main app target)
enum LinearColors {
    /// === MINIMAL/DARK UI THEME COLORS ===
    /// Static dark theme for the new minimal interface (not adaptive - always dark)
    enum Minimal {
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
