import Foundation
import Security
import CryptoKit
import UIKit

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
        config.timeoutIntervalForRequest = 480 // agent pipeline (Cook A/B/C + TTS) takes 3-5 min
        config.timeoutIntervalForResource = 600
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

    /// A new Apple identity token is required to renew backend authentication.
    /// A stored Apple user ID alone is not an authentication credential.
    func refreshToken() async throws {
        signOut()
        throw APIError.authFailed("Please sign in with Apple again")
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

    /// Upload provider objects through the agent-owned integration pipeline.
    /// The payload remains available for provenance while canonical text feeds
    /// the current intelligence agents.
    func uploadIntegrationItems(
        providerId: String,
        runType: String,
        cursorBefore: [String: Any] = [:],
        cursorAfter: [String: Any] = [:],
        items: [[String: Any]]
    ) async throws {
        guard !items.isEmpty else { return }

        let serialized = try JSONSerialization.data(
            withJSONObject: ["providerId": providerId, "runType": runType, "cursorBefore": cursorBefore, "cursorAfter": cursorAfter, "items": items],
            options: [.sortedKeys]
        )
        let idempotencyKey = SHA256.hash(data: serialized).map { String(format: "%02x", $0) }.joined()
        let nativeProviders = Set(["healthkit", "screen_time", "calendar", "apple_music", "photos", "contacts"])
        let endpoint = nativeProviders.contains(providerId)
            ? "/integrations/\(providerId)/device-batches"
            : "/integrations/\(providerId)/items"
        let _: GenericResponse = try await post(
            path: endpoint,
            body: [
                "idempotencyKey": "ios:\(idempotencyKey)",
                "runType": runType,
                "cursorBefore": cursorBefore,
                "cursorAfter": cursorAfter,
                "items": items,
            ]
        )
    }

    func startOAuthConnection(providerId: String) async throws -> URL {
        let response: OAuthStartResponse = try await post(
            path: "/integrations/\(providerId)/connect/start",
            body: [:]
        )
        guard response.success, let value = response.data?.authorizationUrl, let url = URL(string: value) else {
            throw APIError.serverError(response.error ?? "Could not start connection")
        }
        return url
    }

    @MainActor
    func openOAuthConnection(providerId: String) async throws {
        let url = try await startOAuthConnection(providerId: providerId)
        await UIApplication.shared.open(url)
    }

    func importIntegrationArchive(providerId: String, fileURL: URL) async throws {
        let access = fileURL.startAccessingSecurityScopedResource()
        defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let response: ImportStartResponse = try await post(
            path: "/integrations/\(providerId)/imports",
            body: [
                "filename": fileURL.lastPathComponent,
                "contentType": fileURL.pathExtension.lowercased() == "zip"
                    ? "application/zip"
                    : fileURL.pathExtension.lowercased() == "csv" ? "text/csv" : "application/json",
                "byteSize": data.count,
            ]
        )
        guard response.success, let upload = response.data, let signedURL = URL(string: upload.signedUrl) else {
            throw APIError.serverError(response.error ?? "Could not create archive import")
        }
        var request = URLRequest(url: signedURL)
        request.httpMethod = "PUT"
        request.setValue(fileURL.pathExtension.lowercased() == "zip" ? "application/zip" : "application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, uploadResponse) = try await session.upload(for: request, from: data)
        guard let http = uploadResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError("Archive upload failed")
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let _: GenericResponse = try await post(
            path: "/integrations/imports/\(upload.importId)/complete",
            body: ["sha256": digest]
        )
    }

    func uploadIntegrationAsset(
        providerId: String,
        providerObjectType: String,
        providerObjectId: String,
        assetRole: String = "original",
        contentType: String,
        data: Data
    ) async throws {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let response: AssetStartResponse = try await post(
            path: "/integrations/\(providerId)/assets",
            body: [
                "providerObjectType": providerObjectType,
                "providerObjectId": providerObjectId,
                "assetRole": assetRole,
                "contentType": contentType,
                "byteSize": data.count,
                "sha256": digest,
            ]
        )
        guard response.success, let upload = response.data, let signedURL = URL(string: upload.signedUrl) else {
            throw APIError.serverError(response.error ?? "Could not create source asset")
        }

        var request = URLRequest(url: signedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, uploadResponse) = try await session.upload(for: request, from: data)
        guard let http = uploadResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError("Source asset upload failed")
        }
        let _: GenericResponse = try await post(
            path: "/integrations/assets/\(upload.assetId)/complete",
            body: ["sha256": digest]
        )
    }

    func fetchIntegrations() async throws -> [BackendIntegrationCatalogItem] {
        let response: IntegrationsResponse = try await get(path: "/integrations")
        guard response.success else {
            throw APIError.serverError(response.error ?? "Could not load integrations")
        }
        return response.data ?? []
    }

    func syncIntegration(connectionId: String) async throws {
        let _: GenericResponse = try await post(
            path: "/integrations/connections/\(connectionId)/sync",
            body: [:]
        )
    }

    func disconnectIntegration(connectionId: String) async throws {
        let _: GenericResponse = try await delete(path: "/integrations/connections/\(connectionId)")
    }

    func deleteIntegrationData(connectionId: String) async throws {
        let _: GenericResponse = try await delete(path: "/integrations/connections/\(connectionId)/data")
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

    /// Run the FULL intelligence pipeline (ingestion agent + Cook 0) on the onboarding
    /// answers and return the synthesized, evidence-grounded goals. This is the deep path
    /// used by the onboarding goals page (vs the shallow extractAndSaveGoals).
    /// Note: this triggers the agent pipeline server-side and can take ~20-40s; the
    /// session timeout (480s) comfortably covers it.
    func synthesizeGoals(text: String) async throws -> GoalExtractionResponse {
        let response: GoalExtractionAPIResponse = try await post(
            path: "/goals/synthesize",
            body: ["text": text]
        )
        guard response.success, let data = response.data else {
            throw APIError.serverError(response.error ?? "Goal synthesis failed")
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

    private func delete<T: Decodable>(path: String) async throws -> T {
        return try await request(method: "DELETE", path: path, body: nil)
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

        // Apple identity tokens cannot be refreshed from a stored subject ID.
        if response.statusCode == 401 && authenticated {
            signOut()
            throw APIError.authFailed("Please sign in with Apple again")
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

private struct OAuthStartResponse: Codable {
    let success: Bool
    let data: OAuthStartData?
    let error: String?

    struct OAuthStartData: Codable {
        let authorizationUrl: String
    }
}

private struct ImportStartResponse: Codable {
    let success: Bool
    let data: ImportStartData?
    let error: String?

    struct ImportStartData: Codable {
        let importId: String
        let storagePath: String
        let uploadToken: String
        let signedUrl: String
    }
}

private struct AssetStartResponse: Codable {
    let success: Bool
    let data: AssetStartData?
    let error: String?

    struct AssetStartData: Codable {
        let assetId: String
        let signedUrl: String
        let uploadToken: String
    }
}

private struct IntegrationsResponse: Codable {
    let success: Bool
    let data: [BackendIntegrationCatalogItem]?
    let error: String?
}

struct BackendIntegrationCatalogItem: Codable, Identifiable {
    let id: String
    let displayName: String
    let collectionMode: String
    let availability: String
    let intelligenceDomains: [String]
    let connection: BackendIntegrationConnection?
}

struct BackendIntegrationConnection: Codable {
    let id: String
    let providerId: String
    let collectionMode: String
    let status: String
    let providerAccountLabel: String?
    let connectedAt: String?
    let lastVerifiedAt: String?
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
