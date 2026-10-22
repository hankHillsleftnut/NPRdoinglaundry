import Foundation
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
        let environment = Platform.AppEnvironment.live(launch: .standard)

        #expect(environment.log is Platform.Log.SystemSink)
        #expect(environment.updateRequired == false)
    }

    @Test("live() uses the production configuration")
    func liveUsesTheProductionConfiguration() {
        let configuration = Platform.AppEnvironment.live(launch: .standard).configuration

        #expect(configuration.environment == .production)
        #expect(configuration.baseURL.absoluteString == "https://retrospect-api.onrender.com")
    }

    @Test("live(launch:) follows the launch's environment and keeps its options")
    func liveFollowsTheLaunchsEnvironment() {
        let launch = Platform.LaunchOptions.parse(["app", "-Environment", "local", "-Data", "sample", "-State", "offline"])

        let environment = Platform.AppEnvironment.live(launch: launch, log: Platform.Log.Recorder())

        #expect(environment.configuration.environment == .local)
        #expect(environment.launch == launch)
    }

    @Test("ignored launch options are logged by flag")
    func ignoredLaunchOptionsAreLoggedByFlag() {
        let recorder = Platform.Log.Recorder()

        _ = Platform.AppEnvironment.live(launch: .parse(["app", "-Data", "nonsense", "-Account", "month"]), log: recorder)

        #expect(recorder.events == [.launchOptionIgnored(.unknownValue(.data)), .launchOptionIgnored(.accountNeedsStaging)])
    }

    @Test("the scene going active and to the background lands as foreground and background events")
    func scenePhasesLandAsEvents() async throws {
        let environment = Platform.AppEnvironment.preview()
        let database = try Store.LocalDatabase.inMemory()
        await environment.diagnostics.attach(database)

        environment.scenePhaseChanged(to: .active)
        environment.scenePhaseChanged(to: .inactive)
        environment.scenePhaseChanged(to: .background)
        await environment.lifecycleSettled()

        let events = try await environment.diagnostics.rows(in: .events).map(\.payload)
        #expect(try events == [
            Platform.Diagnostics.Recorder.encode(.event(.appForeground)),
            Platform.Diagnostics.Recorder.encode(.event(.appBackground)),
        ], "in the order the scene changed")
    }

    @Test("going to the background keeps the app awake until the flush has landed, and ends the task exactly once")
    func backgroundFlushRunsUnderABackgroundTask() async throws {
        let tasks = BackgroundTaskSpy()
        let environment = Platform.AppEnvironment(configuration: .resolve(.local, info: [:]), log: Platform.Log.Recorder(), backgroundTasks: tasks.tasks)
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
        let environment = Platform.AppEnvironment(configuration: .resolve(.local, info: [:]), log: Platform.Log.Recorder(), backgroundTasks: tasks.tasks)

        environment.scenePhaseChanged(to: .background)
        tasks.expire()
        tasks.expire()

        #expect(tasks.ended == 1)
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
        first.updateRequired = true

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
