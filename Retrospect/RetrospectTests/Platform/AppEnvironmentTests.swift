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
