@testable import Retrospect
import Testing

/// C30.1: the bubble never exceeds 0.8 of the column or 280 points, and the status line under
/// it exists only when there is something to say.
struct RMessageBubbleTests {
    @Test("the bubble's width never exceeds 0.8 of the column")
    func widthFollowsTheColumn() {
        #expect(RMessageBubble.maxWidth(column: 300, accessibilitySize: false) == 240)
        #expect(RMessageBubble.maxWidth(column: 342, accessibilitySize: false) == 342 * 0.8)
    }

    @Test("a wide column stops the bubble at 280")
    func widthCapped() {
        #expect(RMessageBubble.maxWidth(column: 600, accessibilitySize: false) == 280)
    }

    @Test("before the column is measured the bubble uses the cap, never zero")
    func unmeasuredColumn() {
        #expect(RMessageBubble.maxWidth(column: 0, accessibilitySize: false) == 280)
    }

    @Test("at accessibility text sizes the bubble takes the full column")
    func accessibilityFullWidth() {
        #expect(RMessageBubble.maxWidth(column: 342, accessibilitySize: true) == .infinity)
    }

    @Test("only waiting and not sent have a line under the bubble")
    func statusOnlyWhenThereIsSomethingToSay() {
        #expect(RMessageBubble.Status(.sent) == nil)
        #expect(RMessageBubble.Status(.sending) == nil)
        #expect(RMessageBubble.Status(.waiting) == .waiting)
        #expect(RMessageBubble.Status(.notSent) == .notSent)
    }

    @Test("VoiceOver reads the dot as a comma")
    func spokenStatus() {
        #expect(RMessageBubble.spoken(RMessageBubble.Status.notSent.text) == "not sent, tap to retry")
    }
}
