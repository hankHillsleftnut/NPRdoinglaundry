import SwiftUI

/// The app's entry point. Every launch except a unit-test run first runs the
/// install check (`Session.Store.checkInstallAtLaunch`). A unit-test run gets
/// a bare host, so none of the old app is built: no app delegate, no
/// singletons, no root screens, no `onAppear` or scene-phase work, and so no
/// notifications, observers, syncs or network calls. Every other launch, UI
/// tests included (their launched app has no test configuration), runs
/// `RetrospectApp` exactly as before.
@main
enum AppEntry {
    static func main() {
        if Platform.isRunningUnitTests {
            Platform.TestHost.main()
        } else {
            // Bridge (PL1.3): before the old app starts, so a reinstall's
            // leftover sign-in is gone before the old client restores it.
            Platform.Launch.installCheck.value = Session.Store.checkInstallAtLaunch(
                probe: { Session.SystemKeychain(service: Session.Store.service).probeUnlock() },
                log: Platform.Log.SystemSink()
            )
            RetrospectApp.main()
        }
    }
}

extension Platform {
    /// The app a unit-test run hosts: one empty window and nothing else.
    struct TestHost: App {
        /// Set when the test host starts, so a test can prove it was this app,
        /// not `RetrospectApp`, that launched.
        private(set) static var didLaunch = false

        init() {
            Self.didLaunch = true
        }

        var body: some Scene {
            WindowGroup { EmptyView() }
        }
    }
}
