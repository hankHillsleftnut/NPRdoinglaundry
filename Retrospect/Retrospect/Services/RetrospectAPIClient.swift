import Foundation
import Security

// MARK: - API Client for Retrospect Backend
/// Handles all HTTP communication with the backend, including JWT-based authentication
/// stored securely in the iOS Keychain.
class RetrospectAPIClient: ObservableObject {
    static let shared = RetrospectAPIClient()

    // MARK: - Configuration
    #if DEBUG
    private let baseURL = "https://retrospect-api.onrender.com"
    #else
    private let baseURL = "https://retrospect-api.onrender.com"
    #endif

    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    @Published var currentEmail: String?

    private let session: URLSession
    private let keychainService = "com.retrospect.api"
    private let tokenKey = "jwt_token"
    private let userIdKey = "user_id"
    private let appleUserIdKey = "apple_user_id"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 420 // agent (Cook A/B/C) can take several minutes
        self.session = URLSession(configuration: config)

        // Restore auth state from Keychain
        if let _ = readKeychain(key: tokenKey),
           let userId = readKeychain(key: userIdKey) {
            self.isAuthenticated = true
            self.currentUserId = userId
        }
    }

    // MARK: - Authentication

    /// Sign in with Apple credentials. Sends the Apple user ID (and optional email)
    /// to the backend, receives a JWT, and stores it in the Keychain.
    func signIn(appleUserId: String, email: String? = nil, identityToken: String? = nil) async throws -> (userId: String, email: String?) {
        var body: [String: Any] = ["appleUserId": appleUserId]
        if let email = email { body["email"] = email }
        if let token = identityToken { body["identityToken"] = token }

        let response: SignInResponse = try await post(path: "/auth/signin", body: body, authenticated: false)

        guard response.success, let data = response.data else {
            throw APIError.authFailed(response.error ?? "Unknown error")
        }

        // Store credentials
        saveKeychain(key: tokenKey, value: data.token)
        saveKeychain(key: userIdKey, value: data.user.id)
        saveKeychain(key: appleUserIdKey, value: appleUserId)

        await MainActor.run {
            self.isAuthenticated = true
            self.currentUserId = data.user.id
            self.currentEmail = data.user.email
        }

        return (userId: data.user.id, email: data.user.email)
    }

    /// Sign out by clearing Keychain and local state.
    func signOut() {
        deleteKeychain(key: tokenKey)
        deleteKeychain(key: userIdKey)
        deleteKeychain(key: appleUserIdKey)

        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUserId = nil
            self.currentEmail = nil
        }
    }

    /// Attempt to refresh the token using the stored Apple user ID.
    func refreshToken() async throws {
        guard let appleUserId = readKeychain(key: appleUserIdKey) else {
            throw APIError.notAuthenticated
        }

        let response: RefreshResponse = try await post(
            path: "/auth/refresh",
            body: ["appleUserId": appleUserId],
            authenticated: false
        )

        guard response.success, let data = response.data else {
            signOut()
            throw APIError.authFailed("Token refresh failed")
        }

        saveKeychain(key: tokenKey, value: data.token)
    }

    // MARK: - Content Sync

    /// Upload content to the backend as raw content for the analysis pipeline.
    func uploadContent(
        contentType: String,
        content: String,
        contentDate: Date? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        var body: [String: Any] = [
            "contentType": contentType,
            "content": content,
        ]
        if let date = contentDate {
            body["contentDate"] = ISO8601DateFormatter().string(from: date)
        }
        if let metadata = metadata {
            body["metadata"] = metadata
        }

        let _: GenericResponse = try await post(path: "/content", body: body)
    }

    // MARK: - Goals Sync

    /// Sync a list of goal titles to the backend.
    /// Fetches existing goals, adds new ones, deactivates removed ones.
    func syncGoals(_ goals: [String]) async throws {
        try await syncRichGoals(goals.map { RichGoal(title: $0) })
    }

    func syncRichGoals(_ goals: [RichGoal]) async throws {
        let existing: GoalsListResponse = try await get(path: "/goals")
        let existingTitles = Set((existing.data ?? []).map { $0.title.lowercased() })
        let localTitles = Set(goals.map { $0.title.lowercased() })

        for goal in goals {
            if !existingTitles.contains(goal.title.lowercased()) {
                let _: GenericResponse = try await post(path: "/goals", body: [
                    "title": goal.title,
                    "description": goal.backendDescription,
                ])
            }
        }

        for existingGoal in (existing.data ?? []) {
            if !localTitles.contains(existingGoal.title.lowercased()) && existingGoal.isActive {
                let _: GenericResponse = try await patch(
                    path: "/goals/\(existingGoal.id)",
                    body: ["isActive": false]
                )
            }
        }
    }

    // MARK: - Goal Extraction (Backend)

    /// Send a voice transcription to the backend for CBT-informed goal extraction.
    /// The backend extracts goals, saves them to Supabase with embeddings, and returns both
    /// the extracted analysis and the saved goal records.
    func extractAndSaveGoals(text: String) async throws -> GoalExtractionResponse {
        let response: GoalExtractionAPIResponse = try await post(
            path: "/goals/extract-and-save",
            body: ["text": text]
        )
        guard response.success, let data = response.data else {
            throw APIError.serverError(response.error ?? "Goal extraction failed")
        }
        return GoalExtractionResponse(
            extracted: data.extracted,
            saved: data.saved,
            processingNotes: response.processingNotes
        )
    }

    // MARK: - Voice Persona

    /// Set the user's voice persona preference.
    func setVoicePersona(_ persona: String) async throws {
        let _: GenericResponse = try await patch(
            path: "/profile/persona",
            body: ["persona": persona]
        )
    }

    /// Get the user's current profile including persona preference.
    func fetchProfile() async throws -> UserProfile {
        let response: ProfileResponse = try await get(path: "/profile")
        guard let data = response.data else {
            throw APIError.serverError("Failed to fetch profile")
        }
        return data
    }

    // MARK: - Podcasts

    /// Fetch the list of ready podcast episodes.
    func fetchPodcasts(limit: Int = 20, offset: Int = 0) async throws -> [PodcastEpisode] {
        let response: PodcastListResponse = try await get(
            path: "/podcasts?limit=\(limit)&offset=\(offset)"
        )
        return response.data ?? []
    }

    /// Fetch the latest podcast episode.
    func fetchLatestPodcast() async throws -> PodcastEpisode? {
        let response: PodcastSingleResponse = try await get(path: "/podcasts/latest")
        return response.data
    }

    /// Fetch a specific podcast episode by ID.
    func fetchPodcast(id: String) async throws -> PodcastEpisode? {
        let response: PodcastSingleResponse = try await get(path: "/podcasts/\(id)")
        return response.data
    }

    /// Request on-demand podcast generation.
    func generatePodcast(daysSince: Int = 7, generationSource: PodcastGenerationSource? = nil) async throws -> PodcastEpisode {
        var body: [String: Any] = ["daysSince": daysSince]
        if let generationSource {
            body["generationSource"] = generationSource.rawValue
        }

        let response: PodcastSingleResponse = try await post(
            path: "/podcasts/generate",
            body: body
        )
        guard let episode = response.data else {
            throw APIError.serverError(response.error ?? "Generation failed")
        }
        return episode
    }

    // MARK: - Claude Proxy

    /// Proxy a Claude text generation call through the backend so the API key never ships in the binary.
    func claudeGenerate(
        systemPrompt: String? = nil,
        userMessage: String? = nil,
        messages: [[String: Any]]? = nil,
        maxTokens: Int = 2000
    ) async throws -> String {
        var body: [String: Any] = ["maxTokens": maxTokens]
        if let systemPrompt { body["systemPrompt"] = systemPrompt }
        if let userMessage { body["userMessage"] = userMessage }
        if let messages { body["messages"] = messages }
        let response: ClaudeProxyResponse = try await post(path: "/claude/generate", body: body)
        guard response.success, let data = response.data else {
            throw APIError.serverError(response.error ?? "Claude generation failed")
        }
        return data.text
    }

    // MARK: - Insights

    /// Fetch insights for the current user.
    func fetchInsights(goalId: String? = nil, limit: Int = 50) async throws -> [BackendInsight] {
        var path = "/insights?limit=\(limit)"
        if let goalId = goalId { path += "&goalId=\(goalId)" }
        let response: InsightsListResponse = try await get(path: path)
        return response.data ?? []
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        return try await request(method: "GET", path: path, body: nil)
    }

    private func post<T: Decodable>(path: String, body: [String: Any], authenticated: Bool = true) async throws -> T {
        return try await request(method: "POST", path: path, body: body, authenticated: authenticated)
    }

    private func patch<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        return try await request(method: "PATCH", path: path, body: body)
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: [String: Any]?,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if authenticated {
            guard let token = readKeychain(key: tokenKey) else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, httpResponse) = try await session.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle 401 — attempt token refresh once
        if response.statusCode == 401 && authenticated {
            try await refreshToken()
            // Retry with new token
            if let newToken = readKeychain(key: tokenKey) {
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHttp.statusCode) else {
                    throw APIError.serverError("Request failed after token refresh")
                }
                return try JSONDecoder.apiDecoder.decode(T.self, from: retryData)
            }
        }

        guard (200...299).contains(response.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError("HTTP \(response.statusCode): \(errorBody)")
        }

        return try JSONDecoder.apiDecoder.decode(T.self, from: data)
    }

    // MARK: - Keychain Helpers

    private func saveKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case authFailed(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .notAuthenticated: return "Not authenticated"
        case .authFailed(let msg): return "Authentication failed: \(msg)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

// MARK: - Response Models

private struct SignInResponse: Codable {
    let success: Bool
    let data: SignInData?
    let error: String?

    struct SignInData: Codable {
        let token: String
        let user: UserData
    }

    struct UserData: Codable {
        let id: String
        let email: String?
    }
}

private struct RefreshResponse: Codable {
    let success: Bool
    let data: RefreshData?
    let error: String?

    struct RefreshData: Codable {
        let token: String
    }
}

private struct GenericResponse: Codable {
    let success: Bool
    let error: String?
}

private struct GoalsListResponse: Codable {
    let success: Bool
    let data: [BackendGoal]?
    let error: String?
}

private struct PodcastListResponse: Codable {
    let success: Bool
    let data: [PodcastEpisode]?
    let error: String?
}

private struct PodcastSingleResponse: Codable {
    let success: Bool
    let data: PodcastEpisode?
    let error: String?
}

private struct ClaudeProxyResponse: Codable {
    let success: Bool
    let data: ClaudeProxyData?
    let error: String?

    struct ClaudeProxyData: Codable {
        let text: String
    }
}

private struct InsightsListResponse: Codable {
    let success: Bool
    let data: [BackendInsight]?
    let error: String?
}

private struct ProfileResponse: Codable {
    let success: Bool
    let data: UserProfile?
    let error: String?
}

// MARK: - Goal Extraction Response Models

private struct GoalExtractionAPIResponse: Codable {
    let success: Bool
    let data: GoalExtractionData?
    let error: String?
    let processingNotes: String?

    struct GoalExtractionData: Codable {
        let extracted: [ExtractedGoalFromBackend]
        let saved: [BackendGoal]
    }
}

struct ExtractedGoalFromBackend: Codable {
    let title: String
    let description: String
    let reasoning: String
}

struct GoalExtractionResponse {
    let extracted: [ExtractedGoalFromBackend]
    let saved: [BackendGoal]
    let processingNotes: String?
}

// MARK: - Public Profile Model
struct UserProfile: Codable {
    let id: String
    let email: String?
    let voicePersona: String?
    let createdAt: Date
    let availablePersonas: [VoicePersonaOption]?
}

struct VoicePersonaOption: Codable, Identifiable {
    let id: String
    let displayName: String
    let description: String
}

// MARK: - JSON Decoder with snake_case support
extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
}
