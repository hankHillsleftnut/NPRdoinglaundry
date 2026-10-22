import Foundation

extension Backend.Endpoints {
    /// `POST /v2/guesses/:id` (contract 02 §4): answer a guess, yes or no.
    /// Idempotent on the server's side: answering an answered guess returns
    /// its stored status, so the key (the outbox row's id) is safe to repeat.
    struct AnswerGuess: Backend.Endpoint {
        typealias Response = Answered

        struct Body: Codable, Sendable, Equatable {
            let verdict: Flows.Journal.GuessVerdict

            init(verdict: Flows.Journal.GuessVerdict) {
                self.verdict = verdict
            }
        }

        struct Answered: Decodable, Sendable, Equatable {
            let status: Flows.Journal.Guess.Status
        }

        let guessID: String
        let content: Body
        let key: UUID

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .guessByID
        }

        var pathParameters: [String: String] {
            ["id": guessID]
        }

        var body: Body? {
            content
        }

        var idempotencyKey: UUID? {
            key
        }
    }
}
