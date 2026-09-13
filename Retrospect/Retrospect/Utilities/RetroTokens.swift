import SwiftUI

/// The single write site for every design token in the app.
///
/// Before this existed the same palette was typed out twice — once as
/// `FigmaLightTheme` in fraction notation, once as `OnboardingStyle` in decimal
/// notation — plus a third legacy set in `LinearColors`, plus raw literals in
/// at least one component. Changing a colour therefore meant finding every
/// spelling of it.
///
/// `FigmaLightTheme` and `OnboardingStyle` are now thin aliases over this type.
/// Call sites are untouched and nothing changes visually; what changes is that
/// there is exactly one place to write, which is what lets a Figma variable and
/// a Swift constant stay in sync mechanically.
///
/// Figma binding: each name below maps to one variable in the `Color`,
/// `Radius`, `Spacing` or `Elevation` collection of file xWR4UGYyQEiWPrQ2SjCRed.
enum RetroTokens {

    // MARK: - Surfaces

    static let surfacePage = Color(red: 228 / 255, green: 228 / 255, blue: 226 / 255)
    static let surfaceCard = Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255)
    static let surfaceControl = Color(red: 247 / 255, green: 243 / 255, blue: 238 / 255)
    static let surfaceControlPressed = Color(red: 237 / 255, green: 233 / 255, blue: 228 / 255)
    static let surfaceRow = Color(red: 234 / 255, green: 231 / 255, blue: 227 / 255)

    // MARK: - Text
    //
    // `textPrimary` and `textPrimaryStrong` are genuinely different values that
    // arrived from the two systems (#1E1E1E vs #121212). They are kept apart
    // rather than silently collapsed — which of the two wins is a design
    // decision, not a refactor.

    static let textPrimary = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    static let textPrimaryStrong = Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255)
    static let textSecondary = Color(red: 124 / 255, green: 121 / 255, blue: 117 / 255)
    static let textMuted = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    static let textFaint = Color(red: 195 / 255, green: 194 / 255, blue: 190 / 255)
    /// Selected side-panel label. Previously a literal in `SideOverPanel` only,
    /// matching no token. Close to `textSecondary` — worth deciding whether it
    /// should simply be that.
    static let textSelected = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)

    // MARK: - Strokes
    //
    // One stroke colour was being re-multiplied at call sites (`.opacity(0.75)`
    // for card borders, `.opacity(0.65)` for dividers), which made those two
    // values invisible to a token change. They are named here so card strokes
    // can move without dividers moving with them.

    static let strokeHairline = Color.white.opacity(0.9)
    static let strokeHairlineSoft = Color.white.opacity(0.88)
    static let strokeCard = Color.white.opacity(0.675)
    static let strokeDivider = Color.white.opacity(0.585)
    static let strokeWarm = Color(red: 0.565, green: 0.384, blue: 0.133).opacity(0.15)

    // MARK: - Status

    static let statusDanger = Color(red: 0.650, green: 0.090, blue: 0.070)
    static let statusSuccess = Color(red: 0.275, green: 0.455, blue: 0.245)
    static let accentInk = Color(red: 0.160, green: 0.155, blue: 0.145)

    // MARK: - Radius
    //
    // Deliberately the literal values already in the code, not a rationalised
    // scale. Binding Figma to these is visually lossless; collapsing 10 values
    // to 5 changes pixels and should be a decision taken with a before/after in
    // front of you, not a side effect of adding tokens.

    enum Radius {
        static let r2: CGFloat = 2
        static let r4: CGFloat = 4
        static let r8: CGFloat = 8
        static let r10: CGFloat = 10
        static let r12: CGFloat = 12
        static let r14: CGFloat = 14
        static let r16: CGFloat = 16
        static let r20: CGFloat = 20
        static let r22: CGFloat = 22
        static let r44: CGFloat = 44
    }

    // MARK: - Spacing
    //
    // Also literal. This is not an 8-point grid, and 9 / 13 / 15 / 35 are
    // almost certainly accidents rather than intent — they are included so the
    // tokens cover reality, and flagged so they can be removed on purpose.

    enum Space {
        static let s4: CGFloat = 4
        static let s6: CGFloat = 6
        static let s8: CGFloat = 8
        /// Likely accidental — candidate for removal.
        static let s9: CGFloat = 9
        static let s10: CGFloat = 10
        static let s12: CGFloat = 12
        /// Likely accidental — candidate for removal.
        static let s13: CGFloat = 13
        static let s14: CGFloat = 14
        /// Likely accidental — candidate for removal.
        static let s15: CGFloat = 15
        static let s16: CGFloat = 16
        static let s18: CGFloat = 18
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s28: CGFloat = 28
        /// Likely accidental — candidate for removal.
        static let s35: CGFloat = 35
    }

    // MARK: - Elevation
    //
    // There was no shadow scale at all — 44 distinct inline recipes, several of
    // them near-duplicates of each other (0.045 / 0.05 / 0.055 at r10 y5). The
    // six below are the recurring ones. Unlike radius and spacing there is
    // nothing here worth preserving faithfully, so these are consolidated.
    //
    // Roughly 38 one-off recipes remain inline and will NOT respond to a change
    // here. They are listed in the Figma coverage page rather than hidden.

    enum Elevation {
        static let hairline = RetroShadow(opacity: 0.05, radius: 2, y: 1)
        static let raised = RetroShadow(opacity: 0.05, radius: 8, y: 2)
        static let card = RetroShadow(opacity: 0.05, radius: 10, y: 2)
        static let lifted = RetroShadow(opacity: 0.05, radius: 8, y: 4)
        static let press = RetroShadow(opacity: 0.16, radius: 4, y: 2)
        static let float = RetroShadow(opacity: 0.08, radius: 10, y: 5)
    }
}

/// A named elevation, kept as a value type so it maps one-for-one onto a Figma
/// effect style instead of being respelled at each call site.
struct RetroShadow {
    let opacity: Double
    let radius: CGFloat
    var x: CGFloat = 0
    let y: CGFloat

    var color: Color { Color.black.opacity(opacity) }
}

extension View {
    /// Applies a named elevation from `RetroTokens.Elevation`.
    func retroShadow(_ shadow: RetroShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
