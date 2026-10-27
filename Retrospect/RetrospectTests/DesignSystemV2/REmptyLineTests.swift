@testable import Retrospect
import Testing

/// C39.2: VoiceOver reads the empty state as one sentence, with or without its subline.
struct REmptyLineTests {
    @Test("the line and the subline read as one sentence")
    func spokenWithSubline() {
        #expect(REmptyLine
            .spoken(line: "nothing yet. say anything.", subline: "what you say shows up here, by day") ==
            "nothing yet. say anything. what you say shows up here, by day")
    }

    @Test("a one-line state reads only its line")
    func spokenLineOnly() {
        #expect(REmptyLine.spoken(line: "nothing much moved. enjoy the quiet.", subline: nil) == "nothing much moved. enjoy the quiet.")
    }
}
