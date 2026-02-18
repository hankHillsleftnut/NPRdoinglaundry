import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import UIKit

enum XBookmarksError: LocalizedError {
    case missingConfiguration
    case invalidRedirectURI
    case authorizationCancelled
    case authorizationFailed
    case missingAuthorizationCode
    case invalidState
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case notConnected
    case apiFailed(String)
    case backendAuthenticationRequired

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "X OAuth is not configured. Add XClientID in Info.plist."
        case .invalidRedirectURI:
            return "X OAuth redirect URI is invalid."
        case .authorizationCancelled:
            return "Authorization was cancelled."
        case .authorizationFailed:
            return "Failed to authorize with X."
        case .missingAuthorizationCode:
            return "X did not return an authorization code."
        case .invalidState:
            return "Authorization state validation failed."
        case .tokenExchangeFailed(let message):
            return "Failed to exchange token: \(message)"
        case .tokenRefreshFailed(let message):
            return "Failed to refresh token: \(message)"
        case .notConnected:
            return "Not connected to X."
        case .apiFailed(let message):
            return "X API request failed: \(message)"
        case .backendAuthenticationRequired:
            return "Please sign in to Retrospect before syncing bookmarks."
        }
    }
}

struct XBookmark: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let authorName: String?
    let authorUsername: String?
    let createdAt: Date?
    let url: URL?
}

@MainActor
final class XBookmarksService: NSObject, ObservableObject {
    static let shared = XBookmarksService()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var bookmarks: [XBookmark] = []
    @Published var errorMessage: String?
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var lastSyncDate: Date?

    @AppStorage("xBookmarksEnabled") private(set) var isXBookmarksEnabled: Bool = false
    @AppStorage("xBookmarksAuthCompleted") private var xBookmarksAuthCompleted: Bool = false
    @AppStorage("xBookmarksUserId") private var xBookmarksUserId: String = ""
    @AppStorage("xBookmarksLastPayloadHash") private var xBookmarksLastPayloadHash: String = ""
    @AppStorage("xBookmarksLastSyncTimestamp") private var xBookmarksLastSyncTimestamp: Double = 0

    private let keychainService = "com.retrospect.xbookmarks"
    private let accessTokenKey = "x_access_token"
    private let refreshTokenKey = "x_refresh_token"
    private let tokenExpiryKey = "x_token_expiry"

