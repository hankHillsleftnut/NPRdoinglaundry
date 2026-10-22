import Foundation

extension Backend {
    /// The JSON rules of every contract: camelCase keys as written (never
    /// `convertFromSnakeCase`), ISO 8601 dates with milliseconds.
    enum Coding {
        /// The seam's decoder (`JSONDecoder.contract`): dates with or without
        /// fractional seconds. One decoder for the flows and the client.
        static var decoder: JSONDecoder {
            JSONDecoder.contract
        }

        /// Dates go out as `2026-10-21T08:00:04.200Z`, always UTC, always milliseconds.
        /// Keys are sorted, so the same value always makes the same bytes (a
        /// retried write sends exactly what it sent the first time).
        static var encoder: JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(timestamp(date))
            }
            return encoder
        }

        /// The date to the nearest millisecond. Built from whole milliseconds,
        /// because ISO8601FormatStyle truncates the fraction (.123 stored as
        /// .12299… would go out as .122).
        static func timestamp(_ date: Date) -> String {
            let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
            let (seconds, fraction) = milliseconds.quotientAndRemainder(dividingBy: 1000)
            let (wholeSeconds, millis) = fraction < 0 ? (seconds - 1, fraction + 1000) : (seconds, fraction)
            let base = Date(timeIntervalSince1970: TimeInterval(wholeSeconds)).formatted(secondsUTC)
            let padded = String(millis + 1000).dropFirst()
            return "\(base.dropLast()).\(padded)Z"
        }

        private static let secondsUTC = Date.ISO8601FormatStyle(timeZone: .gmt)
    }
}
