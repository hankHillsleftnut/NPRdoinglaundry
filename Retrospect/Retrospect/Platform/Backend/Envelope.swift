import Foundation

extension Backend {
    /// A successful response: `{ "success": true, "data": … }` (contract 00 §2).
    struct Envelope<Payload: Decodable>: Decodable {
        let data: Payload

        private enum CodingKeys: String, CodingKey { case success, data }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard try container.decode(Bool.self, forKey: .success) else {
                throw DecodingError.dataCorruptedError(forKey: .success, in: container, debugDescription: "a failure body, not a success")
            }
            data = try container.decode(Payload.self, forKey: .data)
        }
    }

    /// A failed response: `{ "success": false, "error": { code, message, retryAfterSeconds? } }`.
    struct ErrorBody: Decodable, Sendable, Equatable {
        let code: String
        let message: String?
        let retryAfterSeconds: Int?

        private enum CodingKeys: String, CodingKey { case success, error }
        private enum ErrorKeys: String, CodingKey { case code, message, retryAfterSeconds }

        init(code: String, message: String? = nil, retryAfterSeconds: Int? = nil) {
            self.code = code
            self.message = message
            self.retryAfterSeconds = retryAfterSeconds
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard try !container.decode(Bool.self, forKey: .success) else {
                throw DecodingError.dataCorruptedError(forKey: .success, in: container, debugDescription: "a success body, not a failure")
            }
            let error = try container.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
            code = try error.decode(String.self, forKey: .code)
            message = try error.decodeIfPresent(String.self, forKey: .message)
            retryAfterSeconds = try error.decodeIfPresent(Int.self, forKey: .retryAfterSeconds)
        }
    }
}