    private let tokenRefreshSkew: TimeInterval = 5 * 60
    private let foregroundRefreshInterval: TimeInterval = 6 * 60 * 60
    private let defaultFetchLimit = 75

    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        if xBookmarksLastSyncTimestamp > 0 {
            lastSyncDate = Date(timeIntervalSince1970: xBookmarksLastSyncTimestamp)
        }
        Task {
            await checkAuthenticationStatus()
        }
    }

    // MARK: - Public API

    func connectAndInitialSync() async throws -> Int {
        try await authenticate()
        let fetched = try await fetchBookmarks(limit: defaultFetchLimit)
        try await syncLatestBookmarksToBackend(force: true)
        return fetched.count
    }

    func authenticate() async throws {
        guard let clientId = xClientId else {
            throw XBookmarksError.missingConfiguration
        }
        guard let callbackScheme = callbackURLScheme else {
            throw XBookmarksError.invalidRedirectURI
        }

        let verifier = randomString(length: 64)
        let challenge = codeChallenge(from: verifier)
        let state = randomString(length: 32)

        var components = URLComponents(string: "https://twitter.com/i/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "tweet.read users.read bookmark.read offline.access"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components?.url else {
            throw XBookmarksError.authorizationFailed
        }

        let callbackURL = try await beginWebAuthentication(
            authURL: authURL,
            callbackScheme: callbackScheme
        )

        guard let callbackState = callbackURL.queryValue(named: "state"),
              callbackState == state else {
            throw XBookmarksError.invalidState
        }
        guard let code = callbackURL.queryValue(named: "code"), !code.isEmpty else {
            throw XBookmarksError.missingAuthorizationCode
        }

        let tokenResponse = try await exchangeAuthorizationCode(
            code: code,
            codeVerifier: verifier
        )

        saveTokens(from: tokenResponse)

        let userId = try await fetchCurrentUserId(accessToken: tokenResponse.accessToken)
        xBookmarksUserId = userId
        xBookmarksAuthCompleted = true
        isXBookmarksEnabled = true
        isConnected = true
        errorMessage = nil
    }

    func signOut() {
        deleteKeychain(key: accessTokenKey)
        deleteKeychain(key: refreshTokenKey)
        deleteKeychain(key: tokenExpiryKey)

        xBookmarksAuthCompleted = false
        xBookmarksUserId = ""
        xBookmarksLastPayloadHash = ""
        isXBookmarksEnabled = false

        isConnected = false
        bookmarks = []
        errorMessage = nil
        lastFetchDate = nil
        lastSyncDate = nil
        xBookmarksLastSyncTimestamp = 0
    }

    func checkAuthenticationStatus() async {
        guard xBookmarksAuthCompleted, readKeychain(key: accessTokenKey) != nil else {
            isConnected = false
            return
        }

        do {
            _ = try await validAccessToken()
            isConnected = true
        } catch {
            signOut()
        }
    }

    func fetchBookmarks(limit: Int = 50) async throws -> [XBookmark] {
        guard isConnected else {
            throw XBookmarksError.notConnected
        }

        let cappedLimit = max(1, min(300, limit))
        isLoading = true
        defer { isLoading = false }

        let accessToken = try await validAccessToken()
        let userId = try await ensureUserId(accessToken: accessToken)

        var all: [XBookmark] = []
        var nextToken: String?

        repeat {
            let remaining = cappedLimit - all.count
            if remaining <= 0 { break }

            let page = try await fetchBookmarksPage(
                accessToken: accessToken,
                userId: userId,
                maxResults: min(100, remaining),
                nextToken: nextToken
            )
            all.append(contentsOf: page.bookmarks)
            nextToken = page.nextToken
        } while nextToken != nil && all.count < cappedLimit

        let deduped = dedupeBookmarks(all)
        bookmarks = deduped
        lastFetchDate = Date()
        errorMessage = nil
        return deduped
    }

    func syncLatestBookmarksToBackend(force: Bool = false) async throws {
        guard RetrospectAPIClient.shared.isAuthenticated else {
            throw XBookmarksError.backendAuthenticationRequired
        }
        guard !bookmarks.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        let payload = buildBackendPayload(bookmarks: bookmarks)
        let payloadHash = sha256Hex(payload)
        if !force && payloadHash == xBookmarksLastPayloadHash {
            return
        }

        try await RetrospectAPIClient.shared.uploadContent(
            contentType: "x/twitter",
            content: payload,
            contentDate: Date()
        )

        xBookmarksLastPayloadHash = payloadHash
        lastSyncDate = Date()
        xBookmarksLastSyncTimestamp = lastSyncDate?.timeIntervalSince1970 ?? 0
    }

    func refreshIfNeeded() {
        guard isConnected, isXBookmarksEnabled else { return }
        if isLoading || isSyncing { return }

        if let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < foregroundRefreshInterval {
            return
        }

        Task {
            do {
                _ = try await fetchBookmarks(limit: defaultFetchLimit)
                try await syncLatestBookmarksToBackend(force: false)
            } catch {
                errorMessage = error.localizedDescription
                print("❌ X bookmarks refresh failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - OAuth

    private func beginWebAuthentication(
        authURL: URL,
        callbackScheme: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let nsError = error as NSError? {
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain &&
                        nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: XBookmarksError.authorizationCancelled)
                        return
                    }
                    continuation.resume(throwing: XBookmarksError.authorizationFailed)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: XBookmarksError.authorizationFailed)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session

            if !session.start() {
                authSession = nil
                continuation.resume(throwing: XBookmarksError.authorizationFailed)
            }
        }
    }

    private func exchangeAuthorizationCode(
        code: String,
        codeVerifier: String
    ) async throws -> OAuthTokenResponse {
        guard let clientId = xClientId else {
            throw XBookmarksError.missingConfiguration
        }
        guard let url = URL(string: "https://api.twitter.com/2/oauth2/token") else {
            throw XBookmarksError.authorizationFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", clientId),
            ("redirect_uri", redirectURI),
            ("code_verifier", codeVerifier),
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XBookmarksError.tokenExchangeFailed("Invalid response")
        }

        if !(200...299).contains(http.statusCode) {
            let apiError = decodeOAuthError(from: data)
            throw XBookmarksError.tokenExchangeFailed(apiError)
        }

        do {
            return try JSONDecoder.xDecoder.decode(OAuthTokenResponse.self, from: data)
        } catch {
            throw XBookmarksError.tokenExchangeFailed("Could not decode token response")
        }
    }

    private func refreshAccessToken(refreshToken: String) async throws -> OAuthTokenResponse {
        guard let clientId = xClientId else {
            throw XBookmarksError.missingConfiguration
        }
        guard let url = URL(string: "https://api.twitter.com/2/oauth2/token") else {
            throw XBookmarksError.authorizationFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", clientId),
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XBookmarksError.tokenRefreshFailed("Invalid response")
        }

        if !(200...299).contains(http.statusCode) {
            let apiError = decodeOAuthError(from: data)
            throw XBookmarksError.tokenRefreshFailed(apiError)
        }

        do {
            return try JSONDecoder.xDecoder.decode(OAuthTokenResponse.self, from: data)
        } catch {
            throw XBookmarksError.tokenRefreshFailed("Could not decode refresh response")
        }
    }

    private func validAccessToken() async throws -> String {
        guard let token = readKeychain(key: accessTokenKey) else {
            throw XBookmarksError.notConnected
        }

        let expiry = readKeychain(key: tokenExpiryKey)
            .flatMap(TimeInterval.init)
            .map { Date(timeIntervalSince1970: $0) }

        if let expiry, expiry.timeIntervalSinceNow > tokenRefreshSkew {
            return token
        }

        guard let refreshToken = readKeychain(key: refreshTokenKey), !refreshToken.isEmpty else {
            // If we do not know expiry yet, optimistically use current token.
            if expiry == nil {
                return token
            }
            throw XBookmarksError.notConnected
        }

        let refreshed = try await refreshAccessToken(refreshToken: refreshToken)
        saveTokens(from: refreshed)
        return refreshed.accessToken
    }

    // MARK: - X API

    private func ensureUserId(accessToken: String) async throws -> String {
        if !xBookmarksUserId.isEmpty {
            return xBookmarksUserId
        }
        let userId = try await fetchCurrentUserId(accessToken: accessToken)
        xBookmarksUserId = userId
        return userId
    }

    private func fetchCurrentUserId(accessToken: String) async throws -> String {
        guard let url = URL(string: "https://api.twitter.com/2/users/me") else {
            throw XBookmarksError.apiFailed("Invalid users/me URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XBookmarksError.apiFailed("Invalid response")
        }

        if !(200...299).contains(http.statusCode) {
            throw XBookmarksError.apiFailed("users/me returned HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder.xDecoder.decode(XUserResponse.self, from: data)
        return decoded.data.id
    }

    private func fetchBookmarksPage(
        accessToken: String,
        userId: String,
        maxResults: Int,
        nextToken: String?
    ) async throws -> XBookmarksPage {
        var components = URLComponents(string: "https://api.twitter.com/2/users/\(userId)/bookmarks")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "tweet.fields", value: "author_id,created_at,text,lang"),
            URLQueryItem(name: "expansions", value: "author_id"),
            URLQueryItem(name: "user.fields", value: "id,name,username"),
        ]
        if let nextToken, !nextToken.isEmpty {
            query.append(URLQueryItem(name: "pagination_token", value: nextToken))
        }
        components?.queryItems = query

        guard let url = components?.url else {
            throw XBookmarksError.apiFailed("Invalid bookmarks URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XBookmarksError.apiFailed("Invalid response")
        }

        if !(200...299).contains(http.statusCode) {
            throw XBookmarksError.apiFailed("Bookmarks returned HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder.xDecoder.decode(XBookmarksResponse.self, from: data)
        let usersById = Dictionary(
            uniqueKeysWithValues: (decoded.includes?.users ?? []).map { ($0.id, $0) }
        )

        let mapped: [XBookmark] = (decoded.data ?? []).map { tweet in
            let author = usersById[tweet.authorId ?? ""]
            let username = author?.username
            let url: URL? = username.flatMap { URL(string: "https://x.com/\($0)/status/\(tweet.id)") }
            return XBookmark(
                id: tweet.id,
                text: tweet.text.trimmingCharacters(in: .whitespacesAndNewlines),
                authorName: author?.name,
                authorUsername: username,
                createdAt: parseISO8601Date(tweet.createdAt),
                url: url
            )
        }

        return XBookmarksPage(
            bookmarks: mapped.filter { !$0.text.isEmpty },
            nextToken: decoded.meta?.nextToken
        )
    }

    // MARK: - Data Normalization / Sync Payload

    private func dedupeBookmarks(_ list: [XBookmark]) -> [XBookmark] {
        var seen: Set<String> = []
        var deduped: [XBookmark] = []
        deduped.reserveCapacity(list.count)

        for bookmark in list where !seen.contains(bookmark.id) {
            seen.insert(bookmark.id)
            deduped.append(bookmark)
        }
        return deduped
    }

    private func buildBackendPayload(bookmarks: [XBookmark]) -> String {
        var lines: [String] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        lines.append("X/Twitter Bookmarks Snapshot")
        lines.append("Fetched at: \(formatter.string(from: Date()))")
        lines.append("Bookmark count: \(bookmarks.count)")
        lines.append("")

        for (index, bookmark) in bookmarks.enumerated() {
            lines.append("Bookmark \(index + 1):")
            if let username = bookmark.authorUsername {
                lines.append("Author: @\(username)\(bookmark.authorName.map { " (\($0))" } ?? "")")
            } else {
                lines.append("Author: unknown")
            }
            if let createdAt = bookmark.createdAt {
                lines.append("Tweet date: \(formatter.string(from: createdAt))")
            }
            if let url = bookmark.url?.absoluteString {
                lines.append("URL: \(url)")
            }
            lines.append("Text: \(bookmark.text)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private var xClientId: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "XClientID") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "YOUR_X_CLIENT_ID_HERE" {
            return nil
        }
        return trimmed
    }

    private var redirectURI: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "XRedirectURI") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "retrospect://x-auth-callback"
    }

    private var callbackURLScheme: String? {
        URL(string: redirectURI)?.scheme
    }

    private func decodeOAuthError(from data: Data) -> String {
        if let decoded = try? JSONDecoder.xDecoder.decode(XOAuthErrorResponse.self, from: data) {
            if let description = decoded.errorDescription, !description.isEmpty {
                return description
            }
            if let error = decoded.error, !error.isEmpty {
                return error
            }
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    private func formEncodedBody(_ items: [(String, String)]) -> Data? {
        let body = items
            .map { key, value in
                "\(key.urlQueryEncoded())=\(value.urlQueryEncoded())"
            }
            .joined(separator: "&")
        return body.data(using: .utf8)
    }

    private func randomString(length: Int) -> String {
        let allowed = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return String((0..<length).map { _ in allowed.randomElement() ?? "a" })
        }
        return String(bytes.map { allowed[Int($0) % allowed.count] })
    }

    private func codeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func parseISO8601Date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func saveTokens(from response: OAuthTokenResponse) {
        saveKeychain(key: accessTokenKey, value: response.accessToken)

        if let refreshToken = response.refreshToken, !refreshToken.isEmpty {
            saveKeychain(key: refreshTokenKey, value: refreshToken)
        }

        if let expiresIn = response.expiresIn {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            saveKeychain(key: tokenExpiryKey, value: String(expiry.timeIntervalSince1970))
        }
    }

    // MARK: - Keychain

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

extension XBookmarksService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
    }
}

private struct XBookmarksPage {
    let bookmarks: [XBookmark]
    let nextToken: String?
}

private struct OAuthTokenResponse: Decodable {
    let tokenType: String?
    let expiresIn: Int?
    let accessToken: String
    let scope: String?
    let refreshToken: String?
}

private struct XOAuthErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
}

private struct XUserResponse: Decodable {
    struct XUser: Decodable {
        let id: String
        let name: String?
        let username: String?
    }
    let data: XUser
}

private struct XBookmarksResponse: Decodable {
    struct Tweet: Decodable {
        let id: String
        let text: String
        let authorId: String?
        let createdAt: String?
    }

    struct Includes: Decodable {
        struct User: Decodable {
            let id: String
            let name: String?
            let username: String?
        }
        let users: [User]?
    }

    struct Meta: Decodable {
        let nextToken: String?
        let resultCount: Int?
    }

    let data: [Tweet]?
    let includes: Includes?
    let meta: Meta?
}

private extension URL {
    func queryValue(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    func urlQueryEncoded() -> String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "&", with: "%26")
            .replacingOccurrences(of: "=", with: "%3D")
            ?? self
    }
}

private extension JSONDecoder {
    static let xDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
