@testable import Retrospect
import Testing

struct ScreenLauncherRootTests {
    @Test("-Screen puts the launcher at the root, whatever the id; no -Screen leaves the app alone")
    func requested() {
        #expect(ScreenLauncher.isRequested(.parse([])) == false)
        #expect(ScreenLauncher.isRequested(.parse(["-Data", "sample"])) == false)
        #expect(ScreenLauncher.isRequested(.parse(["-Screen", "journal"])))
        #expect(ScreenLauncher.isRequested(.parse(["-Screen", "NOPE"])))
    }
}
