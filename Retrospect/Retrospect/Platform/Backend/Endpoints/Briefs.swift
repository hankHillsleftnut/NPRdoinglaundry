import Foundation

extension Backend.Endpoints {
    /// `GET /v2/briefs/latest` (contract 02 §3): the newest brief, whether the person has the brief on, and
    /// when the next one is due. The app derives what the card shows from these (`Journal.BriefSlot.derive`).
    struct BriefLatest: Backend.Endpoint {
        struct Latest: Codable, Sendable, Equatable {
            let brief: Flows.Journal.Brief?
            let enabled: Bool
            /// When the next brief is due; null when none is on its way.
            let nextAt: Date?

            init(brief: Flows.Journal.Brief?, enabled: Bool, nextAt: Date?) {
                self.brief = brief
                self.enabled = enabled
                self.nextAt = nextAt
            }

            /// The keys are always written, null included, so a kept copy reads back the same.
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(brief, forKey: .brief)
                try container.encode(enabled, forKey: .enabled)
                try container.encode(nextAt, forKey: .nextAt)
            }
        }

        typealias Response = Latest

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .briefsLatest
        }
    }
}
