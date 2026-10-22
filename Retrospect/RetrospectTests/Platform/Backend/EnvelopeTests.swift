import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct EnvelopeTests {
    @Test("meta decodes from its fixture")
    func metaDecodesFromItsFixture() throws {
        let meta = try Backend.Coding.decoder.decode(Backend.Envelope<Backend.Meta>.self, from: Fixtures.data("00", "meta")).data

        #expect(meta.minVersion == "1.0 (40)")
        #expect(meta.latestVersion == "1.1 (55)")
        #expect(meta.environment == .staging)
        #expect(abs(meta.serverTime.timeIntervalSince1970 - 1_792_569_604.2) < 0.0005)
    }

    @Test("an unknown server name decodes to unknown")
    func anUnknownServerNameDecodesToUnknown() throws {
        let json = #"{"success":true,"data":{"minVersion":"1.0 (1)","latestVersion":"1.0 (1)","serverTime":"2026-10-21T08:00:04Z","environment":"moon"}}"#
        let meta = try Backend.Coding.decoder.decode(Backend.Envelope<Backend.Meta>.self, from: Data(json.utf8)).data
        #expect(meta.environment == .unknown)
    }

    @Test("a failure body is not read as a success")
    func aFailureBodyIsNotReadAsASuccess() throws {
        let data = try Fixtures.data("00", "error.not_found")
        #expect(throws: DecodingError.self) { try Backend.Coding.decoder.decode(Backend.Envelope<Backend.Meta>.self, from: data) }
    }

    @Test("a success body is not read as a failure")
    func aSuccessBodyIsNotReadAsAFailure() throws {
        let data = try Fixtures.data("00", "meta")
        #expect(throws: DecodingError.self) { try Backend.Coding.decoder.decode(Backend.ErrorBody.self, from: data) }
    }

    @Test("a malformed success body fails to decode")
    func aMalformedSuccessBodyFailsToDecode() {
        let json = #"{"success":true,"data":{"minVersion":"1.0 (1)"}}"#
        #expect(throws: DecodingError.self) { try Backend.Coding.decoder.decode(Backend.Envelope<Backend.Meta>.self, from: Data(json.utf8)) }
    }

    @Test("an error body without a message or retry-after still decodes")
    func anErrorBodyWithoutOptionalFieldsDecodes() throws {
        let json = #"{"success":false,"error":{"code":"internal","message":null}}"#
        let body = try Backend.Coding.decoder.decode(Backend.ErrorBody.self, from: Data(json.utf8))
        #expect(body == Backend.ErrorBody(code: "internal"))
    }
}
