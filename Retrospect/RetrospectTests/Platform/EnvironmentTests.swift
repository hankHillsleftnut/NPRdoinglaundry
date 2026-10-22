@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct EnvironmentTests {
    @Test("the preview environment builds without network, disk or Keychain, logging to memory")
    func thePreviewEnvironmentLogsToMemory() throws {
        let environment = Platform.Environment.preview()

        let recorder = try #require(environment.log as? Platform.Log.Recorder)
        #expect(recorder.events.isEmpty)
        #expect(environment.updateRequired == false)
    }

    @Test("the live environment logs to the system log")
    func theLiveEnvironmentLogsToTheSystemLog() {
        let environment = Platform.Environment.live()

        #expect(environment.log is Platform.Log.SystemSink)
        #expect(environment.updateRequired == false)
    }

    @Test("each preview environment is its own, so tests never share state")
    func eachPreviewEnvironmentIsItsOwn() throws {
        let first = Platform.Environment.preview()
        let second = Platform.Environment.preview()
        first.log.record(.refreshed)
        first.updateRequired = true

        let secondLog = try #require(second.log as? Platform.Log.Recorder)
        #expect(secondLog.events.isEmpty)
        #expect(second.updateRequired == false)
    }
}
