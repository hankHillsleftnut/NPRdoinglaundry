@testable import Retrospect
import Testing

/// C19.2: the confirming action is only available when it can run, and VoiceOver hears the
/// question and what happens.
struct RDialogTests {
    @Test("confirm is available at rest and after an error, never while pending or offline")
    func canConfirm() {
        #expect(RDialog.canConfirm(.rest))
        #expect(RDialog.canConfirm(.error(message: "retro couldn't be reached. try again.")))
        #expect(!RDialog.canConfirm(.pending))
        #expect(!RDialog.canConfirm(.offline))
    }

    @Test("the alert reads the question, then exactly what happens")
    func spoken() {
        #expect(RDialog.spoken(title: "delete this entry?", line: "it can't be undone.") == "delete this entry? it can't be undone.")
    }
}
