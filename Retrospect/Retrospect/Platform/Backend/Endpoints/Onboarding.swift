import Foundation

extension Backend.Endpoints {
    /// `POST /v2/onboarding/answers` (contract 01 §4): one answer to a first-run question. Idempotent on
    /// `clientEntryId`, which is also the `Idempotency-Key`: repeating it returns the same answer, so the outbox
    /// can send it again and again until it lands.
    struct OnboardingAnswer: Backend.Endpoint {
        typealias Response = Saved

        /// The question, as the server stores it; the app owns the question copy (contract 01 §1).
        enum QuestionKey: String, Flows.ContractEnum {
            case namePlace = "name.place"
            case yearFromNow = "year.from.now"
            case careMost = "care.most"
            case onYourMind = "on.your.mind"
            case workingOn = "working.on"
            case keepMeaning = "keep.meaning"
            case highLow = "high.low"
            case people
            case howStraight = "how.straight"
            case yesterday
            case readingWatching = "reading.watching"
            case thisWeek = "this.week"
            case unknown
        }

        /// How the answer was given; `skipped` sends `""` as the text.
        enum Given: String, Flows.ContractEnum {
            case voice, typed, skipped, unknown
        }

        /// The request body. The outbox stores it encoded and sends the same bytes on every attempt
        /// (`Backend.Coding.encoder` sorts keys).
        struct Body: Codable, Sendable, Equatable {
            let questionKey: QuestionKey
            /// The person's words; `""` only when `given` is `skipped`.
            let text: String
            let given: Given
            /// Lowercase UUID, as the contract writes it.
            let clientEntryId: String
            let createdAt: Date

            init(questionKey: QuestionKey, text: String, given: Given, clientEntryID: UUID, createdAt: Date) {
                self.questionKey = questionKey
                self.text = text
                self.given = given
                clientEntryId = clientEntryID.uuidString.lowercased()
                self.createdAt = createdAt
            }
        }

        /// One stored answer (contract 01 §1's `Answer`).
        struct Answer: Decodable, Sendable, Equatable {
            let id: String
            let questionKey: QuestionKey
            let text: String
            let given: Given
            let createdAt: Date
        }

        struct Saved: Decodable, Sendable, Equatable {
            let answer: Answer
        }

        let body: Body?

        init(body: Body) {
            self.body = body
        }

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .onboardingAnswers
        }

        /// The answer's own id; nil only if the body's id were not a UUID, which `Body.init` rules out.
        var idempotencyKey: UUID? {
            body.flatMap { UUID(uuidString: $0.clientEntryId) }
        }
    }

    /// `POST /v2/onboarding/complete` (contract 01 §3): first run is over, `approved` becomes `member`. Idempotent
    /// on the server by state (a member or staff caller gets the same 200), so it carries no key.
    struct OnboardingComplete: Backend.Endpoint {
        struct Completed: Decodable, Sendable, Equatable {
            let access: Backend.AuthResponse.Access
        }

        typealias Response = Completed

        var method: Backend.Method {
            .post
        }

        var path: Backend.PathTemplate {
            .onboardingComplete
        }

        /// The contract's body is `{}`.
        var body: Backend.NoBody? {
            Backend.NoBody()
        }
    }
}
