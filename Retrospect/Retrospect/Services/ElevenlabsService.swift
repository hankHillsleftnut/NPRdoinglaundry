import Foundation
import Security

/// Speech synthesis for podcast audio. The provider key lives only on the backend,
/// which proxies `POST /speech/synthesize`, so no credential ships in the binary.
class ElevenLabsService {
    static let shared = ElevenLabsService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // v3 TTS on a full transcript takes minutes
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    func generateSpeech(from text: String, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let audio = try await synthesize(text: text)
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsDirectory.appendingPathComponent("reflection_\(Date().timeIntervalSince1970).mp3")
                try audio.write(to: fileURL)
                await MainActor.run { completion(.success(fileURL)) }
            } catch {
                print("❌ Speech synthesis failed: \(error.localizedDescription)")
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    private func synthesize(text: String) async throws -> Data {
        guard let url = URL(string: Self.baseURL + "/speech/synthesize") else {
            throw ElevenLabsError.invalidURL
        }

        guard let token = Self.authToken() else {
            throw ElevenLabsError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "ElevenLabsService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Speech synthesis failed (HTTP \(httpResponse.statusCode)): \(body.prefix(300))"]
            )
        }

        guard !data.isEmpty else {
            throw ElevenLabsError.audioGenerationFailed
        }

        return data
    }

    private static var baseURL: String {
        #if DEBUG
        let override = UserDefaults.standard.string(forKey: RetrospectAPIClient.devBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return override.isEmpty ? RetrospectAPIClient.productionBaseURL : override
        #else
        return RetrospectAPIClient.productionBaseURL
        #endif
    }

    /// These must stay identical to the Keychain identifiers `RetrospectAPIClient`
    /// stores the backend JWT under; its own copies are private.
    private static let keychainService = "com.retrospect.api"
    private static let keychainTokenKey = "jwt_token"

    private static func authToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

enum ElevenLabsError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case audioGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the speech synthesis request."
        case .notAuthenticated:
            return "Sign in to generate podcast audio."
        case .audioGenerationFailed:
            return "The server returned no audio."
        }
    }
}
