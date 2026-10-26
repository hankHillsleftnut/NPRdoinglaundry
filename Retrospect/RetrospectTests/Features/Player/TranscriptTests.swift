import Foundation
@testable import Retrospect
import Testing

struct TranscriptTests {
    /// Three lines at 0, 10 and 25 s.
    private let transcript = Flows.Transcript(itemID: "episode", lines: [
        .init(id: 0, text: "one", startSeconds: 0),
        .init(id: 1, text: "two", startSeconds: 10),
        .init(id: 2, text: "three", startSeconds: 25),
    ])

    @Test("the line being read is the last one that has started", arguments: [
        (0.0, 0), (9.999, 0), (10.0, 1), (24.999, 1), (25.0, 2), (600.0, 2),
    ])
    func lineAtTime(seconds: Double, line: Int) {
        #expect(transcript.lineIndex(at: seconds) == line)
    }

    @Test("before the first line starts, the first line is the one about to be read")
    func beforeTheFirstLine() {
        let late = Flows.Transcript(itemID: "episode", lines: [
            .init(id: 0, text: "one", startSeconds: 3),
            .init(id: 1, text: "two", startSeconds: 8),
        ])
        #expect(late.lineIndex(at: 0) == 0)
        #expect(late.lineIndex(at: -5) == 0)
    }

    @Test("no lines, no line")
    func empty() {
        let none = Flows.Transcript(itemID: "episode", lines: [])
        #expect(none.lineIndex(at: 12) == nil)
        #expect(!none.isTimed)
    }

    @Test("lines with no times (the transcript fallback) light nothing and keep their own order")
    func untimed() {
        let untimed = Flows.Transcript(itemID: "episode", lines: [
            .init(id: 1, text: "two", startSeconds: nil),
            .init(id: 0, text: "one", startSeconds: nil),
        ])
        #expect(!untimed.isTimed)
        #expect(untimed.lines.map(\.id) == [0, 1])
        #expect(untimed.lineIndex(at: 0) == nil)
        #expect(untimed.lineIndex(at: 600) == nil, "never the last line for the whole episode")
        let mixed = Flows.Transcript(itemID: "episode", lines: [
            .init(id: 0, text: "one", startSeconds: 0),
            .init(id: 1, text: "two", startSeconds: nil),
        ])
        #expect(mixed.lineIndex(at: 30) == nil)
    }

    @Test("lines that arrive out of order are read in the order they start")
    func sorted() {
        let shuffled = Flows.Transcript(itemID: "episode", lines: [
            .init(id: 2, text: "three", startSeconds: 25),
            .init(id: 0, text: "one", startSeconds: 0),
            .init(id: 1, text: "two", startSeconds: 10),
        ])
        #expect(shuffled.lines.map(\.id) == [0, 1, 2])
        #expect(shuffled.lineIndex(at: 12) == 1)
    }

    @Test("the tease's words are Paper's, word for word (26PE-0 … 26PA-0), and its third line is lit at 0:04")
    func teaseIsPapers() {
        #expect(SampleTranscript.tease.lines.map(\.text) == [
            "This is the week you started, so it's a short one.",
            "Here's the first thing I noticed. It's narrow, because it's day one.",
            "You said Thursday's investor call matters. Your calendar agrees: three prep blocks, all before noon.",
            "You give your mornings to what you care about.",
            "Next Sunday I'll have a whole week to go on.",
        ])
        #expect(SampleTranscript.tease.lineIndex(at: SamplePlayback.teaseLitLine) == 2)
        #expect(SampleTranscript.tease.itemID == SamplePlayback.tease.id)
    }
}
