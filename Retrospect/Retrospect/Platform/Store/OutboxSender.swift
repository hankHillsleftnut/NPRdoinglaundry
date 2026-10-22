import Foundation

extension Store {
    /// What the server answered for one outbox item: the ids and state to
    /// write back to its entity.
    struct OutboxSendResult: Sendable, Equatable {
        /// The server's id for the entity (an entry's `id`).
        var serverID: String?
        var reading: Reading?

        init(serverID: String? = nil, reading: Reading? = nil) {
            self.serverID = serverID
            self.reading = reading
        }
    }

    /// Sends one outbox item. The drainer owns everything else: when to send,
    /// what a failure means, what to write back. Throws `Backend.Failure`, or
    /// `CancellationError` when the drain was cancelled mid-send.
    protocol OutboxSending: Sendable {
        func send(_ item: OutboxRow) async throws -> OutboxSendResult
    }

    /// The production sender: the stored payload goes out through
    /// `Backend.Client` with the stored key, byte for byte the same on every
    /// attempt (`Backend.Coding.encoder` sorts keys, so decoding the payload
    /// and encoding it again makes the same bytes).
    struct ClientSender: OutboxSending {
        let client: Backend.Client

        init(client: Backend.Client) {
            self.client = client
        }

        func send(_ item: OutboxRow) async throws -> OutboxSendResult {
            switch item.operation {
            case .entryCreate:
                guard let key = UUID(uuidString: item.id) else { throw Backend.Failure(.invalidRequest) }
                let body: Backend.Endpoints.CreateEntry.Body
                do {
                    body = try Backend.Coding.decoder.decode(Backend.Endpoints.CreateEntry.Body.self, from: item.payload)
                } catch {
                    throw Backend.Failure(.invalidRequest)
                }
                let created = try await client.send(Backend.Endpoints.CreateEntry(clientEntryID: key, content: body))
                return OutboxSendResult(serverID: created.entry.id, reading: Reading(rawValue: created.entry.reading.rawValue) ?? .unknown)
            case .unknown:
                // Written by a newer build; left in the queue for it.
                throw Backend.Failure(.invalidRequest)
            }
        }
    }
}
