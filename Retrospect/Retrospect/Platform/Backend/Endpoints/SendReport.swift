import Foundation

extension Backend.Endpoints {
    /// `POST /v2/diagnostics` (DG.1): send a report. Idempotent on the
    /// report's id, which is also the `Idempotency-Key`: repeating it returns
    /// the same reference. Open to waitlisted people too.
    struct SendReport: Backend.Endpoint {
        typealias Response = Receipt

        /// The short reference the person can quote, e.g. `r-7KQ2`.
        struct Receipt: Decodable, Sendable, Equatable {
            let reference: String
        }

        let report: Platform.Diagnostics.Report

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .diagnostics
        }

        var body: Platform.Diagnostics.Report? {
            report
        }

        var idempotencyKey: UUID? {
            UUID(uuidString: report.reportId)
        }

        /// A report can be a few hundred kilobytes on a slow link.
        var timeout: Duration {
            .seconds(60)
        }
    }
}
