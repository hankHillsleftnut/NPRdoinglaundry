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
        /// The one session (PL1.5): reads, renews and ends it; the client's token provider.
        let session: Session.Manager
        /// The one client for the `/v2` doors.
        let client: Backend.Client
        let reachability: any Backend.Reachability
        /// What the app did, for "send a report" (DG.3). No database until
        /// the store opens after sign-in (`attach`); until then it keeps the
        /// newest records in memory.
        let diagnostics: Platform.Diagnostics.Recorder
        private let crashReporter: Platform.Diagnostics.CrashReporter
        private let backgroundTasks: Platform.BackgroundTasks
        private let openDatabase: @Sendable (String) throws -> Store.LocalDatabase
        /// Diagnostics work runs one piece after another on this chain, so
        /// foreground and background land in the order the scene changed.
        private var diagnosticsWork: Task<Void, Never>?
        private var sessionLifecycleBound = false

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(
            launch: Platform.LaunchOptions = .standard,
            configuration: Backend.Configuration,
            log: any Platform.LogSink,
            session: Session.Manager,
            client: Backend.Client,
            reachability: any Backend.Reachability,
            backgroundTasks: Platform.BackgroundTasks = .uiKit,
            openDatabase: @escaping @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.inMemory(ownerUserID: $0) }
        ) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            self.session = session
            self.client = client
            self.reachability = reachability
            self.backgroundTasks = backgroundTasks
            self.openDatabase = openDatabase
            diagnostics = Platform.Diagnostics.Recorder(log: log)
            crashReporter = Platform.Diagnostics.CrashReporter(sink: diagnostics)
        }

        /// The app's environment, set by this launch's options (always live
        /// production in a release build), logging to the system log. Options
        /// that were ignored are logged by flag, never by value. Builds the
        /// session and the client, joins them, and sets the old app's bridges.
        static func live(
            launch: Platform.LaunchOptions = .current,
            log: any Platform.LogSink = Log.SystemSink(),
            reachability: any Backend.Reachability = Backend.PathReachability()
        ) -> AppEnvironment {
            launch.problems.forEach { log.record(.launchOptionIgnored($0)) }
            let configuration = Backend.Configuration.resolve(launch.environment)
            if launch.environment == .staging, configuration.environment == .local {
                log.record(.stagingResolvedToLocal)
            }
            let session = Session.Manager(
                store: Session.Store(),
                mirror: Session.LegacyMirror(
                    keychain: Session.SystemKeychain(service: Session.Store.legacyService),
                    stateChanged: { Bridges.legacyStateChanged(userID: $0) }
                ),
                log: log,
                launchCheck: Launch.installCheck.value,
                probeUnlock: { Session.SystemKeychain(service: Session.Store.service).probeUnlock() },
                clearGate: { Bridges.clearSignInGate() },
                appleCredentialState: Session.AppleRevocationCheck.live
            )
            let client = Backend.Client(configuration: configuration, tokens: session, reachability: reachability, log: log)
            session.connect(client)
            Bridges.refreshLegacy = { await session.refreshForLegacy() }
            Bridges.legacySignedOut = { _ = await session.signOut(force: true) }
            return AppEnvironment(
                launch: launch, configuration: configuration, log: log, session: session, client: client, reachability: reachability,
                openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0) }
            )
        }

        /// For previews and tests: no network, no disk, no Keychain; logs are
        /// kept in memory. The session starts signed out and nothing it does
        /// reaches the old app.
        static func preview(
            log: any Platform.LogSink = Log.Recorder(),
            backgroundTasks: Platform.BackgroundTasks = .uiKit,
            openDatabase: @escaping @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.inMemory(ownerUserID: $0) }
        ) -> AppEnvironment {
            let configuration = Backend.Configuration.resolve(.local, info: [:])
            let session = Session.Manager(
                store: Session.Store(keychain: Session.MemoryKeychain(), legacyKeychain: Session.MemoryKeychain(), defaults: UserDefaults()),
                mirror: Session.LegacyMirror(keychain: Session.MemoryKeychain(), stateChanged: { _ in }),
                log: log,
                launchCheck: .alreadyDone,
                probeUnlock: { .unlocked },
                clearGate: {},
                appleCredentialState: { _ in .unknown }
            )
            let reachability = Backend.PathReachability(monitor: nil)
            let client = Backend.Client(configuration: configuration, tokens: session, reachability: reachability, log: log)
            session.connect(client)
            return AppEnvironment(
                configuration: configuration, log: log, session: session, client: client, reachability: reachability,
                backgroundTasks: backgroundTasks, openDatabase: openDatabase
            )
        }

        /// Sign in with Apple, wired to this environment's client and session.
        func appleSignIn() -> Session.AppleSignIn {
            Session.AppleSignIn(client: client, installer: session, log: log)
        }

        /// The scene became active: the session finishes a deferred launch
        /// check, reads, checks Apple, saves what it couldn't, and renews.
        func becameActive() {
            Task { await session.becameActive() }
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
        /// app goes to the background (it may not come back). The flush runs
        /// under a background task, so the app isn't suspended in the middle
        /// of writing the very records a report is meant to carry.
        @discardableResult
        func scenePhaseChanged(to phase: ScenePhase) -> Task<Void, Never>? {
            switch phase {
            case .active:
                return enqueueDiagnostics { [diagnostics] in
                    await diagnostics.record(.event(.appForeground))
                }
            case .background:
                let keepAwake = backgroundTasks.begin("com.shauryanarang.Retrospect.diagnostics.flush")
                return enqueueDiagnostics { [diagnostics] in
                    await diagnostics.record(.event(.appBackground))
                    await diagnostics.flush()
                    keepAwake.end()
                }
            case .inactive:
                return nil
            @unknown default:
                return nil
            }
        }

        /// Waits for every piece of diagnostics work queued so far. For tests.
        func lifecycleSettled() async {
            await diagnosticsWork?.value
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
