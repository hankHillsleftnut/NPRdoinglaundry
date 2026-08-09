import SwiftUI
import AppKit

/// Bridges the SwiftUI formatting toolbar to the active `JournalTextView`. The toolbar reads
/// `@Published` state to light up the right buttons, and calls the apply methods to format the
/// current selection (or the upcoming typing run when there's no selection).
@MainActor
final class EditorController: ObservableObject {
    weak var textView: JournalTextView?

    @Published var isBold = false
    @Published var isItalic = false
    /// 0 = body, 1 = title, 2 = heading, 3 = subhead.
    @Published var headingLevel = 0

    /// Live word count for the current entry (quiet feedback for freewriting).
    @Published var wordCount = 0

    /// True while the user is actively typing — used to fade the chrome (toolbar/menu) away so
    /// nothing competes with the words. Resets after a short pause.
    @Published var isTyping = false
    private var typingTimer: Timer?

    /// Note a keystroke: hide the chrome and arm the reveal-on-pause timer.
    func noteTyping() {
        if !isTyping { isTyping = true }
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.isTyping = false }
        }
    }

    /// Force the chrome back (e.g. pointer moved into the window).
    func revealChrome() {
        typingTimer?.invalidate()
        if isTyping { isTyping = false }
    }

    func setWordCount(_ markdown: String) {
        let n = markdown.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
        if wordCount != n { wordCount = n }
    }

    var styleName: String {
        switch headingLevel {
        case 1: return "Title"
        case 2: return "Heading"
        case 3: return "Subhead"
        default: return "Body"
        }
    }

    func toggleBold() { textView?.toggleBold(); textView?.window?.makeFirstResponder(textView); refresh() }
    func toggleItalic() { textView?.toggleItalic(); textView?.window?.makeFirstResponder(textView); refresh() }
    func applyHeading(_ level: Int) { textView?.applyHeading(level); textView?.window?.makeFirstResponder(textView); refresh() }

    /// Re-read the current formatting at the caret/selection so the toolbar reflects it.
    func refresh() {
        guard let tv = textView else { return }
        let attrs: [NSAttributedString.Key: Any]
        let sel = tv.selectedRange()
        if let storage = tv.textStorage, storage.length > 0, sel.location < storage.length {
            attrs = storage.attributes(at: sel.location, effectiveRange: nil)
        } else {
            attrs = tv.typingAttributes
        }
        let font = attrs[.font] as? NSFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        let size = font?.pointSize ?? 18
        let level = size >= 29 ? 1 : size >= 23 ? 2 : size >= 19.5 ? 3 : 0

        // Headings are bold by construction; only surface "bold" as active for body text.
        let bold = traits.contains(.bold) && level == 0
        let italic = traits.contains(.italic)
        if isBold != bold { isBold = bold }
        if isItalic != italic { isItalic = italic }
        if headingLevel != level { headingLevel = level }
    }
}
