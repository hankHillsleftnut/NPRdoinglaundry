@testable import Retrospect
import Testing

/// C14: with voice off (nothing records yet) the corner is only the send: no mic, and a tap
/// never says "listening…" while keeping nothing. With voice on nothing changes.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RVoiceComposerTests {
    @Test("voice off: no corner while the field is empty; the send once there are words")
    func voiceOffCorner() {
        #expect(!RVoiceComposer.showsCorner(voice: false, mode: .muted, text: ""))
        #expect(RVoiceComposer.showsCorner(voice: false, mode: .muted, text: "hi"))
        #expect(RVoiceComposer.cornerTap(voice: false, mode: .muted, text: "") == .none)
        #expect(RVoiceComposer.cornerTap(voice: false, mode: .muted, text: "hi") == .send)
    }

    @Test("voice on (the default): the mic toggles talking and typing, and words send")
    func voiceOnUnchanged() {
        let composer = RVoiceComposer(mode: .constant(.muted), text: .constant(""))
        #expect(composer.voice)
        #expect(RVoiceComposer.showsCorner(voice: true, mode: .muted, text: ""))
        #expect(RVoiceComposer.cornerTap(voice: true, mode: .muted, text: "") == .toggle(to: .listening))
        #expect(RVoiceComposer.cornerTap(voice: true, mode: .listening, text: "") == .toggle(to: .muted))
        #expect(RVoiceComposer.cornerTap(voice: true, mode: .muted, text: "hi") == .send)
    }

    @Test("while Retro speaks VoiceOver never calls the corner 'stop listening': the host's name, or 'type instead'")
    func speakingCornerLabel() {
        let composer = RVoiceComposer(mode: .constant(.speaking), text: .constant(""))
        #expect(composer.speakingCornerLabel == "type instead")
        let speaking = RVoiceComposer.cornerLabel(isSend: false, mode: .speaking, speaking: composer.speakingCornerLabel)
        #expect(speaking == "type instead")
        #expect(!speaking.contains("listening"))
        // ON-5's corner moves on, so it says so
        #expect(RVoiceComposer.cornerLabel(isSend: false, mode: .speaking, speaking: PrivacyModel.moveOnAction) == "move on")
        // the other states keep their words
        #expect(RVoiceComposer.cornerLabel(isSend: false, mode: .listening, speaking: "move on") == "stop listening, type instead")
        #expect(RVoiceComposer.cornerLabel(isSend: false, mode: .muted, speaking: "move on") == "talk instead")
        #expect(RVoiceComposer.cornerLabel(isSend: true, mode: .muted, speaking: "move on") == "send")
    }
}
