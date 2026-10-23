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
        /// The invite: a pending code, its check after sign-in, the tear (PL1.7).
        let invites: Session.InviteCenter
        /// The version floor (PL1.6): whether this build must update.
        let floor: Platform.VersionFloor
        /// What the app did, for "send a report" (DG.3). No database until
        /// the store opens after sign-in (`attach`); until then it keeps the
        /// newest records in memory.
        let diagnostics: Platform.Diagnostics.Recorder
        /// Sign in with Apple on the new backend (PL1.4b): the only thing that hands `session` a credential.
        let signIn: Session.SignInCoordinator
        private let crashReporter: Platform.Diagnostics.CrashReporter
        private let backgroundTasks: Platform.BackgroundTasks
        private let openDatabase: @Sendable (String) throws -> Store.LocalDatabase
        /// Diagnostics work runs one piece after another on this chain, so
        /// foreground and background land in the order the scene changed.
        private var diagnosticsWork: Task<Void, Never>?
        private var sessionLifecycleBound = false

        /// The outbox, once the person's store is open (sign-in, PL1.5 / PL2.3);
        /// nil before. The scene-phase and background-task bridges drain it.
        var outbox: Store.Outbox?

        /// The signed-in person's journal data (PL3.1a); nil while signed out. Set with the store
        /// and dropped before it is erased, so the next person never sees the last one's entries.
        private(set) var journalData: LiveJournalData?
        /// Where the player gets a brief's audio file (PL3.1b); erased with the store.
        private(set) var mediaSource: Platform.Media.Source?

        /// The new session's state as the root shows it (PL1.4b): nil until the first value, then every
        /// change `session.states()` publishes, whatever its cause (sign-in, a server-ended session, Apple
        /// revoking access, sign-out, a locked phone). Only recorded: nothing here opens, closes or erases the
        /// person's store (SESSION-OUTBOX-FIXES owns that, and keeps unsent entries when the server ends a session).
        private(set) var sessionState: Session.State?
        @ObservationIgnored private var sessionFollower: Task<Void, Never>?

        /// True once the backend has said this version is too old (PL1.6); never false again.
        var updateRequired: Bool {
            floor.updateRequired
        }

        init(
            launch: Platform.LaunchOptions = .standard,
            configuration: Backend.Configuration,
            log: any Platform.LogSink,
            session: Session.Manager,
            client: Backend.Client,
            reachability: any Backend.Reachability,
            invites: Session.InviteCenter,
            floor: Platform.VersionFloor,
            backgroundTasks: Platform.BackgroundTasks = .uiKit,
            openDatabase: @escaping @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.inMemory(ownerUserID: $0) }
        ) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            self.session = session
            self.client = client
            self.reachability = reachability
            self.invites = invites
            self.floor = floor
            self.backgroundTasks = backgroundTasks
            self.openDatabase = openDatabase
            diagnostics = Platform.Diagnostics.Recorder(log: log)
            crashReporter = Platform.Diagnostics.CrashReporter(sink: diagnostics)
            signIn = Session.SignInCoordinator(apple: Session.AppleSignIn(client: client, installer: session, log: log))
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
            let store = Session.Store()
            let session = Session.Manager(
                store: store,
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
            let floor = VersionFloor(runningVersion: configuration.appVersion, log: log)
            let client = Backend.Client(
                configuration: configuration, tokens: session, reachability: reachability, log: log,
                onUpdateRequired: { Task { @MainActor in floor.serverRequiresUpdate() } }
            )
            session.connect(client)
            Bridges.refreshLegacy = { await session.refreshForLegacy() }
            Bridges.legacySignedOut = { _ = await session.signOut(force: true) }
            let invites = Session.InviteCenter(store: store, client: client, session: session, log: log)
            invites.start()
            let environment = AppEnvironment(
                launch: launch, configuration: configuration, log: log, session: session, client: client, reachability: reachability,
                invites: invites, floor: floor,
                openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0) }
            )
            environment.followSession()
            return environment
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
            let store = Session.Store(keychain: Session.MemoryKeychain(), legacyKeychain: Session.MemoryKeychain(), defaults: UserDefaults())
            let session = Session.Manager(
                store: store,
                mirror: Session.LegacyMirror(keychain: Session.MemoryKeychain(), stateChanged: { _ in }),
                log: log,
                launchCheck: .alreadyDone,
                probeUnlock: { .unlocked },
                clearGate: {},
                appleCredentialState: { _ in .unknown }
            )
            let reachability = Backend.PathReachability(monitor: nil)
            let floor = VersionFloor(runningVersion: configuration.appVersion, log: log)
            let client = Backend.Client(
                configuration: configuration, tokens: session, reachability: reachability, log: log,
                onUpdateRequired: { Task { @MainActor in floor.serverRequiresUpdate() } }
            )
            session.connect(client)
            let invites = Session.InviteCenter(store: store, client: client, session: session, log: log)
            return AppEnvironment(
                configuration: configuration, log: log, session: session, client: client, reachability: reachability,
                invites: invites, floor: floor, backgroundTasks: backgroundTasks, openDatabase: openDatabase
            )
        }

        /// Starts recording `session.states()` into `sessionState`, once. `live()` calls it; tests and
        /// previews call it when they want the root to follow their session.
        func followSession() {
            guard sessionFollower == nil else { return }
            let states = session.states()
            sessionFollower = Task { [weak self] in
                await self?.follow(states)
            }
        }

        /// Every state the stream publishes, in order, until it ends.
        func follow(_ states: AsyncStream<Session.State>) async {
            for await state in states {
                sessionState = state
            }
        }

        /// The scene became active: the session finishes a deferred launch
        /// check, reads, checks Apple, saves what it couldn't, and renews.
        func becameActive() {
            // The version check is its own task: renewal and the invite retry must not
            // wait on its round trip, or on its retries over a bad connection.
            Task { await floor.checkIfDue(using: client) }
            Task {
                await session.becameActive()
                await invites.retryIfWaiting()
            }
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
            enqueueDiagnostics { [self, diagnostics] in
                // Stop everything that reads or writes the person's store before it is erased.
                journalData?.stop()
                journalData = nil
                await outbox?.stop()
                outbox = nil
                await mediaSource?.erase()
                mediaSource = nil
                await diagnostics.detach(erasingDatabase: true)
            }
        }

        @discardableResult
        func sessionDidChange(to userID: String) -> Task<Void, Never> {
            enqueueDiagnostics { [self, diagnostics, openDatabase, log] in
                do {
                    let database = try await Task.detached { try openDatabase(userID) }.value
                    await diagnostics.attach(database)
                    openJournal(on: database)
                } catch {
                    log.record(.diagnosticsWriteFailed)
                }
            }
        }

        /// The per-person stack on their store: the outbox (started, so what was left unsent goes out)
        /// and the journal's live data on it.
        private func openJournal(on database: Store.LocalDatabase) {
            let outbox = Store.Outbox(
                database: database, sender: Store.ClientSender(client: client), reachability: reachability, log: log
            )
            self.outbox = outbox
            let repository = Platform.Repositories.Journal(database: database, client: client)
            journalData = LiveJournalData(repository: repository, outbox: outbox, reachability: reachability)
            let reachability = reachability
            mediaSource = Platform.Media.Source(
                isOnline: { await reachability.isOnline },
                refetch: { try await repository.refreshBrief().brief }
            )
            Task { await outbox.start() }
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
