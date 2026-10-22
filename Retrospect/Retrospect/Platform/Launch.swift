import Foundation

extension Platform {
    /// A value shared between threads under a lock. For the few places a
    /// value is set once at launch or wiring time and read from anywhere.
    final class Box<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Value

        init(_ value: Value) {
            stored = value
        }

        var value: Value {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    /// What this launch did before the app started, read once by the
    /// environment. A prewarmed process never runs `AppEntry.main` again, so
    /// the session manager finishes what launch deferred on the first active scene.
    enum Launch {
        /// `Session.Store.checkInstallAtLaunch`'s result: nil when it didn't run
        /// or failed, `.deferredUntilUnlock` when it waited; both are run again.
        static let installCheck = Box<Session.InstallCheck?>(nil)
    }
}
