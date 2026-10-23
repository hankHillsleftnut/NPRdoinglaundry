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

extension Backend.Endpoints {
    /// `GET /v2/entries` (contract 02 §5): the drawer's list, newest first, a page at a time. `q` searches the
    /// person's own words; matches come back as UTF-16 ranges.
    struct EntriesList: Backend.Endpoint {
        struct Listed: Decodable, Sendable {
            let entries: [Flows.Journal.Entry]
            /// Nil on the last page.
            let nextCursor: String?
        }

        typealias Response = Listed

        let cursor: String?
        /// Already trimmed and clipped; nil when there is nothing to search for.
        let search: String?

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .entries
        }

        var query: [URLQueryItem] {
            [cursor.map { URLQueryItem(name: "cursor", value: $0) }, search.map { URLQueryItem(name: "q", value: $0) }].compactMap { $0 }
        }
    }

    /// `GET /v2/entries/:id` (contract 02 §5): one entry; another person's or a deleted one is `not_found`.
    struct EntryByID: Backend.Endpoint {
        struct Found: Decodable, Sendable {
            let entry: Flows.Journal.Entry
        }

        typealias Response = Found

        let id: String

        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .entryByID
        }

        var pathParameters: [String: String] {
            ["id": id]
        }
    }
}
