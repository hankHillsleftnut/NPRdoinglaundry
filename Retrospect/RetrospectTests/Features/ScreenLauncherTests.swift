@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ScreenLauncherTests {
    @Test("no -Screen, or an id nothing handles, launches nothing")
    func nothingAsked() {
        #expect(ScreenLauncher.view(for: .parse([])) == nil)
        #expect(ScreenLauncher.view(for: .parse(["-Screen", "NOPE"])) == nil)
    }
}
