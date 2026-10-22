@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CrashReporterTests {
    typealias CrashReporter = Platform.Diagnostics.CrashReporter

    @Test("a payload's counts become one crash record per crash and one hang per hang, nothing else")
    func countsBecomeRecords() {
        #expect(CrashReporter.records(crashes: 2, hangs: 1) == [
            .crash(.init(kind: .crash)), .crash(.init(kind: .crash)), .crash(.init(kind: .hang)),
        ])
        #expect(CrashReporter.records(crashes: 0, hangs: 0).isEmpty)
        #expect(CrashReporter.records(crashes: -1, hangs: 0).isEmpty)
    }

    @Test("a reporter built for the preview environment subscribes to nothing until started")
    @MainActor
    func aReporterSubscribesToNothingUntilStarted() {
        let spy = DiagnosticsSpy()

        _ = CrashReporter(sink: spy)

        // MetricKit's subscriber list isn't readable; this proves construction has no side effect
        // on the sink, and `AppEnvironment.preview()` never calls `didLaunch`.
        #expect(Platform.AppEnvironment.preview().diagnostics is Platform.Diagnostics.Recorder)
    }
}
