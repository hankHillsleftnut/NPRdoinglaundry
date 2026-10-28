@testable import Retrospect
import SwiftUI
import Testing

/// V2.outside.a (EX-D10): the compact composer's mic is never a dead control.
@MainActor
struct RComposerMicTests {
    @Test("with a mic action the well hands over to it")
    func talk() {
        var talks = 0
        let composer = RComposer(label: "add why", placeholder: "…", text: .constant(""), onMic: { talks += 1 })
        #expect(composer.micAction == .talk)
        composer.onMic?()
        #expect(talks == 1)
    }

    @Test("without one the well focuses the field (the keyboard's dictation)")
    func focus() {
        let composer = RComposer(label: "add why", placeholder: "…", text: .constant(""))
        #expect(composer.micAction == .focusField)
        var focused = 0
        RComposer.micTapped(onMic: composer.onMic) { focused += 1 }
        #expect(focused == 1)
    }

    @Test("with an action the tap talks and never focuses")
    func tapTalks() {
        var talks = 0
        var focused = 0
        RComposer.micTapped(onMic: { talks += 1 }, focus: { focused += 1 })
        #expect(talks == 1)
        #expect(focused == 0)
    }
}
