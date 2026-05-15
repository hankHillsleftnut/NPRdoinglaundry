import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

// MARK: - Error Types
enum GoogleDocsError: Error {
    case authenticationFailed
    case fetchFailed
    case documentNotFound
    case syncFailed
    case notConnected
    
    var localizedDescription: String {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Google"
        case .fetchFailed:
            return "Failed to fetch documents from Google Drive"
        case .documentNotFound:
            return "Document not found"
        case .syncFailed:
            return "Failed to sync documents"
        case .notConnected:
            return "Not connected to Google account"
        }
    }
}

// MARK: - GoogleDocsService
class GoogleDocsService: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var documents: [GoogleDocsModel] = []
    @Published var selectedDocuments: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var lastFetchTime: Date?
    @Published var errorMessage: String?
    
    // MARK: - App Storage for Persistence
    @AppStorage("googleDocsEnabled") var isGoogleDocsEnabled: Bool = false
    @AppStorage("googleAuthCompleted") private var googleAuthCompleted: Bool = false
    @AppStorage("lastSuccessfulAuth") private var lastSuccessfulAuthTimestamp: Double = 0
    
    // MARK: - Private Properties
    private let scopes = [
        "https://www.googleapis.com/auth/drive.readonly",
        "https://www.googleapis.com/auth/documents.readonly"
    ]
    private let drivePageSize = 100
    
    // MARK: - Shared Instance
    static let shared = GoogleDocsService()
    
    // MARK: - Initialization
    init() {
        setupGoogleSignIn()
        
        // Restore authentication state on app launch
        Task {
            await restoreAuthenticationState()
        }
    }
    
    // MARK: - Setup and Configuration
    private func setupGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty,
              clientID != "YOUR_GOOGLE_CLIENT_ID_HERE" else {
            print("⚠️ Google Client ID not configured")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        print("✅ Google Sign-In configured with client ID: \(clientID.prefix(20))...")
    }
    
    // MARK: - Enhanced Authentication State Restoration
    private func restoreAuthenticationState() async {
        print("🔄 Restoring authentication state...")
        print("📱 Previous auth completed: \(googleAuthCompleted)")
        print("📱 Google Docs enabled: \(isGoogleDocsEnabled)")
        print("📱 Has previous sign-in: \(GIDSignIn.sharedInstance.hasPreviousSignIn())")
        
        guard GIDSignIn.sharedInstance.configuration != nil else {
            print("⚠️ Google Sign-In not configured, skipping restoration")
            return
        }
        
        // Only attempt restoration if we previously had a successful auth
        guard googleAuthCompleted && GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            print("📱 No previous successful authentication to restore")
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            
            // Verify we have a valid access token
            guard !result.accessToken.tokenString.isEmpty else {
                print("⚠️ Restored sign-in but access token is empty")
                await handleAuthenticationFailure()
                return
            }
            
            await MainActor.run {
                self.isConnected = true
                self.errorMessage = nil
            }
            
            print("✅ Successfully restored Google authentication")
            print("🔑 Access token: \(result.accessToken.tokenString.prefix(20))...")
            
            // Auto-fetch documents if Google Docs is enabled
            if isGoogleDocsEnabled {
                print("🔄 Auto-fetching documents after authentication restoration")
                try? await fetchLastTwoWeeksDocuments()
            }
            
        } catch {
            print("❌ Failed to restore previous sign-in: \(error)")
            await handleAuthenticationFailure()
        }
    }
    
    // MARK: - Enhanced Authentication
    func authenticate() async throws {
        guard GIDSignIn.sharedInstance.configuration != nil else {
            throw GoogleDocsError.authenticationFailed
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GoogleDocsError.authenticationFailed
        }
        
        print("🔐 Starting Google authentication...")
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            )
            
            // Verify we received a valid access token
            guard !result.user.accessToken.tokenString.isEmpty else {
                print("❌ Authentication succeeded but access token is empty")
                throw GoogleDocsError.authenticationFailed
            }
            
            await MainActor.run {
                self.isConnected = true
                self.errorMessage = nil
                
                // Persist successful authentication state
                self.googleAuthCompleted = true
                self.lastSuccessfulAuthTimestamp = Date().timeIntervalSince1970
                self.isGoogleDocsEnabled = true
            }
            
            print("✅ Google authentication successful")
            print("🔑 Access token: \(result.user.accessToken.tokenString.prefix(20))...")
            print("💾 Authentication state persisted")
            
            // Auto-fetch documents after successful authentication
            print("🔄 Auto-fetching documents after authentication")
            try? await fetchLastTwoWeeksDocuments()
            
        } catch {
            print("❌ Google authentication failed: \(error)")
            await handleAuthenticationFailure()
            throw GoogleDocsError.authenticationFailed
        }
    }
    
    // MARK: - Authentication Failure Handling
    private func handleAuthenticationFailure() async {
        await MainActor.run {
            self.isConnected = false
            self.googleAuthCompleted = false
            self.isGoogleDocsEnabled = false
            self.documents = []
            self.selectedDocuments = []
            self.lastFetchTime = nil
        }
    }
    
    // MARK: - Enhanced Sign Out
    func signOut() {
        print("🚪 Signing out of Google account...")
        
        GIDSignIn.sharedInstance.signOut()
        
        // Clear all persistent state
        DispatchQueue.main.async {
            self.isConnected = false
            self.documents = []
            self.selectedDocuments = []
            self.lastFetchTime = nil
            self.errorMessage = nil
            self.isGoogleDocsEnabled = false
            self.googleAuthCompleted = false
            self.lastSuccessfulAuthTimestamp = 0
        }
        
        print("✅ Successfully signed out and cleared all state")
    }
    
    // MARK: - Token Refresh and Validation
    private func ensureValidToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No current user available")
            throw GoogleDocsError.authenticationFailed
        }
        
        // Check if token needs refresh (refresh if expires within 5 minutes)
        let expirationDate = user.accessToken.expirationDate
        let shouldRefresh = expirationDate?.timeIntervalSinceNow ?? 0 < 300 // 5 minutes
        
        if shouldRefresh {
            print("🔄 Access token expires soon, refreshing...")
            do {
                let refreshedUser = try await user.refreshTokensIfNeeded()
                print("✅ Token refreshed successfully")
                return refreshedUser.accessToken.tokenString
            } catch {
                print("❌ Token refresh failed: \(error)")
                await handleAuthenticationFailure()
                throw GoogleDocsError.authenticationFailed
            }
        }
        
        return user.accessToken.tokenString
    }
    
    // MARK: - Enhanced Document Fetching with Token Management
    func fetchLastTwoWeeksDocuments() async throws -> [GoogleDocsModel] {
        print("🚀 Starting document fetch with enhanced token management")
        
        guard isConnected else {
            print("❌ Not connected")
            throw GoogleDocsError.notConnected
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Ensure we have a valid, fresh token
            let accessToken = try await ensureValidToken()
            print("✅ Have valid access token: \(accessToken.prefix(20))...")
            
            print("🔄 Making direct REST API call...")
            let documents = try await fetchDocumentsViaRESTAPI(accessToken: accessToken)
            
            await MainActor.run {
                self.documents = documents
                self.lastFetchTime = Date()
                self.isLoading = false
            }
            
            print("✅ Successfully fetched \(documents.count) documents via REST API")
            return documents
            
        } catch {
            print("❌ Document fetch failed: \(error)")
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            
            // If authentication failed, clear auth state
            if case GoogleDocsError.authenticationFailed = error {
                await handleAuthenticationFailure()
            }
            
            throw error
        }
    }
    
    // MARK: - Direct REST API Implementation
    private func fetchDocumentsViaRESTAPI(accessToken: String, modifiedSince: Date? = nil) async throws -> [GoogleDocsModel] {
        print(" Building REST API request...")
        
        // Create URL for Google Drive API
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        var query = "mimeType='application/vnd.google-apps.document'"
        if let modifiedSince = modifiedSince {
            query += " and modifiedTime > '\(ISO8601DateFormatter().string(from: modifiedSince))'"
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,createdTime,modifiedTime)"),
            URLQueryItem(name: "pageSize", value: "\(drivePageSize)"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc")
        ]
        
        guard let url = components.url else {
            print(" Failed to create URL")
            throw GoogleDocsError.fetchFailed
        }
        
        print(" URL: \(url)")
        
        // Create request with authorization header
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print(" Making URLSession request...")
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print(" Invalid response type")
            throw GoogleDocsError.fetchFailed
        }
        
        print(" HTTP Response Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print(" API Error (\(httpResponse.statusCode)): \(errorString)")
            throw GoogleDocsError.fetchFailed
        }
        
        print(" Got successful HTTP response")
        
        // Parse JSON response manually to avoid casting issues
        return try parseJSONResponse(data)
    }

    func fetchDocumentsModifiedWithin(days: Int) async throws -> [GoogleDocsModel] {
        guard isConnected else {
            throw GoogleDocsError.notConnected
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let accessToken = try await ensureValidToken()
        let documents = try await fetchDocumentsViaRESTAPI(accessToken: accessToken, modifiedSince: startDate)

        await MainActor.run {
            self.documents = documents
            self.lastFetchTime = Date()
        }

        return documents
    }
    
    private func parseJSONResponse(_ data: Data) throws -> [GoogleDocsModel] {
        print(" Parsing JSON response manually...")
        
        let jsonString = String(data: data, encoding: .utf8) ?? "Unable to convert to string"
        print(" Raw JSON: \(jsonString)")
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print(" Failed to parse JSON")
            throw GoogleDocsError.fetchFailed
        }
        
        print(" Parsed top-level JSON object")
        
        guard let filesArray = json["files"] as? [[String: Any]] else {
            print(" No files array found in response")
            return []
        }
        
        print(" Found \(filesArray.count) files in response")
        
        var documents: [GoogleDocsModel] = []
        
        for (index, fileDict) in filesArray.enumerated() {
            print(" Processing file \(index + 1):")
            print("   Raw file data: \(fileDict)")
            
            // Extract values with extreme safety
            guard let id = extractStringFromJSON(fileDict["id"], fieldName: "id"),
                  let name = extractStringFromJSON(fileDict["name"], fieldName: "name") else {
                print(" Skipping file \(index + 1) - missing required fields")
                continue
            }
            
            let mimeType = extractStringFromJSON(fileDict["mimeType"], fieldName: "mimeType") ?? "application/vnd.google-apps.document"
            
            // Handle dates safely
            let createdTime = parseDateFromJSON(fileDict["createdTime"]) ?? Date()
            let modifiedTime = parseDateFromJSON(fileDict["modifiedTime"]) ?? Date()
            
            let document = GoogleDocsModel(
                id: id,
                name: name,
                mimeType: mimeType,
                createdTime: createdTime,
                modifiedTime: modifiedTime,
                content: "Loading content...", 
                comments: nil,
                revisions: nil
            )
            
            documents.append(document)
            print(" Successfully created document: \(name)")
        }
        
        print(" Finished parsing, created \(documents.count) documents")
        return documents
    }
    
    private func extractStringFromJSON(_ value: Any?, fieldName: String) -> String? {
        print(" Extracting \(fieldName) from: \(String(describing: value)) (type: \(type(of: value)))")
        
        guard let value = value else {
            print(" \(fieldName) is nil")
            return nil
        }
        
        if let stringValue = value as? String {
            print(" \(fieldName) extracted as String: \(stringValue)")
            return stringValue
        }
        
        if let numberValue = value as? NSNumber {
            let stringValue = numberValue.stringValue
            print(" \(fieldName) converted from NSNumber: \(stringValue)")
            return stringValue
        }
        
        if let intValue = value as? Int {
            let stringValue = String(intValue)
            print(" \(fieldName) converted from Int: \(stringValue)")
            return stringValue
        }
        
        if let doubleValue = value as? Double {
            let stringValue = String(doubleValue)
            print(" \(fieldName) converted from Double: \(stringValue)")
            return stringValue
        }
        
        let stringValue = String(describing: value)
        print(" \(fieldName) converted using description: \(stringValue)")
        return stringValue
    }
    
    private func parseDateFromJSON(_ value: Any?) -> Date? {
        guard let dateString = extractStringFromJSON(value, fieldName: "date") else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    // MARK: - Enhanced Content Fetching with Token Management
    func fetchContentForDocument(_ documentId: String) async throws -> String {
        print("📄 fetchContentForDocument called for: \(documentId)")
        
        do {
            // Ensure we have a valid, fresh token
            let accessToken = try await ensureValidToken()
            print("✅ Have valid access token for content fetch: \(accessToken.prefix(20))...")
            
            // Try the export API
            let urlString = "https://www.googleapis.com/drive/v3/files/\(documentId)/export?mimeType=text/plain"
            print("🔗 Export URL: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                throw GoogleDocsError.fetchFailed
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            print("🔄 Making export request...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                throw GoogleDocsError.fetchFailed
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let content = String(data: data, encoding: .utf8) ?? "Could not decode content"
                print("✅ Successfully exported content: \(content.count) characters")
                return content
            } else if httpResponse.statusCode == 401 {
                // Token expired, handle authentication failure
                print("🔒 Authentication failed, clearing auth state")
                await handleAuthenticationFailure()
                throw GoogleDocsError.authenticationFailed
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Export failed (\(httpResponse.statusCode)): \(errorData)")
                throw GoogleDocsError.fetchFailed
            }
        } catch {
            print("❌ Content fetch error: \(error)")
            
            // If authentication failed, clear auth state
            if case GoogleDocsError.authenticationFailed = error {
                await handleAuthenticationFailure()
            }
            
            throw error
        }
    }
    
    func updateDocumentContent(_ documentId: String, content: String) {
        if let index = documents.firstIndex(where: { $0.id == documentId }) {
            documents[index] = GoogleDocsModel(
                id: documents[index].id,
                name: documents[index].name,
                mimeType: documents[index].mimeType,
                createdTime: documents[index].createdTime,
                modifiedTime: documents[index].modifiedTime,
                content: content,
                comments: documents[index].comments,
                revisions: documents[index].revisions
            )
            print(" Updated content for document: \(documents[index].name)")
        }
    }
    
    // MARK: - Legacy Methods
    func fetchLastWeekDocuments() async throws -> [GoogleDocsModel] {
        return try await fetchLastTwoWeeksDocuments()
    }
    
    func fetchContentsForDocuments(_ docs: [GoogleDocsModel]) async throws -> [(String, String)] {
        return docs.map { ($0.name, "Content fetching simplified in this version") }
    }
    
    // MARK: - Enhanced Integration Management
    func toggleGoogleDocsIntegration(_ enabled: Bool) {
        print("🔄 Toggling Google Docs integration: \(enabled)")
        isGoogleDocsEnabled = enabled
        
        // If enabling and we're connected, auto-fetch documents
        if enabled && isConnected {
            Task {
                try? await fetchLastTwoWeeksDocuments()
            }
        }
    }
    
    // MARK: - Authentication Status Check
    func checkAuthenticationStatus() async {
        print("🔍 Checking current authentication status...")
        
        guard GIDSignIn.sharedInstance.configuration != nil else {
            print("⚠️ Google Sign-In not configured")
            return
        }
        
        if googleAuthCompleted && GIDSignIn.sharedInstance.hasPreviousSignIn() {
            print("📱 Previous authentication found, attempting restore...")
            await restoreAuthenticationState()
        } else {
            print("📱 No previous authentication found")
            await MainActor.run {
                self.isConnected = false
            }
        }
    }
    
    // MARK: - Force Reauthentication
    func forceReauthentication() async throws {
        print("🔄 Force reauthentication requested")
        signOut()
        try await authenticate()
    }
}
