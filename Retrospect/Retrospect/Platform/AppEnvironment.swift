import Observation
import SwiftUI

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
        /// What the app did, for "send a report" (DG.3). No database until
        /// the store opens after sign-in (`attach`); until then it keeps the
        /// newest records in memory.
        let diagnostics: Platform.Diagnostics.Recorder
        private let crashReporter: Platform.Diagnostics.CrashReporter

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(launch: Platform.LaunchOptions = .standard, configuration: Backend.Configuration, log: any Platform.LogSink) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            diagnostics = Platform.Diagnostics.Recorder(log: log)
            crashReporter = Platform.Diagnostics.CrashReporter(sink: diagnostics)
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

        /// Once, when the app's first scene is up: records the launch and
        /// starts listening for crash and hang diagnostics. Not called by the
        /// test host or previews, so neither subscribes to MetricKit.
        func didLaunch() {
            crashReporter.start()
            let diagnostics = diagnostics
            Task { await diagnostics.record(.event(.appLaunch)) }
        }

        /// Records foreground and background, and lands what's waiting when the
        /// app goes to the background (it may not come back).
        func scenePhaseChanged(to phase: ScenePhase) {
            let diagnostics = diagnostics
            switch phase {
            case .active:
                Task { await diagnostics.record(.event(.appForeground)) }
            case .background:
                Task {
                    await diagnostics.record(.event(.appBackground))
                    await diagnostics.flush()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
