@testable import Retrospect
import SwiftUI
import Testing

/// V2 lane 0 · entry words (E2U-0 rest, G8U-0 editing) and the conversation link (E2Z-0): Paper's type
/// as additive styles, and the link's copy and 44 row.
@MainActor
struct REntryWordsTests {
    @Test("your words: the inky card face at text-xl with a snug leading (E2U-0); additive")
    func wordsStyle() {
        #expect(RTextStyle.inkEntry.size == RDimension.fontSizeXl)
        #expect(abs(Double(RTextStyle.inkEntry.tracking) - RNumber.fontTrackingCard) < 0.0001)
        #expect(RTextStyle.inkEntry.leading > RTextStyle.inkCard.leading)
        #expect(RTextStyle.inkCard.size == RDimension.fontSizeXl) // unchanged beside it
    }

    @Test("the link reads Paper's words, in SF text-md regular")
    func link() {
        #expect(RConversationLink {}.title == "show it in the conversation")
        #expect(RTextStyle.inlineLink.size == RDimension.fontSizeMd)
        #expect(RTextStyle.inlineLink.weight == .regular)
        #expect(RDimension.sizeTouchTarget == 44)
    }
}
