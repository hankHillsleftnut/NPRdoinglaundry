import Observation

extension Platform {
    /// Everything new code depends on, built once at launch and handed down
    /// with `.environment(_:)`. Nothing new is a singleton: tests and previews
    /// build their own with `preview()`.
    ///
    /// Each later byte adds its dependency here as a protocol-typed member
    /// (the configuration in PL1.1, then the session, client, store, outbox,
    /// router, billing and flows), so tests can swap in fakes.
    ///
    /// Views read it with `@Environment(Platform.Environment.self)`. Inside
    /// `extension Platform`, `Environment` means this type, so code there never
    /// uses SwiftUI's `@Environment` wrapper.
    @MainActor @Observable
    final class Environment {
        let log: any Platform.LogSink

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(log: any Platform.LogSink) {
            self.log = log
        }

        /// The app's environment: logs go to the system log.
        static func live() -> Environment {
            Environment(log: Log.SystemSink())
        }

        /// For previews and tests: no network, no disk, no Keychain; logs are
        /// kept in memory.
        static func preview() -> Environment {
            Environment(log: Log.Recorder())
        }
    }
}
