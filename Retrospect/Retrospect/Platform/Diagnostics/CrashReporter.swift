import Foundation
import MetricKit

extension Platform.Diagnostics {
    /// Crash and hang markers from MetricKit: one `crash` record per crash
    /// diagnostic and one `hang` per hang diagnostic in each payload the
    /// system delivers (on the next launch after the event). Only the counts
    /// are read; the payloads' call stacks never leave MetricKit.
    final class CrashReporter: NSObject, MXMetricManagerSubscriber, Sendable {
        private let sink: any Sink

        init(sink: any Sink) {
            self.sink = sink
        }

        /// Starts receiving payloads; the app keeps the reporter alive.
        func start() {
            MXMetricManager.shared.add(self)
        }

        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            let records = payloads.flatMap { Self.records(crashes: $0.crashDiagnostics?.count ?? 0, hangs: $0.hangDiagnostics?.count ?? 0) }
            guard !records.isEmpty else { return }
            Task { [sink] in
                for record in records {
                    await sink.record(record)
                }
            }
        }

        /// The records for one payload's counts.
        static func records(crashes: Int, hangs: Int) -> [Record] {
            Array(repeating: Record.crash(Crash(kind: .crash)), count: max(0, crashes))
                + Array(repeating: Record.crash(Crash(kind: .hang)), count: max(0, hangs))
        }
    }
}
