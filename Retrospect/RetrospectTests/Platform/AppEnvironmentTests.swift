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
        await Task.yield()

        let events = try await environment.diagnostics.rows(in: .events).map(\.payload)
        #expect(try events.contains(Platform.Diagnostics.Recorder.encode(.event(.appForeground))))
        #expect(try events.contains(Platform.Diagnostics.Recorder.encode(.event(.appBackground))))
        #expect(events.count == 2)
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
