import Observation

extension Platform {
    /// Everything new code depends on, built once at launch and handed down
    /// with `.environment(_:)`. Nothing new is a singleton: tests and previews
    /// build their own with `preview()`.
    ///
    /// Each later byte adds its dependency here as a protocol-typed member
    /// (the session, client, store, outbox, router, billing and flows), so
    /// tests can swap in fakes.
    ///
    /// Views read it with `@Environment(Platform.AppEnvironment.self)`. It's
    /// named `AppEnvironment`, not `Environment`, so code inside `extension
    /// Platform` can still use SwiftUI's `@Environment` wrapper.
    @MainActor @Observable
    final class AppEnvironment {
        /// How this launch runs: sample or live data, which server, the screen
        /// launcher's page and state.
        let launch: Platform.LaunchOptions
        /// Which server, and the version every request reports.
        let configuration: Backend.Configuration
        let log: any Platform.LogSink

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(launch: Platform.LaunchOptions = .standard, configuration: Backend.Configuration, log: any Platform.LogSink) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
        }

        /// The app's environment, set by this launch's options (always live
        /// production in a release build), logging to the system log. Options
        /// that were ignored are logged by flag, never by value.
        static func live(launch: Platform.LaunchOptions = .current, log: any Platform.LogSink = Log.SystemSink()) -> AppEnvironment {
            launch.problems.forEach { log.record(.launchOptionIgnored($0)) }
            return AppEnvironment(launch: launch, configuration: .resolve(launch.environment), log: log)
        }

        /// For previews and tests: no network, no disk, no Keychain; logs are
        /// kept in memory.
        static func preview() -> AppEnvironment {
            AppEnvironment(configuration: .resolve(.local, info: [:]), log: Log.Recorder())
        }
    }
}
