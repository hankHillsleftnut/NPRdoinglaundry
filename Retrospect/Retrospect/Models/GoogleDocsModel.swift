import Foundation

struct GoogleDocsModel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let mimeType: String
    let createdTime: Date
    let modifiedTime: Date
    var content: String?
    var comments: [GoogleDocComment]?
    var revisions: [GoogleDocRevision]?

    var isDocument: Bool {
        return mimeType == "application/vnd.google-apps.document"
    }
}

struct GoogleDocComment: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let author: String
    let createdTime: Date
    let resolved: Bool
}

struct GoogleDocRevision: Identifiable, Codable, Equatable {
    let id: String
    let modifiedTime: Date
    let lastModifyingUser: String
    let originalFilename: String?
}

// MARK: - Enhanced Data Model for UI

class GoogleDocsDataModel: ObservableObject {
    @Published var documents: [GoogleDocsModel] = []
    @Published var isLoading: Bool = false
    @Published var lastFetchTime: Date?
    @Published var errorMessage: String?

    func updateDocuments(_ newDocuments: [GoogleDocsModel]) {
        DispatchQueue.main.async {
            self.documents = newDocuments
            self.lastFetchTime = Date()
            self.isLoading = false
        }
    }

    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }

    func setError(_ error: String?) {
        DispatchQueue.main.async {
            self.errorMessage = error
            self.isLoading = false
        }
    }
}
