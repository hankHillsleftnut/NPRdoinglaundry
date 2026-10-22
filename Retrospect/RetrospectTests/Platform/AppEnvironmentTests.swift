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
        await environment.scenePhaseChanged(to: .background)?.value

        // Read without Recorder.rows first: rows itself flushes, which would
        // hide a missing background flush.
        let persisted = try await database.writer.read { try Store.DiagnosticRow.inRing(.events).fetchAll($0).map(\.payload) }
        #expect(try persisted == [
            Platform.Diagnostics.Recorder.encode(.event(.appForeground)),
            Platform.Diagnostics.Recorder.encode(.event(.appBackground)),
        ])
        let events = try await environment.diagnostics.rows(in: .events).map(\.payload)
        #expect(try events.contains(Platform.Diagnostics.Recorder.encode(.event(.appForeground))))
        #expect(try events.contains(Platform.Diagnostics.Recorder.encode(.event(.appBackground))))
        #expect(events.count == 2)
    }

    @Test("opening the authenticated store lands waiting diagnostics in that user's database")
    func openingTheStoreAttachesDiagnostics() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment(
            configuration: .resolve(.local, info: [:]),
            log: Platform.Log.Recorder(),
            openDatabase: { _ in database }
        )
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
        let environment = Platform.AppEnvironment(
            configuration: .resolve(.local, info: [:]),
            log: Platform.Log.Recorder(),
            openDatabase: { $0 == "user-a" ? first : second }
        )
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
        let environment = Platform.AppEnvironment(
            configuration: .resolve(.local, info: [:]),
            log: log,
            openDatabase: { _ in throw CocoaError(.fileReadNoSuchFile) }
        )

        await environment.sessionDidChange(to: "user-a").value
        await environment.scenePhaseChanged(to: .background)?.value

        #expect(log.events == [.diagnosticsWriteFailed])
        #expect(try await environment.diagnostics.rows(in: .events).isEmpty)
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
