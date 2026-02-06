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
    
    static func == (lhs: GoogleDocsModel, rhs: GoogleDocsModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.mimeType == rhs.mimeType &&
               lhs.createdTime == rhs.createdTime &&
               lhs.modifiedTime == rhs.modifiedTime &&
               lhs.content == rhs.content &&
               lhs.comments == rhs.comments &&
               lhs.revisions == rhs.revisions
    }
}

struct GoogleDocComment: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let author: String
    let createdTime: Date
    let resolved: Bool
    
    static func == (lhs: GoogleDocComment, rhs: GoogleDocComment) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.author == rhs.author &&
               lhs.createdTime == rhs.createdTime &&
               lhs.resolved == rhs.resolved
    }
}

struct GoogleDocRevision: Identifiable, Codable, Equatable {
    let id: String
    let modifiedTime: Date
    let lastModifyingUser: String
    let originalFilename: String?
    
    static func == (lhs: GoogleDocRevision, rhs: GoogleDocRevision) -> Bool {
        return lhs.id == rhs.id &&
               lhs.modifiedTime == rhs.modifiedTime &&
               lhs.lastModifyingUser == rhs.lastModifyingUser &&
               lhs.originalFilename == rhs.originalFilename
    }
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
