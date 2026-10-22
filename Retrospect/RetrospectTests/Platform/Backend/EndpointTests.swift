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

    @Test("send report is an authenticated POST keyed by the report id, with a long timeout")
    func sendReportIsAPostKeyedByTheReportID() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000d1"))
        let report = Platform.Diagnostics.Report(
            reportID: id, createdAt: Date(timeIntervalSince1970: 1_792_569_604), note: nil,
            environment: Platform.Diagnostics.Environment(sources: .init(
                info: nil, osVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), machine: "arm64",
                locale: Locale(identifier: "en_US"), timeZone: .gmt, contentSize: .large, reduceMotion: false, voiceOver: false,
                network: .unknown, freeDiskBytes: nil
            )),
            account: .init(provider: .apple, access: .member, entitlement: .trial),
            events: [], network: [], outbox: .empty, failures: [], performance: .none, crashes: []
        )
        let send = Backend.Endpoints.SendReport(report: report)

        #expect(send.method == .post)
        #expect(send.path == .diagnostics)
        #expect(send.path.rawValue == "/v2/diagnostics")
        #expect(send.requiresAuth)
        #expect(send.body == report)
        #expect(send.idempotencyKey == id)
        #expect(send.timeout == .seconds(60))
    }

    @Test("every path template is a /v2 path")
    func everyPathTemplateIsAV2Path() {
        #expect(Backend.PathTemplate.allCases.allSatisfy { $0.rawValue.hasPrefix("/v2/") })
    }
}
