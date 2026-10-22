import Foundation
import Observation
import SwiftUI
import UIKit

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
        private let backgroundTasks: Platform.BackgroundTasks
        /// Lifecycle records run one after another on this chain, so
        /// foreground and background land in the order the scene changed.
        private var lifecycle: Task<Void, Never>?

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(
            launch: Platform.LaunchOptions = .standard,
            configuration: Backend.Configuration,
            log: any Platform.LogSink,
            backgroundTasks: Platform.BackgroundTasks = .uiKit
        ) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            self.backgroundTasks = backgroundTasks
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
        /// app goes to the background (it may not come back). The flush runs
        /// under a background task, so the app isn't suspended in the middle
        /// of writing the very records a report is meant to carry.
        func scenePhaseChanged(to phase: ScenePhase) {
            let diagnostics = diagnostics
            switch phase {
            case .active:
                enqueueLifecycle { await diagnostics.record(.event(.appForeground)) }
            case .background:
                let keepAwake = backgroundTasks.begin("com.shauryanarang.Retrospect.diagnostics.flush")
                enqueueLifecycle {
                    await diagnostics.record(.event(.appBackground))
                    await diagnostics.flush()
                    keepAwake.end()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }

        /// Waits for every lifecycle record queued so far to land. For tests.
        func lifecycleSettled() async {
            await lifecycle?.value
        }

        private func enqueueLifecycle(_ work: @escaping @Sendable () async -> Void) {
            let previous = lifecycle
            lifecycle = Task {
                await previous?.value
                await work()
            }
        }
    }

    /// Keeps the app running a little longer for work that must finish
    /// (`UIApplication.beginBackgroundTask`). `uiKit` is the real thing; tests
    /// pass closures of their own.
    struct BackgroundTasks: Sendable {
        /// One task kept awake; `end` is safe to call more than once, and the
        /// expiration handler calls it too.
        final class Handle: Sendable {
            private let finish: @Sendable () -> Void
            private let once = OnceFlag()

            init(finish: @escaping @Sendable () -> Void) {
                self.finish = finish
            }

            func end() {
                guard once.claim() else { return }
                finish()
            }
        }

        let begin: @MainActor @Sendable (_ name: String) -> Handle

        @MainActor static let uiKit = BackgroundTasks { name in
            let application = UIApplication.shared
            let box = IdentifierBox()
            let handle = Handle {
                let id = box.take()
                guard id != .invalid else { return }
                Task { @MainActor in application.endBackgroundTask(id) }
            }
            box.set(application.beginBackgroundTask(withName: name) { handle.end() })
            return handle
        }

        private final class IdentifierBox: @unchecked Sendable {
            private let lock = NSLock()
            private var id = UIBackgroundTaskIdentifier.invalid

            func set(_ value: UIBackgroundTaskIdentifier) {
                lock.withLock { id = value }
            }

            /// The id, once; `.invalid` afterwards.
            func take() -> UIBackgroundTaskIdentifier {
                lock.withLock {
                    defer { id = .invalid }
                    return id
                }
            }
        }

        private final class OnceFlag: @unchecked Sendable {
            private let lock = NSLock()
            private var claimed = false

            func claim() -> Bool {
                lock.withLock {
                    defer { claimed = true }
                    return !claimed
                }
            }
        }
    }
}
