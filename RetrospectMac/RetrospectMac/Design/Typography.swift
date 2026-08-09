import SwiftUI
import AppKit
import CoreText

/// Hedvig Letters Serif registration + font helpers.
///
/// The iOS app uses Hedvig for titles only (SF Pro for body). On the Mac journal the
/// *writing itself* is set in Hedvig — the "inky" manuscript feel the product calls for.
enum Typeface {
    static let hedvigPostScript = "HedvigLettersSerif-24ptRegular"
    static let hedvigFamily = "Hedvig Letters Serif 24pt"

    private static var didRegister = false

    /// Register the bundled Hedvig font at launch. Safe to call more than once.
    static func register() {
        guard !didRegister else { return }
        didRegister = true
        guard let url = Bundle.main.url(forResource: "HedvigLettersSerif", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "HedvigLettersSerif", withExtension: "ttf") else {
            NSLog("[Retrospect] Hedvig font not found in bundle — falling back to system serif.")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // Already registered (e.g. via ATSApplicationFontsPath) is fine.
            NSLog("[Retrospect] Hedvig registration note: \(error?.takeUnretainedValue().localizedDescription ?? "already registered")")
        }
    }

    /// SwiftUI Hedvig at a given size, falling back to system serif.
    static func hedvig(_ size: CGFloat) -> Font {
        if NSFont(name: hedvigPostScript, size: size) != nil {
            return .custom(hedvigPostScript, size: size)
        }
        if NSFont(name: hedvigFamily, size: size) != nil {
            return .custom(hedvigFamily, size: size)
        }
        return .system(size: size, design: .serif)
    }

    /// AppKit Hedvig at a given size (for NSTextView), falling back to system serif.
    static func nsHedvig(_ size: CGFloat) -> NSFont {
        NSFont(name: hedvigPostScript, size: size)
            ?? NSFont(name: hedvigFamily, size: size)
            ?? NSFont(descriptor: NSFontDescriptor(name: "Times New Roman", size: size), size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    /// AppKit Hedvig italic — used for the gentle inline placeholder prompt.
    static func nsHedvigItalic(_ size: CGFloat) -> NSFont {
        let base = nsHedvig(size)
        let desc = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: size) ?? base
    }
}

extension Font {
    /// 34pt — journal hero / page header.
    static let journalHero = Typeface.hedvig(34)
    /// 21pt — sidebar wordmark.
    static let journalBrand = Typeface.hedvig(21)
    /// 18pt — the writing body (inky Hedvig).
    static let journalBody = Typeface.hedvig(18)
    /// 15pt — gentle prompt.
    static let journalPrompt = Typeface.hedvig(17)
    /// 13pt — entry list date / meta. Inky Hedvig (the journal reads entirely in the serif).
    static let journalMeta = Typeface.hedvig(13)
    /// 13pt — formatting toolbar labels, inky Hedvig.
    static let journalTool = Typeface.hedvig(13)
    static let journalEntryTitle = Typeface.hedvig(16)
}
