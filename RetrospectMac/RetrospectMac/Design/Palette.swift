import SwiftUI
import AppKit

/// Retrospect macOS journal palette — "ink on cream".
///
/// Ported from the iOS `LinearColors` design system, but the journal is intentionally a
/// fixed light/paper surface (not adaptive), so these are plain non-adaptive colors that
/// compile natively on macOS without UIKit. RGB values match the iOS tokens exactly.
enum Ink {

    // MARK: Paper (backgrounds)

    /// #FBF5ED — rich warm cream, the outer card / window surface.
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.93)
    /// #F5EEE3 — deeper cream, used behind the inner card (the "card in a card" gap).
    static let creamDeep = Color(red: 0.96, green: 0.93, blue: 0.89)
    /// Pure white — the inner writing page.
    static let page = Color.white

    // MARK: Ink (text)

    /// #473D38 — warm charcoal, primary writing ink.
    static let primary = Color(red: 0.28, green: 0.24, blue: 0.22)
    /// #2E2420 — darker warm brown for emphasized headings.
    static let emphasis = Color(red: 0.18, green: 0.14, blue: 0.12)
    /// #80736B — medium warm gray, secondary text.
    static let secondary = Color(red: 0.50, green: 0.45, blue: 0.42)
    /// #ADA097 — light warm gray, tertiary / metadata.
    static let tertiary = Color(red: 0.68, green: 0.63, blue: 0.59)
    /// Warm placeholder text / faded prompt.
    static let placeholder = Color(red: 0.75, green: 0.70, blue: 0.65)

    // MARK: Accent (ivory)

    /// #EDE0CC — creamy ivory accent.
    static let accent = Color(red: 0.93, green: 0.88, blue: 0.80)
    /// #CCBDA6 — deeper warm ivory.
    static let accentDeep = Color(red: 0.80, green: 0.74, blue: 0.65)

    // MARK: Lines & shadow

    /// #E3D9CC — warm hairline border.
    static let border = Color(red: 0.89, green: 0.85, blue: 0.80)
    /// Gentle warm card shadow.
    static let shadow = Color(red: 0.80, green: 0.74, blue: 0.65).opacity(0.18)

    // MARK: Status

    static let success = Color(red: 0.45, green: 0.65, blue: 0.40)
    static let warning = Color(red: 0.85, green: 0.65, blue: 0.25)
    static let error = Color(red: 0.80, green: 0.35, blue: 0.30)

    // MARK: AppKit bridges (for NSTextView)

    static let nsPrimary = NSColor(calibratedRed: 0.28, green: 0.24, blue: 0.22, alpha: 1)
    static let nsEmphasis = NSColor(calibratedRed: 0.18, green: 0.14, blue: 0.12, alpha: 1)
    static let nsPage = NSColor.white
    static let nsInsertion = NSColor(calibratedRed: 0.80, green: 0.35, blue: 0.25, alpha: 1) // warm terracotta caret
    /// Faded warm placeholder ink for the inline prompt (matches `Ink.placeholder`).
    static let nsPlaceholder = NSColor(calibratedRed: 0.75, green: 0.70, blue: 0.65, alpha: 1)
    /// Warm ivory selection highlight (matches the cream accent) instead of jarring system blue.
    static let nsSelection = NSColor(calibratedRed: 0.80, green: 0.74, blue: 0.65, alpha: 0.45)
}
