@testable import Retrospect
import SwiftUI
import Testing

/// SI.fidelity: the splash, the invite gate and "you're in" against what Paper draws.
@MainActor
struct SignInFidelityTests {
    @Test("a live screen has no Google button: no Google sign-in exists yet")
    func liveHasNoGoogle() {
        #expect(SignInScreen.offersGoogle(sampleTaps: false) == false)
        let screen = SignInScreen(model: SignInModel.sample(.splash), sampleTaps: false)
        #expect(screen.googleAction == nil)
    }

    #if DEBUG // sample taps and `sampleGoogle` exist only in Debug builds
    @Test("on sample taps (-Flow sample, the launcher) Continue with Google is there (decision 12)")
    func sampleHasGoogle() {
        #expect(SignInScreen.offersGoogle(sampleTaps: true))
        let screen = SignInScreen(model: SignInModel.sample(.splash), sampleTaps: true)
        #expect(screen.googleAction != nil)
    }

    @Test("the sample Google tap signs the sample person in, once")
    func sampleGoogleSignsIn() async {
        let model = SignInModel(look: .splash, coordinator: SampleSignIn(sleep: { _ in }))
        var handed: [String?] = []
        model.onSignedIn = { name, _ in handed.append(name) }
        await SignInScreen.sampleGoogle(model)
        #expect(handed == ["sam"])
        // signed in: the buttons no longer rest, so a second tap does nothing
        await SignInScreen.sampleGoogle(model)
        #expect(handed.count == 1)
    }
    #endif

    @Test("the orbs carry Paper's four sample names at Paper's places")
    func orbNames() {
        #expect(RYouMapRest.names.map(\.0) == ["maya", "running", "the river", "work"])
        #expect(RYouMapRest.names.map(\.1) == [
            CGPoint(x: 100, y: 86), CGPoint(x: 293, y: 113), CGPoint(x: 303, y: 218), CGPoint(x: 110, y: 266),
        ])
    }

    @Test("the gift band is Paper's three ellipses (2IUL-0)")
    func giftBand() {
        let blobs = RTicketGift.blobs
        #expect(blobs.count == 3)
        #expect(blobs[0] == .init(strength: 1, radiusX: 0.8, radiusY: 0.9, at: UnitPoint(x: 0.85, y: 0.1), fade: 0.7))
        #expect(blobs[1] == .init(strength: 0.8, radiusX: 0.7, radiusY: 0.8, at: UnitPoint(x: 0.15, y: 0.9), fade: 0.75))
        #expect(blobs[2] == .init(strength: 0.45, radiusX: 0.45, radiusY: 0.4, at: UnitPoint(x: 0.55, y: 0.45), fade: 1))
    }
}
