@testable import Retrospect
import SwiftUI
import Testing

/// V2 lane 0 · the claim (part 41 G2A-0 stated, G3C-0 asked): Paper's type, and the guess look shared
/// with the guess card. New styles are additive; the ones they sit next to are unchanged.
@MainActor
struct RClaimTests {
    @Test("the asked question is the inky card face one size up; meta and label are Geist 12")
    func styles() {
        #expect(RTextStyle.inkClaimAsked.size == RDimension.fontSize2xl)
        #expect(abs(Double(RTextStyle.inkClaimAsked.tracking) - RNumber.fontTrackingCard) < 0.0001)
        // the meta line is the shared .metaLine (Geist 12, snug, no tracking), like G2C-0
        #expect(RTextStyle.metaLine.size == RDimension.fontSizeSm)
        #expect(abs(Double(RTextStyle.metaLine.tracking) - RNumber.fontTrackingNone) < 0.0001)
        #expect(RTextStyle.claimGuessLabel.weight == .medium)
        // additive: the styles beside them keep their values
        #expect(RTextStyle.inkCard.size == RDimension.fontSizeXl)
        #expect(RTextStyle.inkTitle.size == RDimension.fontSize3xl)
    }

    @Test("VoiceOver reads the meta line with commas, not dots")
    func kinds() {
        let stated = RClaim(kind: .stated, text: "your best days start early.", meta: "stated · from what you did · very sure")
        let asked = RClaim(kind: .asked, text: "are mornings when you do your best work?", meta: "asked · fairly sure · rests on 3 mornings")
        #expect(stated.spokenMeta == "stated, from what you did, very sure")
        #expect(asked.spokenMeta == "asked, fairly sure, rests on 3 mornings")
    }
}
