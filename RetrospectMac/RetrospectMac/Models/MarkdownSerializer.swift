import AppKit

/// Bidirectional bridge between the editor's `NSAttributedString` and Markdown on disk.
///
/// Scope is deliberately focused (journaling, not a doc editor): headings (`#`/`##`/`###`),
/// **bold**, _italic_, and plain paragraphs. This keeps the stored text clean for the agent
/// pipeline while supporting the rich formatting a writer actually reaches for.
enum MarkdownSerializer {

    // MARK: Markdown -> attributed (load into editor)

    static func attributed(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        for (idx, line) in lines.enumerated() {
            let (level, text) = headingLevel(of: line)
            let paragraph = inlineAttributed(text, headingLevel: level)
            result.append(paragraph)
            if idx < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes(headingLevel: 0)))
            }
        }
        if result.length == 0 {
            return NSAttributedString(string: "", attributes: baseAttributes(headingLevel: 0))
        }
        return result
    }

    // MARK: attributed -> Markdown (save)

    static func markdown(from attributed: NSAttributedString) -> String {
        let full = attributed.string as NSString
        guard full.length > 0 else { return "" }

        var out: [String] = []
        var index = 0
        // Strict `index < length`: when text doesn't end in a newline, `lineRange(for:)` at the
        // end of the string returns the *last line's* range (not an empty range), so a `<=` bound
        // would re-process that line forever and hang the main thread on every keystroke.
        while index < full.length {
            let lineRange = full.lineRange(for: NSRange(location: index, length: 0))
            // lineRange includes the trailing newline; trim it for processing.
            var contentRange = lineRange
            if contentRange.length > 0,
               full.substring(with: NSRange(location: contentRange.location + contentRange.length - 1, length: 1)) == "\n" {
                contentRange.length -= 1
            }
            out.append(markdownLine(from: attributed, lineRange: contentRange))
            index = NSMaxRange(lineRange) // always advances: a covering line range has length >= 1
        }
        // A trailing newline implies a final empty line that the loop above doesn't visit.
        if full.substring(from: full.length - 1) == "\n" {
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Line helpers

    private static func markdownLine(from attributed: NSAttributedString, lineRange: NSRange) -> String {
        guard lineRange.length > 0 else { return "" }

        // Heading? Detected from the font size of the first character.
        var prefix = ""
        if let font = attributed.attribute(.font, at: lineRange.location, effectiveRange: nil) as? NSFont {
            switch font.pointSize {
            case let s where s >= 29: prefix = "# "
            case let s where s >= 23: prefix = "## "
            case let s where s >= 19.5: prefix = "### "
            default: prefix = ""
            }
        }

        // Inline emphasis runs.
        var pieces: [String] = []
        attributed.enumerateAttributes(in: lineRange, options: []) { attrs, range, _ in
            var text = (attributed.string as NSString).substring(with: range)
            let traits = (attrs[.font] as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            let bold = traits.contains(.bold)
            let italic = traits.contains(.italic)
            if bold && italic { text = "***\(text)***" }
            else if bold { text = "**\(text)**" }
            else if italic { text = "_\(text)_" }
            pieces.append(text)
        }
        // Trim trailing whitespace so the stored Markdown stays clean (and a stray double-space
        // doesn't become an accidental hard line break).
        var line = prefix + pieces.joined()
        while line.hasSuffix(" ") || line.hasSuffix("\t") { line.removeLast() }
        return line
    }

    private static func headingLevel(of line: String) -> (Int, String) {
        if line.hasPrefix("### ") { return (3, String(line.dropFirst(4))) }
        if line.hasPrefix("## ") { return (2, String(line.dropFirst(3))) }
        if line.hasPrefix("# ") { return (1, String(line.dropFirst(2))) }
        return (0, line)
    }

    // MARK: - Inline parsing (bold / italic)

    private static func inlineAttributed(_ text: String, headingLevel: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let s = Array(text)
        var i = 0
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            result.append(NSAttributedString(string: buffer, attributes: attributes(headingLevel: headingLevel, bold: false, italic: false)))
            buffer = ""
        }
        func emit(_ str: String, bold: Bool, italic: Bool) {
            guard !str.isEmpty else { return }
            result.append(NSAttributedString(string: str, attributes: attributes(headingLevel: headingLevel, bold: bold, italic: italic)))
        }

        while i < s.count {
            // ***bold italic***
            if match(s, i, "***"), let close = find(s, i + 3, "***") {
                flush(); emit(String(s[(i + 3)..<close]), bold: true, italic: true); i = close + 3; continue
            }
            // **bold**
            if match(s, i, "**"), let close = find(s, i + 2, "**") {
                flush(); emit(String(s[(i + 2)..<close]), bold: true, italic: false); i = close + 2; continue
            }
            // _italic_ or *italic* (non-empty inner span)
            if (match(s, i, "_") || match(s, i, "*")) {
                let marker = String(s[i])
                if let close = find(s, i + 1, marker), close > i + 1 {
                    flush(); emit(String(s[(i + 1)..<close]), bold: false, italic: true); i = close + 1; continue
                }
            }
            buffer.append(s[i]); i += 1
        }
        flush()
        if result.length == 0 {
            return NSAttributedString(string: "", attributes: attributes(headingLevel: headingLevel, bold: false, italic: false))
        }
        return result
    }

    private static func match(_ s: [Character], _ i: Int, _ token: String) -> Bool {
        let t = Array(token)
        guard i + t.count <= s.count else { return false }
        for k in 0..<t.count where s[i + k] != t[k] { return false }
        return true
    }

    private static func find(_ s: [Character], _ from: Int, _ token: String) -> Int? {
        let t = Array(token)
        var i = from
        while i + t.count <= s.count {
            if match(s, i, token) { return i }
            i += 1
        }
        return nil
    }

    // MARK: - Attributes

    static func baseAttributes(headingLevel: Int) -> [NSAttributedString.Key: Any] {
        attributes(headingLevel: headingLevel, bold: false, italic: false)
    }

    static func attributes(headingLevel: Int, bold: Bool, italic: Bool) -> [NSAttributedString.Key: Any] {
        let size: CGFloat
        switch headingLevel {
        case 1: size = 30
        case 2: size = 24
        case 3: size = 20
        default: size = 18
        }
        var font = Typeface.nsHedvig(size)
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold || headingLevel > 0 { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        if !traits.isEmpty {
            let desc = font.fontDescriptor.withSymbolicTraits(traits)
            if let t = NSFont(descriptor: desc, size: size) { font = t }
        }
        let para = NSMutableParagraphStyle()
        para.lineSpacing = Metrics.writingLineSpacing
        // A little more air between paragraphs so separate thoughts read as distinct blocks.
        para.paragraphSpacing = headingLevel > 0 ? 12 : 8
        return [
            .font: font,
            .foregroundColor: headingLevel > 0 ? Ink.nsEmphasis : Ink.nsPrimary,
            .paragraphStyle: para,
            // Ligatures off — Hedvig fuses ff/fi/fl into one glyph, which makes doubled letters
            // (e.g. "off") look wrong while writing. Raw text should render letter-for-letter.
            .ligature: 0,
        ]
    }
}
