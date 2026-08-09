import SwiftUI
import AppKit

/// NSTextView-backed rich editor. The user edits formatted text (Hedvig, headings, bold,
/// italic); the formatted text is serialized to Markdown (the stored source of truth) on a
/// short debounce so long entries don't re-serialize on every keystroke.
struct MarkdownEditor: NSViewRepresentable {
    /// The entry id currently being edited (drives reload when the selection changes).
    let entryID: UUID?
    /// Initial markdown for the current entry.
    let markdown: String
    /// Gentle prompt drawn inline as a placeholder while the entry is empty.
    let placeholder: String
    /// Drives the formatting toolbar (active state + apply actions) for the live text view.
    let controller: EditorController
    /// Called (debounced) with the entry id + new markdown whenever the text changes.
    let onChange: (UUID?, String) -> Void
    /// Called on each meaningful keystroke (for the session monitor).
    let onActivity: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // Build the text system explicitly so the container width reliably tracks the view width
        // (reusing `scrollableTextView()`'s shared container drops width-tracking on resize, which
        // made long lines run off the right edge instead of wrapping).
        let container = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0 // first glyph sits exactly on the column's left edge
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        let storage = NSTextStorage()
        storage.addLayoutManager(layoutManager)

        let journal = JournalTextView(frame: .zero, textContainer: container)

        journal.delegate = context.coordinator
        journal.isRichText = true
        journal.allowsUndo = true
        journal.isAutomaticQuoteSubstitutionEnabled = true
        journal.isAutomaticDashSubstitutionEnabled = false // don't rewrite `--`/hyphens mid-thought
        journal.isAutomaticSpellingCorrectionEnabled = false
        journal.isAutomaticTextReplacementEnabled = false
        journal.isContinuousSpellCheckingEnabled = false   // no red squiggles on a calm surface
        journal.isGrammarCheckingEnabled = false           // no blue grammar squiggles either
        // Pin the editor to the light appearance. The page is always white, so without this the
        // dynamic default text color (`NSColor.textColor`) resolves to WHITE in macOS dark mode —
        // any run/typing state lacking an explicit ink color would render white-on-white.
        journal.appearance = NSAppearance(named: .aqua)
        journal.usesAdaptiveColorMappingForDarkAppearance = false
        journal.drawsBackground = false
        journal.insertionPointColor = Ink.nsInsertion
        journal.selectedTextAttributes = [.backgroundColor: Ink.nsSelection] // warm, not system blue
        journal.textContainerInset = NSSize(width: 0, height: 16)
        journal.font = Typeface.nsHedvig(18)
        journal.typingAttributes = MarkdownSerializer.baseAttributes(headingLevel: 0)
        journal.textColor = Ink.nsPrimary
        journal.minSize = NSSize(width: 0, height: 0)
        journal.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        journal.isVerticallyResizable = true
        journal.isHorizontallyResizable = false
        journal.autoresizingMask = [.width]
        journal.placeholder = placeholder

        let scroll = NSScrollView()
        scroll.documentView = journal
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false // no visible scrollbar — trackpad/scroll still works
        scroll.hasHorizontalScroller = false
        scroll.automaticallyAdjustsContentInsets = false
        scroll.verticalScrollElasticity = .allowed
        // Generous bottom room (set dynamically in JournalTextView.layout) gives a typewriter feel:
        // the active line floats in the upper-middle rather than crawling along the bottom edge.
        scroll.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 240, right: 0)

        context.coordinator.textView = journal
        controller.textView = journal
        context.coordinator.loadIfNeeded(entryID: entryID, markdown: markdown)
        controller.refresh()
        // Focus the editor as soon as it's on screen so you can type immediately on launch.
        DispatchQueue.main.async { journal.window?.makeFirstResponder(journal) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if let journal = scroll.documentView as? JournalTextView {
            journal.placeholder = placeholder
            controller.textView = journal
        }
        context.coordinator.loadIfNeeded(entryID: entryID, markdown: markdown)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var textView: NSTextView?
        private var hasLoaded = false
        private var loadedID: UUID?
        private var isProgrammatic = false
        private var pendingSerialize: DispatchWorkItem?

        init(_ parent: MarkdownEditor) { self.parent = parent }

        /// Reload the text only when the selected entry actually changes (not on every keystroke).
        func loadIfNeeded(entryID: UUID?, markdown: String) {
            if hasLoaded && loadedID == entryID { return }
            // Flush any pending edit for the *previous* entry before swapping content in.
            flushPending()
            hasLoaded = true
            loadedID = entryID
            guard let tv = textView else { return }
            isProgrammatic = true
            let attr = MarkdownSerializer.attributed(from: markdown)
            tv.textStorage?.setAttributedString(attr)
            tv.typingAttributes = MarkdownSerializer.baseAttributes(headingLevel: 0)
            // Place the caret at the end of the existing text and focus, so switching entries
            // drops you straight into writing rather than leaving an unplaced cursor.
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
            tv.window?.makeFirstResponder(tv)
            isProgrammatic = false
            tv.needsDisplay = true // refresh placeholder visibility
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammatic, let tv = textView else { return }
            parent.onActivity()                  // cheap, immediate (session monitor)
            parent.controller.noteTyping()        // fade the chrome away while writing
            (tv as? JournalTextView)?.needsDisplay = true
            // Debounce the (potentially O(n)) markdown serialization off the keystroke path.
            pendingSerialize?.cancel()
            let id = loadedID
            let work = DispatchWorkItem { [weak self] in
                guard let self, let storage = self.textView?.textStorage else { return }
                let md = MarkdownSerializer.markdown(from: storage)
                self.parent.controller.setWordCount(md)
                self.parent.onChange(id, md)
            }
            pendingSerialize = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }

        /// Commit any debounced edit immediately (blur, entry switch, app teardown).
        func flushPending() {
            guard let work = pendingSerialize else { return }
            work.cancel()
            pendingSerialize = nil
            guard let storage = textView?.textStorage else { return }
            parent.onChange(loadedID, MarkdownSerializer.markdown(from: storage))
        }

        func textDidEndEditing(_ notification: Notification) { flushPending() }

        /// Keep the formatting toolbar in sync with the caret/selection.
        func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller.refresh()
        }
    }
}

