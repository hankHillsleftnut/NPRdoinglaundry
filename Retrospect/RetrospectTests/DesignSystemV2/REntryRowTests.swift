@testable import Retrospect
import Testing

/// C31: search matches arrive as UTF-16 offsets (contract 02 §5) and are cut out of the words
/// on character boundaries, emoji included.
struct REntryRowTests {
    private func cut(_ words: String, _ matches: [Range<Int>]) -> [String] {
        REntryRow.segments(words, matches: matches).map { $0.matched ? "[\($0.text)]" : $0.text }
    }

    @Test("a match in plain words becomes its own run")
    func plainMatch() {
        #expect(cut("the 9am standup again", [8 ..< 15]) == ["the 9am ", "[standup]", " again"])
    }

    @Test("offsets after an emoji count its two UTF-16 units, not one character")
    func afterEmoji() {
        // 🏃 is one character and two UTF-16 units, so "canal" starts at 3
        #expect(cut("🏃 canal walk", [3 ..< 8]) == ["🏃 ", "[canal]", " walk"])
    }

    @Test("a family emoji (one character, many units) keeps the match after it right")
    func afterJoinedEmoji() {
        let words = "👨‍👩‍👧 dinner"
        let start = "👨‍👩‍👧 ".utf16.count
        #expect(cut(words, [start ..< start + 6]) == ["👨‍👩‍👧 ", "[dinner]"])
    }

    @Test("a match that splits a character, overlaps, or runs past the end is skipped")
    func badMatchesSkipped() {
        #expect(cut("🏃 run", [1 ..< 3]) == ["🏃 run"])
        #expect(cut("abc", [2 ..< 9]) == ["abc"])
        #expect(cut("canal canal", [0 ..< 5, 2 ..< 7, 6 ..< 11]) == ["[canal]", " ", "[canal]"])
    }

    @Test("two matches and the words between them")
    func twoMatches() {
        #expect(cut("canal walk by the canal", [0 ..< 5, 18 ..< 23]) == ["[canal]", " walk by the ", "[canal]"])
    }
}
