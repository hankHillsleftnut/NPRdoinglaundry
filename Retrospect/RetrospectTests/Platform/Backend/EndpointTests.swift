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

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") })
    }
}
