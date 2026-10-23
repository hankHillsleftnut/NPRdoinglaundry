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
        private let crashReporter: Platform.Diagnostics.CrashReporter
        private let backgroundTasks: Platform.BackgroundTasks
        private let openDatabase: @Sendable (String) throws -> Store.LocalDatabase
        /// Diagnostics work runs one piece after another on this chain, so
        /// foreground and background land in the order the scene changed.
        private var diagnosticsWork: Task<Void, Never>?
        private var sessionFollow: Task<Void, Never>?

        /// The outbox, once the person's store is open (sign-in, PL1.5 / PL2.3);
        /// nil before. The scene-phase and background-task bridges drain it.
        private(set) var outbox: Store.Outbox?
        /// The same outbox, readable from the session manager's sign-out check (the manager is built first).
        private let unsentSource: Box<Store.Outbox?>
        /// Whose store the per-person stack is open on; nil when none is. Asking again for that person does nothing.
        private var openUserID: String?
        private var repository: Platform.Repositories.Journal?
        /// Whose rows were left on the phone when their session ended on its own; erased the moment a different person signs in.
        private var keptUserID: String?

        /// The signed-in person's journal data (PL3.1a); nil while signed out. Set with the store
        /// and dropped before it is erased, so the next person never sees the last one's entries.
        private(set) var journalData: LiveJournalData?
        /// Where the player gets a brief's audio file (PL3.1b); erased with the store.
        private(set) var mediaSource: Platform.Media.Source?
        /// The one player (PLP.1a): plays today's brief from `mediaSource`; unloaded and dropped with the store.
        private(set) var playback: Platform.Media.LivePlayback?

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
            openDatabase: @escaping @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.inMemory(ownerUserID: $0) },
            unsentSource: Box<Store.Outbox?> = Box(nil)
        ) {
            self.unsentSource = unsentSource
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
            let unsentSource = Box<Store.Outbox?>(nil)
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
                appleCredentialState: Session.AppleRevocationCheck.live,
                unsentCount: { await Self.unsentCount(in: unsentSource) }
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
            return AppEnvironment(
                launch: launch, configuration: configuration, log: log, session: session, client: client, reachability: reachability,
                invites: invites, floor: floor,
                openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0) },
                unsentSource: unsentSource
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
            let store = Session.Store(keychain: Session.MemoryKeychain(), legacyKeychain: Session.MemoryKeychain(), defaults: UserDefaults())
            let unsentSource = Box<Store.Outbox?>(nil)
            let session = Session.Manager(
                store: store,
                mirror: Session.LegacyMirror(keychain: Session.MemoryKeychain(), stateChanged: { _ in }),
                log: log,
                launchCheck: .alreadyDone,
                probeUnlock: { .unlocked },
                clearGate: {},
                appleCredentialState: { _ in .unknown },
                unsentCount: { await Self.unsentCount(in: unsentSource) }
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
                invites: invites, floor: floor, backgroundTasks: backgroundTasks, openDatabase: openDatabase,
                unsentSource: unsentSource
            )
        }

        /// Sign in with Apple, wired to this environment's client and session.
        func appleSignIn() -> Session.AppleSignIn {
            Session.AppleSignIn(client: client, installer: session, log: log)
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

        /// Starts following the new session, once, at launch. The per-person stack comes from its states and from
        /// nothing else: Apple sign-in, a renewal, a session the server ended, an Apple revocation and sign-out
        /// are the same stream. The old client's callbacks no longer open or close anything.
        func startSession() {
            follow(session.states())
        }

        /// `startSession` on any stream of states (tests feed their own); only the first call counts.
        ///   signed in  -> the person's store and stack open (a renewal asks again: nothing changes);
        ///   signed out -> the stack stops, the store STAYS on the phone: whatever the reason, because the stream
        ///                 cannot tell an Apple revocation from a Log Out. Only `logOut` and a different person erase;
        ///   locked     -> nothing.
        func follow(_ states: AsyncStream<Session.State>) {
            guard sessionFollow == nil else { return }
            sessionFollow = Task { [weak self] in
                for await state in states {
                    guard let self else { return }
                    switch state {
                    case let .signedIn(userID, _):
                        await sessionDidChange(to: userID).value
                    case .signedOut:
                        if openUserID != nil {
                            await closeStoreKeeping().value
                        }
                    case .locked:
                        continue
                    }
                }
            }
        }

        private func closeStoreKeeping() -> Task<Void, Never> {
            enqueueDiagnostics { [self] in await closeStore(erasing: false) }
        }

        enum LogOutResult: Equatable {
            case signedOut
            /// Entries are not sent yet and the person has not confirmed: nothing changed.
            case hasUnsent(Int)
        }

        /// The person chose Log Out. With entries not yet sent and no confirmation nothing happens; otherwise the
        /// session ends and the store is erased. The session ends first: if the app dies between, the phone is
        /// signed out with the store kept, which is the safe direction.
        func logOut(confirmed: Bool) async -> LogOutResult {
            let count = await unsentEntryCount()
            if count > 0, !confirmed {
                return .hasUnsent(count)
            }
            _ = await session.signOut(force: true)
            await sessionWillChange().value
            return .signedOut
        }

        @discardableResult
        func sessionWillChange() -> Task<Void, Never> {
            enqueueDiagnostics { [self] in await closeStore(erasing: true) }
        }

        @discardableResult
        func sessionDidChange(to userID: String) -> Task<Void, Never> {
            enqueueDiagnostics { [self] in await openStore(for: userID) }
        }

        /// Stops everything that reads or writes the person's store, in order, and waits for it: the journal's
        /// loads, the outbox's send in flight, late writes. Then, with `erasing`, the store is erased too
        /// (sign-out, another person signing in); without it the rows stay on the phone for the same person's
        /// next sign-in (the server ended the session on its own).
        func closeStore(erasing: Bool) async {
            let closing = openUserID
            let leftOver = keptUserID
            keptUserID = erasing ? nil : closing ?? keptUserID
            openUserID = nil
            journalData?.stop()
            journalData = nil
            await repository?.close()
            repository = nil
            await outbox?.stop()
            outbox = nil
            unsentSource.value = nil
            playback?.unload()
            playback = nil
            await mediaSource?.erase()
            mediaSource = nil
            await diagnostics.detach(erasingDatabase: erasing)
            if erasing, closing == nil, let kept = leftOver {
                await eraseStore(of: kept) // Log Out after the stack already stopped: the kept words go now
            }
        }

        private func eraseStore(of userID: String) async {
            let open = openDatabase
            _ = await Task.detached { try? open(userID).erase() }.value
        }

        /// Opens the person's store and the stack on it. Asking again for the person whose store is open does nothing;
        /// asking for someone else closes and erases the first person's first.
        func openStore(for userID: String) async {
            if openUserID == userID {
                return
            }
            if openUserID != nil {
                await closeStore(erasing: true)
            }
            if let kept = keptUserID, kept != userID {
                // another person on this phone: the last person's unsent words go before anything of the new person's opens
                await eraseStore(of: kept)
                keptUserID = nil
            }
            do {
                let open = openDatabase
                let database = try await Task.detached { try open(userID) }.value
                await diagnostics.attach(database)
                openJournal(on: database)
                openUserID = userID
                keptUserID = nil
            } catch {
                log.record(.diagnosticsWriteFailed)
            }
        }

        /// Entries not yet sent, for the sign-out question (0 when no store is open).
        func unsentEntryCount() async -> Int {
            await Self.unsentCount(in: unsentSource)
        }

        /// What the sign-out check counts: entries in the open outbox. A store that can't be read counts as one,
        /// so a sign-out never silently discards.
        nonisolated static func unsentCount(in source: Box<Store.Outbox?>) async -> Int {
            guard let outbox = source.value else { return 0 }
            return await (try? outbox.unsentCount()) ?? 1
        }

        /// The per-person stack on their store: the outbox (started, so what was left unsent goes out)
        /// and the journal's live data on it.
        private func openJournal(on database: Store.LocalDatabase) {
            let outbox = Store.Outbox(
                database: database, sender: Store.ClientSender(client: client), reachability: reachability, log: log
            )
            self.outbox = outbox
            unsentSource.value = outbox
            let repository = Platform.Repositories.Journal(database: database, client: client)
            self.repository = repository
            journalData = LiveJournalData(repository: repository, outbox: outbox, reachability: reachability)
            let reachability = reachability
            let source = Platform.Media.Source(
                isOnline: { await reachability.isOnline },
                refetch: { try await repository.refreshBrief().brief }
            )
            mediaSource = source
            playback = Platform.Media.LivePlayback(
                engine: Platform.Media.AVPlayerEngine(), session: Platform.Media.SystemAudioSession(),
                resolve: { item, rate in try await Self.audioFile(for: item, rate: rate, repository: repository, source: source) },
                log: log
            )
            Task { await outbox.start() }
        }

        /// The file the player plays for a brief: the day's brief as the store has it (or the server's, when the
        /// store has another), through the media source's download rules. Only briefs play so far.
        nonisolated static func audioFile(
            for item: Flows.PlaybackItem, rate: Double, repository: Platform.Repositories.Journal, source: Platform.Media.Source
        ) async throws -> URL {
            guard item.kind == .brief else { throw Platform.Media.Source.Failure.unavailable }
            var brief = await repository.cachedBrief()?.brief
            if brief?.id != item.id {
                do {
                    brief = try await repository.refreshBrief().brief
                } catch let failure as Backend.Failure where failure.kind == .offline {
                    // no connection and not the brief on the phone: say offline (a tap later retries), not "can't play"
                    throw Platform.Media.Source.Failure.offline
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    brief = nil
                }
            }
            guard let brief, brief.id == item.id else { throw Platform.Media.Source.Failure.unavailable }
            return try await source.playableFile(for: brief, rate: rate)
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
