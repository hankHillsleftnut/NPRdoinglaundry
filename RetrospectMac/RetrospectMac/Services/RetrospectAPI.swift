import Foundation
import Combine

/// macOS port of the Retrospect backend client. Mirrors the iOS `RetrospectAPIClient`
/// contract: `POST /auth/signin` and `POST /content`, JWT in the Keychain, Bearer auth.
@MainActor
final class RetrospectAPI: ObservableObject {
    static let shared = RetrospectAPI()

    private let baseURL = "https://retrospect-api.onrender.com"
    private let session: URLSession

    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var currentEmail: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 480 // agent pipeline can take minutes
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)

        if Keychain.get(Keychain.Key.token) != nil, let uid = Keychain.get(Keychain.Key.userId) {
            isAuthenticated = true
            currentUserId = uid
        }
    }

    enum APIError: LocalizedError {
        case badURL, notAuthenticated, http(Int, String), auth(String), decode
        var errorDescription: String? {
            switch self {
            case .badURL: return "Bad URL"
            case .notAuthenticated: return "Not signed in"
            case .http(let code, let body): return "HTTP \(code): \(body)"
            case .auth(let m): return m
            case .decode: return "Could not decode response"
            }
        }
    }

    // MARK: - Auth

    @discardableResult
    func signIn(appleUserId: String, email: String?, identityToken: String?) async throws -> (userId: String, email: String?) {
        var body: [String: Any] = ["appleUserId": appleUserId]
        if let email { body["email"] = email }
        if let identityToken { body["identityToken"] = identityToken }

        let resp: SignInResponse = try await post(path: "/auth/signin", body: body, authenticated: false)
        guard resp.success, let data = resp.data else {
            throw APIError.auth(resp.error ?? "Sign in failed")
        }
        Keychain.set(data.token, for: Keychain.Key.token)
        Keychain.set(data.user.id, for: Keychain.Key.userId)
        Keychain.set(appleUserId, for: Keychain.Key.appleUserId)
        isAuthenticated = true
        currentUserId = data.user.id
        currentEmail = data.user.email
        return (data.user.id, data.user.email)
    }

    func signOut() {
        Keychain.delete(Keychain.Key.token)
        Keychain.delete(Keychain.Key.userId)
        Keychain.delete(Keychain.Key.appleUserId)
        isAuthenticated = false
        currentUserId = nil
        currentEmail = nil
    }

    // MARK: - Content sync

    /// Upload an entry as journal content for the analysis/synthesis pipeline.
    func uploadContent(contentType: String, content: String, contentDate: Date?, metadata: [String: Any]? = nil) async throws {
        var body: [String: Any] = ["contentType": contentType, "content": content]
        if let contentDate { body["contentDate"] = ISO8601DateFormatter().string(from: contentDate) }
        if let metadata { body["metadata"] = metadata }
        let _: GenericResponse = try await post(path: "/content", body: body, authenticated: true)
    }

    /// Kick the daily synthesis. The backend route may differ; this is best-effort and
    /// failures are tolerated by the scheduler (sync of content already feeds the pipeline).
    func requestSynthesis(daysSince: Int = 1) async throws {
        let body: [String: Any] = ["daysSince": daysSince, "generationSource": "macos_journal"]
        let _: GenericResponse = try await post(path: "/podcasts/generate", body: body, authenticated: true)
    }

    // MARK: - Transport

    private func post<T: Decodable>(path: String, body: [String: Any], authenticated: Bool) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            guard let token = Keychain.get(Keychain.Key.token) else { throw APIError.notAuthenticated }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw APIError.auth("Session expired — sign in again") }
            throw APIError.http(http.statusCode, text)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decode
        }
    }
}

// MARK: - Wire types

struct SignInResponse: Decodable {
    let success: Bool
    let data: SignInData?
    let error: String?
}
struct SignInData: Decodable {
    let token: String
    let user: SignInUser
}
struct SignInUser: Decodable {
    let id: String
    let email: String?
}
struct GenericResponse: Decodable {
    let success: Bool?
    let error: String?
}
