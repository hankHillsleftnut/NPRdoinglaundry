@testable import Retrospect

/// Keeps diagnostics records in memory, in order. For tests.
actor DiagnosticsSpy: Platform.Diagnostics.Sink {
    private(set) var records: [Platform.Diagnostics.Record] = []

    init() {}

    /// A spy has no people: one generation, everything kept.
    nonisolated var generation: Int {
        0
    }

    func record(_ record: Platform.Diagnostics.Record) {
        records.append(record)
    }

    func record(_ record: Platform.Diagnostics.Record, startedIn _: Int) {
        self.record(record)
    }
}
