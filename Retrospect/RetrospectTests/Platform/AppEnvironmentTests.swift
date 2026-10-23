import Foundation
import GRDB
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppEnvironmentTests {
    @Test("the preview environment builds without network, disk or Keychain, logging to memory")
    func thePreviewEnvironmentLogsToMemory() throws {
        let environment = Platform.AppEnvironment.preview()

        let recorder = try #require(environment.log as? Platform.Log.Recorder)
        #expect(recorder.events.isEmpty)
        #expect(environment.updateRequired == false)
    }

    @Test("the live environment logs to the system log")
    func theLiveEnvironmentLogsToTheSystemLog() {
        let environment = Platform.AppEnvironment.live(launch: .standard, reachability: Backend.PathReachability(monitor: nil))

        #expect(environment.log is Platform.Log.SystemSink)
        #expect(environment.updateRequired == false)
    }

    @Test("live() uses the production configuration")
    func liveUsesTheProductionConfiguration() {
        let configuration = Platform.AppEnvironment.live(launch: .standard, reachability: Backend.PathReachability(monitor: nil)).configuration

        #expect(configuration.environment == .production)
        #expect(configuration.baseURL.absoluteString == "https://retrospect-api.onrender.com")
    }

    @Test("live(launch:) follows the launch's environment and keeps its options")
    func liveFollowsTheLaunchsEnvironment() {
        let launch = Platform.LaunchOptions.parse(["app", "-Environment", "local", "-Data", "sample", "-State", "offline"])

        let environment = Platform.AppEnvironment.live(launch: launch, log: Platform.Log.Recorder(), reachability: Backend.PathReachability(monitor: nil))

        #expect(environment.configuration.environment == .local)
        #expect(environment.launch == launch)
    }

    @Test("ignored launch options are logged by flag")
    func ignoredLaunchOptionsAreLoggedByFlag() {
        let recorder = Platform.Log.Recorder()

        _ = Platform.AppEnvironment.live(
            launch: .parse(["app", "-Data", "nonsense", "-Account", "month"]),
            log: recorder,
            reachability: Backend.PathReachability(monitor: nil)
        )

        #expect(recorder.events == [.launchOptionIgnored(.unknownValue(.data)), .launchOptionIgnored(.accountNeedsStaging)])
    }

    @Test("the scene going active and to the background lands as foreground and background events")
    func scenePhasesLandAsEvents() async throws {
        let environment = Platform.AppEnvironment.preview()
        let database = try Store.LocalDatabase.inMemory()
        await environment.diagnostics.attach(database)

        environment.scenePhaseChanged(to: .active)
        environment.scenePhaseChanged(to: .inactive)
        await environment.scenePhaseChanged(to: .background)?.value

        // Read without Recorder.rows first: rows itself flushes, which would
        // hide a missing background flush.
        let persisted = try await database.writer.read { try Store.DiagnosticRow.inRing(.events).fetchAll($0).map(\.payload) }
        #expect(try persisted == [
            Platform.Diagnostics.Recorder.encode(.event(.appForeground)),
            Platform.Diagnostics.Recorder.encode(.event(.appBackground)),
        ])
        let events = try await environment.diagnostics.rows(in: .events).map(\.payload)
        #expect(try events == [
            Platform.Diagnostics.Recorder.encode(.event(.appForeground)),
            Platform.Diagnostics.Recorder.encode(.event(.appBackground)),
        ], "in the order the scene changed")
    }

    @Test("going to the background keeps the app awake until the flush has landed, and ends the task exactly once")
    func backgroundFlushRunsUnderABackgroundTask() async throws {
        let tasks = BackgroundTaskSpy()
        let environment = Platform.AppEnvironment.preview(backgroundTasks: tasks.tasks)
        let database = try Store.LocalDatabase.inMemory()
        await environment.diagnostics.attach(database)

        environment.scenePhaseChanged(to: .background)
        #expect(tasks.begun == ["com.shauryanarang.Retrospect.diagnostics.flush"])
        #expect(tasks.ended == 0, "still awake while the flush runs")
        await environment.lifecycleSettled()

        #expect(tasks.ended == 1)
        #expect(try await environment.diagnostics.rows(in: .events).count == 1)
        tasks.expire()
        #expect(tasks.ended == 1, "expiring after the end doesn't end it twice")
    }

    @Test("a background task that expires before the flush ends is ended once by the expiration handler, then never again")
    func anExpiredBackgroundTaskEndsOnce() {
        let tasks = BackgroundTaskSpy()
        let environment = Platform.AppEnvironment.preview(backgroundTasks: tasks.tasks)

        environment.scenePhaseChanged(to: .background)
        tasks.expire()
        tasks.expire()

        #expect(tasks.ended == 1)
    }

    @Test("signing out unloads and drops the player, so nothing keeps playing for the next person")
    func signOutDropsThePlayer() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        await environment.sessionDidChange(to: "user-a").value
        let player = try #require(environment.playback)
        await player.load(Flows.PlaybackItem(id: "b1", kind: .brief, title: "today's brief", parts: [], durationSeconds: 60))
        #expect(player.item?.id == "b1", "the person's brief is the player's item (its fetch fails here; it stays the item)")

        await environment.sessionWillChange().value

        #expect(environment.playback == nil)
        #expect(player.item == nil && player.state == .idle, "the old person's audio is unloaded, not just dropped")
    }

    @Test("signing in builds the journal stack on that person's store; signing out stops it and erases it, and the next person starts empty")
    func theJournalStackFollowsTheSession() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        #expect(environment.journalData == nil)
        #expect(environment.outbox == nil)

        await environment.sessionDidChange(to: "user-a").value
        let outbox = try #require(environment.outbox)
        #expect(environment.journalData != nil)
        try await outbox.enqueueEntry(#require(Store.EntryDraft(kind: .typed, text: "private words", createdAt: Date())))
        #expect(try await database.writer.read { try Store.EntryRow.fetchCount($0) } == 1)

        await environment.sessionWillChange().value

        #expect(environment.journalData == nil)
        #expect(environment.outbox == nil)
        #expect(try await database.writer.read { try Store.EntryRow.fetchCount($0) } == 0, "the store is erased")
        #expect(try await database.writer.read { try Store.OutboxRow.fetchCount($0) } == 0)

        await environment.sessionDidChange(to: "user-b").value
        #expect(environment.journalData != nil)
        #expect(try await database.writer.read { try Store.EntryRow.fetchCount($0) } == 0, "the next person starts empty")
    }

    @Test("opening the authenticated store lands waiting diagnostics in that user's database")
    func openingTheStoreAttachesDiagnostics() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        environment.scenePhaseChanged(to: .active)

        await environment.sessionDidChange(to: "user-a").value
        await environment.scenePhaseChanged(to: .background)?.value

        let events = try await database.writer.read { try Store.DiagnosticRow.inRing(.events).fetchAll($0).map(\.payload) }
        #expect(try events == [
            Platform.Diagnostics.Recorder.encode(.event(.appForeground)),
            Platform.Diagnostics.Recorder.encode(.event(.appBackground)),
        ])
    }

    @Test("sign-out drains earlier scene work, detaches and erases before the next user's store opens")
    func signingOutSeparatesUsers() async throws {
        let first = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let second = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        let environment = Platform.AppEnvironment.preview(openDatabase: { $0 == "user-a" ? first : second })
        await environment.sessionDidChange(to: "user-a").value
        environment.scenePhaseChanged(to: .active)
        environment.scenePhaseChanged(to: .background)
        await environment.sessionWillChange().value
        await environment.diagnostics.record(.event(.screenShown(.signIn)))
        await environment.diagnostics.flush()
        #expect(try await first.writer.read { try Store.DiagnosticRow.inRing(.events).fetchCount($0) } == 0)

        await environment.sessionDidChange(to: "user-b").value

        let events = try await second.writer.read { try Store.DiagnosticRow.inRing(.events).fetchAll($0).map(\.payload) }
        #expect(try events == [Platform.Diagnostics.Recorder.encode(.event(.screenShown(.signIn)))])
        #expect(try await first.writer.read { try Store.DiagnosticRow.inRing(.events).fetchCount($0) } == 0)
    }

    @Test("a store open failure logs no content and leaves diagnostics detached")
    func aStoreOpenFailureLeavesDiagnosticsDetached() async throws {
        let log = Platform.Log.Recorder()
        let environment = Platform.AppEnvironment.preview(log: log, openDatabase: { _ in throw CocoaError(.fileReadNoSuchFile) })

        await environment.sessionDidChange(to: "user-a").value
        await environment.scenePhaseChanged(to: .background)?.value

        #expect(log.events == [.diagnosticsWriteFailed])
        #expect(try await environment.diagnostics.rows(in: .events).isEmpty)
    }

    @Test("live() joins the session and the client, sets the old app's bridges, and logs when staging resolves to this Mac")
    func liveJoinsTheSessionAndTheClient() async {
        let recorder = Platform.Log.Recorder()
        Platform.Bridges.refreshLegacy = nil
        Platform.Bridges.legacySignedOut = nil

        let environment = Platform.AppEnvironment.live(
            launch: .parse(["app", "-Environment", "staging"]), log: recorder, reachability: Backend.PathReachability(monitor: nil)
        )

        #expect(recorder.events == [.stagingResolvedToLocal])
        #expect(environment.configuration.environment == .local)
        #expect(Platform.Bridges.refreshLegacy != nil)
        #expect(Platform.Bridges.legacySignedOut != nil)
        // A signed-out session never reaches the server: no client is needed to say so.
        #expect(await environment.session.signOut(force: true) == .signedOut)
        Platform.Bridges.refreshLegacy = nil
        Platform.Bridges.legacySignedOut = nil
    }

    @Test("the preview session starts signed out, with no Keychain and no network")
    func thePreviewSessionStartsSignedOut() async {
        let environment = Platform.AppEnvironment.preview()

        #expect(await environment.session.state == .signedOut(hasSignedInBefore: false, reason: .none))
        await #expect(throws: Backend.Failure(.unauthenticated)) { _ = try await environment.session.accessToken() }
    }

    @Test("the preview environment points at local staging and reads no bundle")
    func thePreviewEnvironmentPointsAtLocalStaging() {
        let configuration = Platform.AppEnvironment.preview().configuration

        #expect(configuration.environment == .local)
        #expect(configuration.appVersion == "0 (0)")
    }

    @Test("each preview environment is its own, so tests never share state")
    func eachPreviewEnvironmentIsItsOwn() throws {
        let first = Platform.AppEnvironment.preview()
        let second = Platform.AppEnvironment.preview()
        first.log.record(.refreshed)
        first.floor.serverRequiresUpdate()

        let secondLog = try #require(second.log as? Platform.Log.Recorder)
        #expect(secondLog.events.isEmpty)
        #expect(second.updateRequired == false)
    }
}

/// Stands in for UIKit's background tasks: counts begins and ends, and can
/// fire the expiration handler.
private final class BackgroundTaskSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var begunNames: [String] = []
    private var endedCount = 0
    private var handles: [Platform.BackgroundTasks.Handle] = []

    var begun: [String] {
        lock.withLock { begunNames }
    }

    var ended: Int {
        lock.withLock { endedCount }
    }

    var tasks: Platform.BackgroundTasks {
        Platform.BackgroundTasks { [self] name in
            let handle = Platform.BackgroundTasks.Handle { self.lock.withLock { self.endedCount += 1 } }
            lock.withLock {
                begunNames.append(name)
                handles.append(handle)
            }
            return handle
        }
    }

    func expire() {
        lock.withLock { handles }.forEach { $0.end() }
    }
}
