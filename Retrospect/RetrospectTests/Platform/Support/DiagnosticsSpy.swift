@testable import Retrospect

/// Keeps diagnostics records in memory, in order. For tests.
actor DiagnosticsSpy: Platform.Diagnostics.Sink {
    private(set) var records: [Platform.Diagnostics.Record] = []

    init() {}

    func record(_ record: Platform.Diagnostics.Record) {
        records.append(record)
    }
}
