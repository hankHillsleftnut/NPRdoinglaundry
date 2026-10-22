import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CodingTests {
    private struct Stamped: Codable, Equatable {
        let sentAt: Date
    }

    @Test("dates decode with and without fractional seconds")
    func datesDecodeWithAndWithoutFractionalSeconds() throws {
        let decoder = Backend.Coding.decoder
        let withMs = try decoder.decode(Stamped.self, from: Data(#"{"sentAt":"2026-10-21T08:00:04.200Z"}"#.utf8))
        let without = try decoder.decode(Stamped.self, from: Data(#"{"sentAt":"2026-10-21T08:00:04Z"}"#.utf8))

        #expect(abs(withMs.sentAt.timeIntervalSince1970 - 1_792_569_604.2) < 0.0005)
        #expect(without.sentAt == Date(timeIntervalSince1970: 1_792_569_604))
    }

    @Test("a date that isn't ISO 8601 fails to decode")
    func aDateThatIsntISO8601FailsToDecode() {
        #expect(throws: DecodingError.self) {
            try Backend.Coding.decoder.decode(Stamped.self, from: Data(#"{"sentAt":"21 Oct 2026"}"#.utf8))
        }
    }

    @Test("dates encode in UTC with milliseconds, and keys stay camelCase")
    func datesEncodeInUTCWithMilliseconds() throws {
        let data = try Backend.Coding.encoder.encode(Stamped(sentAt: Date(timeIntervalSince1970: 1_792_569_604.2)))

        #expect(String(bytes: data, encoding: .utf8) == #"{"sentAt":"2026-10-21T08:00:04.200Z"}"#)
    }

    @Test("milliseconds are rounded, not truncated")
    func millisecondsAreRoundedNotTruncated() throws {
        // 0.123 is stored as 0.12299…; a truncating formatter writes .122.
        let data = try Backend.Coding.encoder.encode(Stamped(sentAt: Date(timeIntervalSince1970: 1_792_569_604.123)))
        #expect(String(bytes: data, encoding: .utf8) == #"{"sentAt":"2026-10-21T08:00:04.123Z"}"#)
    }

    @Test("whole seconds and dates before 1970 keep three digits", arguments: [
        (0.0, "1970-01-01T00:00:00.000Z"),
        (-0.5, "1969-12-31T23:59:59.500Z"),
        (1_792_569_604.0006, "2026-10-21T08:00:04.001Z"),
    ])
    func wholeSecondsAndEarlyDatesKeepThreeDigits(_ seconds: Double, _ expected: String) {
        #expect(Backend.Coding.timestamp(Date(timeIntervalSince1970: seconds)) == expected)
    }

    @Test("an encoded date decodes to the same instant")
    func anEncodedDateDecodesToTheSameInstant() throws {
        let original = Stamped(sentAt: Date(timeIntervalSince1970: 1_792_569_604.123))
        let decoded = try Backend.Coding.decoder.decode(Stamped.self, from: Backend.Coding.encoder.encode(original))
        #expect(abs(decoded.sentAt.timeIntervalSince(original.sentAt)) < 0.0005)
    }
}
