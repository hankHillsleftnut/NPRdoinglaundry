@testable import Retrospect
import Testing
import UserNotifications

struct PlatformSmokeTests {
    @Test("the app boots as a test host without starting the app delegate's services or the root screens")
    func theAppBootsAsATestHostWithoutStartingServices() {
        #expect(Platform.isRunningUnitTests)
        // The app delegate's first job is claiming the notification delegate;
        // the guard returns before it, so nothing after it ran either.
        #expect(UNUserNotificationCenter.current().delegate == nil)
    }
}
