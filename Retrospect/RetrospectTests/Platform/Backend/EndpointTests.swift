import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct EndpointTests {
    @Test("meta is a public GET with no body, no key and the default timeout")
    func metaIsAPublicGet() {
        let meta = Backend.Endpoints.Meta()

        #expect(meta.method == .get)
        #expect(meta.path == .meta)
        #expect(meta.path.rawValue == "/v2/meta")
        #expect(!meta.requiresAuth)
        #expect(meta.body == nil)
        #expect(meta.idempotencyKey == nil)
        #expect(meta.pathParameters.isEmpty)
        #expect(meta.query.isEmpty)
        #expect(meta.timeout == .seconds(20))
    }

    @Test("answer guess is a keyed POST to /v2/guesses/:id with the verdict as its body")
    func answerGuessIsAKeyedPost() throws {
        let key = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000777"))
        let answer = Backend.Endpoints.AnswerGuess(guessID: "g1", content: .init(verdict: .no), key: key)

        #expect(answer.method == .post)
        #expect(answer.path == .guessByID)
        #expect(answer.path.rawValue == "/v2/guesses/:id")
        #expect(answer.pathParameters == ["id": "g1"])
        #expect(answer.requiresAuth)
        #expect(answer.idempotencyKey == key)
        #expect(try #require(String(data: Backend.Coding.encoder.encode(answer.body), encoding: .utf8)) == #"{"verdict":"no"}"#)
    }

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") })
    }
}