/// NSTextView subclass that adds journaling-friendly behavior: an inline placeholder prompt,
/// plain-text paste (keeps the page in Hedvig and protects the Markdown serializer), heading
/// styles that don't bleed past a newline, click-anywhere-to-write, and formatting shortcuts
/// (⌘B bold · ⌘I italic · ⌘⌥1/2/3 headings · ⌘⌥0 body).
final class JournalTextView: NSTextView {

    /// Gentle prompt shown while the entry is empty, aligned to where typing begins.
    var placeholder: String = "" { didSet { needsDisplay = true } }

    // MARK: Inline placeholder

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Typeface.nsHedvigItalic(18),
            .foregroundColor: Ink.nsPlaceholder,
        ]
        // Same origin the first typed glyph will occupy → prompt and text share the line + left edge.
        let origin = NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
                             y: textContainerInset.height)
        (placeholder as NSString).draw(at: origin, withAttributes: attrs)
    }

    // MARK: Focus on summon (global hotkey / window activation)

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowBecameKey),
                                                   name: NSWindow.didBecomeKeyNotification, object: window)
        }
    }

    @objc private func windowBecameKey() { window?.makeFirstResponder(self) }

    // MARK: Click-anywhere-to-write — keep the text view tall enough to fill the viewport so
    // clicking the empty area below the text still lands the caret (at the end of the entry).

    private var lastClipHeight: CGFloat = -1

    override func layout() {
        super.layout()
        guard let scroll = enclosingScrollView else { return }
        let clipHeight = scroll.contentView.bounds.height
        let target = clipHeight - textContainerInset.height
        if minSize.height != target {
            minSize = NSSize(width: minSize.width, height: target)
            if bounds.height < target { setFrameSize(NSSize(width: bounds.width, height: target)) }
        }
        // Typewriter cushion: scale the bottom scroll room with the viewport so the active line
        // can float to roughly the upper-middle instead of hugging the bottom edge.
        if abs(clipHeight - lastClipHeight) > 1 {
            lastClipHeight = clipHeight
            scroll.contentInsets.bottom = max(160, clipHeight * 0.5)
        }
    }

    // MARK: Plain-text paste

    override func paste(_ sender: Any?) {
        guard let raw = NSPasteboard.general.string(forType: .string) else { super.paste(sender); return }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: raw) else { return }
        // Re-style to the current (body) typing attributes — foreign fonts/sizes would otherwise
        // be mis-read as headings by the size-based Markdown serializer.
        let styled = NSAttributedString(string: raw, attributes: typingAttributes)
        textStorage?.replaceCharacters(in: range, with: styled)
        didChangeText()
    }

    // MARK: Markdown shortcuts as you type — "# " / "## " / "### " at the start of a line turns
    // it into a heading (the markers are consumed), matching the toolbar styles.

    override func insertText(_ string: Any, replacementRange: NSRange) {
        if let s = string as? String, s == " ", let level = headingMarkerLevelAtCaret() {
            let ns = self.string as NSString
            let lineStart = ns.lineRange(for: selectedRange()).location
            let markerRange = NSRange(location: lineStart, length: selectedRange().location - lineStart)
            guard shouldChangeText(in: markerRange, replacementString: "") else { return }
            textStorage?.replaceCharacters(in: markerRange, with: "")
            didChangeText()
            applyHeading(level) // empty line → sets typing attributes to the heading style
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    /// Returns the heading level if the text from the line start to the caret is exactly #, ##, ###.
    private func headingMarkerLevelAtCaret() -> Int? {
        let sel = selectedRange()
        guard sel.length == 0 else { return nil }
        let ns = string as NSString
        let lineStart = ns.lineRange(for: sel).location
        let prefix = ns.substring(with: NSRange(location: lineStart, length: sel.location - lineStart))
        switch prefix {
        case "#": return 1
        case "##": return 2
        case "###": return 3
        default: return nil
        }
    }

    // MARK: Return — continue bullet lists, and don't let heading styling bleed onward

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        var line = ns.substring(with: lineRange)
        while line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }

        if let bullet = leadingBullet(of: line) {
            if line.count == bullet.count {
                // Empty bullet → exit the list: clear the marker, then a normal newline.
                let markerRange = NSRange(location: lineRange.location, length: bullet.count)
                if shouldChangeText(in: markerRange, replacementString: "") {
                    textStorage?.replaceCharacters(in: markerRange, with: "")
                    didChangeText()
                }
                super.insertNewline(sender)
            } else {
                // Continue the list with a fresh bullet on the next line.
                super.insertNewline(sender)
                insertText(bullet, replacementRange: selectedRange())
            }
            return
        }

        super.insertNewline(sender)
        if let font = typingAttributes[.font] as? NSFont, font.pointSize >= 19.5 {
            // Coming off a heading line — resume in body so the next paragraph isn't huge/bold.
            typingAttributes = MarkdownSerializer.baseAttributes(headingLevel: 0)
        }
    }

    /// The bullet prefix ("- " or "* ", with any leading indentation) if `line` is a list item.
    private func leadingBullet(of line: String) -> String? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line.dropFirst(indent.count)
        guard rest.hasPrefix("- ") || rest.hasPrefix("* ") else { return nil }
        return String(indent) + String(rest.prefix(2))
    }

    // MARK: Tab / Shift-Tab — indent and outdent the current line (structure without the mouse)

    override func insertTab(_ sender: Any?) {
        insertText("  ", replacementRange: selectedRange()) // two spaces per indent level
    }

    override func insertBacktab(_ sender: Any?) {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        let line = ns.substring(with: lineRange)
        var remove = 0
        for ch in line.prefix(2) where ch == " " { remove += 1 }
        guard remove > 0 else { return }
        let r = NSRange(location: lineRange.location, length: remove)
        if shouldChangeText(in: r, replacementString: "") {
            textStorage?.replaceCharacters(in: r, with: "")
            didChangeText()
        }
    }

    // MARK: Formatting commands (shared by ⌘-shortcuts and the toolbar)

    func toggleBold() { toggleTrait(.bold) }
    func toggleItalic() { toggleTrait(.italic) }
    func applyHeading(_ level: Int) { setHeading(level) }

    /// Insert the current time inline (⌘⇧T) — handy for timestamped stream-of-consciousness logs.
    private func insertTimestamp() {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        insertText(f.string(from: Date()) + " ", replacementRange: selectedRange())
    }

    // MARK: Formatting shortcuts

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        guard cmd, let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        let shift = flags.contains(.shift)
        switch (chars, opt) {
        case ("b", false): toggleTrait(.bold); return true
        case ("i", false): toggleTrait(.italic); return true
        case ("t", false) where shift: insertTimestamp(); return true
        case ("1", true): setHeading(1); return true
        case ("2", true): setHeading(2); return true
        case ("3", true): setHeading(3); return true
        case ("0", true): setHeading(0); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }

    private func toggleTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        guard let storage = textStorage else { return }
        let range = selectedRange()
        guard range.length > 0 else {
            // Toggle typing attributes for the next characters.
            toggleTypingTrait(trait); return
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let current = (value as? NSFont) ?? Typeface.nsHedvig(18)
            var traits = current.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            let desc = current.fontDescriptor.withSymbolicTraits(traits)
            if let newFont = NSFont(descriptor: desc, size: current.pointSize) {
                storage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        storage.endEditing()
        didChangeText()
    }

    private func toggleTypingTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        var attrs = typingAttributes
        let current = (attrs[.font] as? NSFont) ?? Typeface.nsHedvig(18)
        var traits = current.fontDescriptor.symbolicTraits
        if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
        if let newFont = NSFont(descriptor: current.fontDescriptor.withSymbolicTraits(traits), size: current.pointSize) {
            attrs[.font] = newFont
            typingAttributes = attrs
        }
    }

    private func setHeading(_ level: Int) {
        guard let storage = textStorage else { return }
        let lineRange = (string as NSString).lineRange(for: selectedRange())
        guard lineRange.length >= 0 else { return }
        let attrs = MarkdownSerializer.attributes(headingLevel: level, bold: false, italic: false)
        if lineRange.length > 0 {
            storage.beginEditing()
            storage.setAttributes(attrs, range: lineRange)
            storage.endEditing()
        }
        typingAttributes = attrs
        didChangeText()
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
