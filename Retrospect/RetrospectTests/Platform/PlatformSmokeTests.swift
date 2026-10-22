import Foundation
@testable import Retrospect
import Testing
import UserNotifications

@Suite(.timeLimit(.minutes(1)))
struct PlatformSmokeTests {
    @Test("the app boots as a bare test host, not the app")
    func theAppBootsAsABareTestHost() {
        #expect(Platform.isRunningUnitTests)
        #expect(Platform.TestHost.didLaunch)
        // RetrospectApp's delegate claims the notification centre first thing;
        // it never ran.
        #expect(UNUserNotificationCenter.current().delegate == nil)
    }

    @Test("the test host makes no network request")
    func theTestHostMakesNoNetworkRequest() async {
        // The old app's launch work (Google sign-in restore, integration sync,
        // the transcript models) reaches the network through the shared
        // session or sessions it builds in singletons. The host builds none of
        // them, and the shared session has never had a task.
        #expect(Platform.TestHost.didLaunch)
        let tasks = await URLSession.shared.allTasks
        #expect(tasks.isEmpty)
    }
}
