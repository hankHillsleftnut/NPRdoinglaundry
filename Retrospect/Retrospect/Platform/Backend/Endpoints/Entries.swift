import Foundation

extension Backend.Endpoints {
    /// `POST /v2/entries` (contract 02 §2): send one entry into the bank.
    /// Idempotent on `clientEntryId`, which is also the `Idempotency-Key`:
    /// repeating it returns the same entry.
    struct CreateEntry: Backend.Endpoint {
        typealias Response = Created

        /// What a new entry can be when it's sent.
        enum Kind: String, Codable, Sendable {
            case typed, voice
        }

        /// The request body. The outbox stores it encoded and sends the same
        /// bytes on every attempt (`Backend.Coding.encoder` sorts keys).
        struct Body: Codable, Sendable, Equatable {
            let text: String
            let kind: Kind
            /// Lowercase UUID, as the contract writes it.
            let clientEntryId: String
            let createdAt: Date

            init(text: String, kind: Kind, clientEntryID: UUID, createdAt: Date) {
                self.text = text
                self.kind = kind
                clientEntryId = clientEntryID.uuidString.lowercased()
                self.createdAt = createdAt
            }
        }

        struct Created: Decodable, Sendable {
            let entry: Flows.Journal.Entry
        }

        let clientEntryID: UUID
        let content: Body

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .entries
        }

        var body: Body? {
            content
        }

        var idempotencyKey: UUID? {
            clientEntryID
        }
    }
}

extension Backend.Endpoints {
    /// `GET /v2/entries/today` (contract 02 §2): today's entries in the person's
    /// own day (from `X-Time-Zone`), oldest first.
    struct EntriesToday: Backend.Endpoint {
        struct Today: Decodable, Sendable {
            /// The person's local day, `YYYY-MM-DD`.
            let date: String
            let entries: [Flows.Journal.Entry]
        }

        typealias Response = Today

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .entriesToday
        }
    }
}
