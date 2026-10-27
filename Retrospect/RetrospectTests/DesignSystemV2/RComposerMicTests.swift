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
        #expect(composer.onMic == nil)
    }
}
