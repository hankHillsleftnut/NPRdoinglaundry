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
        private let openDatabase: @Sendable (String) throws -> Store.LocalDatabase
        private var diagnosticsWork: Task<Void, Never>?
        private var sessionLifecycleBound = false

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(
            launch: Platform.LaunchOptions = .standard,
            configuration: Backend.Configuration,
            log: any Platform.LogSink,
            openDatabase: @escaping @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.inMemory(ownerUserID: $0) }
        ) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            self.openDatabase = openDatabase
            diagnostics = Platform.Diagnostics.Recorder(log: log)
            crashReporter = Platform.Diagnostics.CrashReporter(sink: diagnostics)
        }

        /// The app's environment, set by this launch's options (always live
        /// production in a release build), logging to the system log. Options
        /// that were ignored are logged by flag, never by value.
        static func live(launch: Platform.LaunchOptions = .current, log: any Platform.LogSink = Log.SystemSink()) -> AppEnvironment {
            launch.problems.forEach { log.record(.launchOptionIgnored($0)) }
            return AppEnvironment(
                launch: launch,
                configuration: .resolve(launch.environment),
                log: log,
                openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0) }
            )
        }

        /// For previews and tests: no network, no disk, no Keychain; logs are
        /// kept in memory.
        static func preview() -> AppEnvironment {
            AppEnvironment(configuration: .resolve(.local, info: [:]), log: Log.Recorder())
        }

        /// Bridge until the new session owns authentication: restore the signed-in
        /// user's store, and finish store work before the old client changes users.
        func bindSessionLifecycle(to client: RetrospectAPIClient) async {
            guard !sessionLifecycleBound else { return }
            sessionLifecycleBound = true
            client.sessionWillChange = { [weak self] in
                await self?.sessionWillChange().value
            }
            client.sessionDidChange = { [weak self] userID in
                await self?.sessionDidChange(to: userID).value
            }
            if let userID = client.currentUserId {
                await sessionDidChange(to: userID).value
            }
        }

        @discardableResult
        func sessionWillChange() -> Task<Void, Never> {
            enqueueDiagnostics { [diagnostics] in
                await diagnostics.detach(erasingDatabase: true)
            }
        }

        @discardableResult
        func sessionDidChange(to userID: String) -> Task<Void, Never> {
            enqueueDiagnostics { [diagnostics, openDatabase, log] in
                do {
                    let database = try await Task.detached { try openDatabase(userID) }.value
                    await diagnostics.attach(database)
                } catch {
                    log.record(.diagnosticsWriteFailed)
                }
            }
        }

        /// Once, when the app's first scene is up: records the launch and
        /// starts listening for crash and hang diagnostics. Not called by the
        /// test host or previews, so neither subscribes to MetricKit.
        func didLaunch() {
            crashReporter.start()
            enqueueDiagnostics { [diagnostics] in
                await diagnostics.record(.event(.appLaunch))
            }
        }

        /// Records foreground and background, and lands what's waiting when the
        /// app goes to the background (it may not come back).
        @discardableResult
        func scenePhaseChanged(to phase: ScenePhase) -> Task<Void, Never>? {
            switch phase {
            case .active:
                return enqueueDiagnostics { [diagnostics] in
                    await diagnostics.record(.event(.appForeground))
                }
            case .background:
                return enqueueDiagnostics { [diagnostics] in
                    await diagnostics.record(.event(.appBackground))
                    await diagnostics.flush()
                }
            case .inactive:
                return nil
            @unknown default:
                return nil
            }
        }

        /// Each callback waits for the previous callback's entire operation,
        /// including its actor calls. The returned task is also a completion point.
        @discardableResult
        private func enqueueDiagnostics(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
            let previous = diagnosticsWork
            let task = Task {
                await previous?.value
                await operation()
            }
            diagnosticsWork = task
            return task
        }
    }
}
