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
        /// The one session (PL1.5): reads, renews and ends it; the client's token provider.
        let session: Session.Manager
        /// The one client for the `/v2` doors.
        let client: Backend.Client
        let reachability: any Backend.Reachability

        /// Set when the backend says this version is too old (PL1.6).
        var updateRequired = false

        init(
            launch: Platform.LaunchOptions = .standard,
            configuration: Backend.Configuration,
            log: any Platform.LogSink,
            session: Session.Manager,
            client: Backend.Client,
            reachability: any Backend.Reachability
        ) {
            self.launch = launch
            self.configuration = configuration
            self.log = log
            self.session = session
            self.client = client
            self.reachability = reachability
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
                launch: launch, configuration: configuration, log: log, session: session, client: client, reachability: reachability
            )
        }

        /// For previews and tests: no network, no disk, no Keychain; logs are
        /// kept in memory. The session starts signed out and nothing it does
        /// reaches the old app.
        static func preview() -> AppEnvironment {
            let log = Log.Recorder()
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
            return AppEnvironment(configuration: configuration, log: log, session: session, client: client, reachability: reachability)
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
    }
}
