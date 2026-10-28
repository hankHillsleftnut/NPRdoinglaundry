import Foundation

extension Store {
    /// What the server answered for one outbox item: the ids and state to
    /// write back to its entity.
    struct OutboxSendResult: Sendable, Equatable {
        /// The server's id for the entity (an entry's `id`).
        var serverID: String?
        var reading: Reading?
        /// The server's `createdAt` (clamped if the phone's clock was ahead) and its `day`.
        var createdAt: Date?
        var day: String?
        /// A report's short reference (`r-7KQ2`), for the "sent" toast.
        var reference: String?
        /// Where the account stands after `onboarding.complete` (`member`), for the session to keep.
        var access: Session.AccessState?

        init(
            serverID: String? = nil, reading: Reading? = nil, createdAt: Date? = nil, day: String? = nil, reference: String? = nil,
            access: Session.AccessState? = nil
        ) {
            self.reference = reference
            self.serverID = serverID
            self.reading = reading
            self.createdAt = createdAt
            self.day = day
            self.access = access
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
                return OutboxSendResult(
                    serverID: created.entry.id, reading: Reading(rawValue: created.entry.reading.rawValue) ?? .unknown,
                    createdAt: created.entry.createdAt, day: created.entry.day
                )
            case .guessAnswer:
                guard let key = UUID(uuidString: item.id) else { throw Backend.Failure(.invalidRequest) }
                let body: Backend.Endpoints.AnswerGuess.Body
                do {
                    body = try Backend.Coding.decoder.decode(Backend.Endpoints.AnswerGuess.Body.self, from: item.payload)
                } catch {
                    throw Backend.Failure(.invalidRequest)
                }
                _ = try await client.send(Backend.Endpoints.AnswerGuess(guessID: item.entityID, content: body, key: key))
                return OutboxSendResult()
            case .diagnosticsSend:
                return try await sendReport(item)
            case .onboardingAnswer:
                return try await sendAnswer(item)
            case .onboardingComplete:
                return try await sendComplete()
            case .unknown:
                // Written by a newer build; left in the queue for it.
                throw Backend.Failure(.invalidRequest)
            }
        }

        /// `diagnostics.send`: the stored report goes to its door; the door's key is the report's own id, which is also the row's id.
        private func sendReport(_ item: OutboxRow) async throws -> OutboxSendResult {
            let report: Platform.Diagnostics.Report
            do {
                report = try Backend.Coding.decoder.decode(Platform.Diagnostics.Report.self, from: item.payload)
            } catch {
                throw Backend.Failure(.invalidRequest)
            }
            guard report.reportId.lowercased() == item.id else { throw Backend.Failure(.invalidRequest) }
            let receipt = try await client.send(Backend.Endpoints.SendReport(report: report))
            return OutboxSendResult(reference: receipt.reference)
        }
    }
}

extension Backend.Failure.Kind {
    /// How long a spend refusal holds its outbox item: the server's Retry-After (contract 00 §2), else an hour.
    var spendWait: TimeInterval {
        guard case let .spendLimited(retryAfter?) = self else { return 3600 }
        return max(1, TimeInterval(retryAfter.components.seconds))
    }
}

extension Store.Outbox {
    /// What a failure means for the item and the pass (kept beside the sender, out of the actor's body).
    static func outcome(of failure: Backend.Failure) -> Outcome {
        switch failure.kind {
        // an old build (426) gates every door: all wait for the update. A spent day (429) holds only its own item.
        case .offline, .unauthenticated, .sessionRevoked, .updateRequired: .pause
        case .spendLimited: .wait
        case .rateLimited, .upstreamTimeout, .upstreamUnavailable, .internal, .timedOut, .transport: .retry
        case .invalidRequest, .invalidCredentials, .inviteRequired, .suspended, .notFound, .idempotencyMismatch,
             .inviteInvalid, .inviteUsed, .inviteExpired, .decoding, .unknown: .dead
        }
    }
}
