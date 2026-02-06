import Foundation
import UIKit

// MARK: - AI Provider Selection
// Change this to switch between Claude and OpenAI

enum AIProvider: String {
    case claude = "claude"
    case openAI = "openai"

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openAI: return "OpenAI GPT-4"
        }
    }
}

// MARK: - Unified Error Type

enum AIServiceError: Error {
    case networkError
    case parseError
    case apiError(String)
    case invalidKey

    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .parseError:
            return "Failed to parse response"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidKey:
            return "Invalid API key"
        }
    }
}

// MARK: - AI Service Manager

class AIServiceManager {
    static let shared = AIServiceManager()

    // ============================================
    // CHANGE THIS LINE TO SWITCH AI PROVIDERS
    // ============================================
    static let activeProvider: AIProvider = .claude
    // ============================================

    private init() {}

    // MARK: - Transcript Generation

    func generateTranscript(
        text: String,
        goals: [String],
        generationType: GenerationType,
        completion: @escaping (Result<String, AIServiceError>) -> Void
    ) {
        print("🤖 Using AI Provider: \(Self.activeProvider.displayName)")

        switch Self.activeProvider {
        case .claude:
            ClaudeService.shared.generateTranscript(text: text, goals: goals, generationType: generationType) { result in
                switch result {
                case .success(let transcript):
                    completion(.success(transcript))
                case .failure(let error):
                    completion(.failure(self.convertClaudeError(error)))
                }
            }

        case .openAI:
            OpenAIService.shared.generateTranscript(text: text, goals: goals, generationType: generationType) { result in
                switch result {
                case .success(let transcript):
                    completion(.success(transcript))
                case .failure(let error):
                    completion(.failure(self.convertOpenAIError(error)))
                }
            }
        }
    }

    // MARK: - API Key Validation

    func validateAPIKey(completion: @escaping (Result<Bool, AIServiceError>) -> Void) {
        switch Self.activeProvider {
        case .claude:
            ClaudeService.shared.validateAPIKey { result in
                switch result {
                case .success(let valid):
                    completion(.success(valid))
                case .failure(let error):
                    completion(.failure(self.convertClaudeError(error)))
                }
            }

        case .openAI:
            OpenAIService.shared.validateAPIKey { result in
                switch result {
                case .success(let valid):
                    completion(.success(valid))
                case .failure(let error):
                    completion(.failure(self.convertOpenAIError(error)))
                }
            }
        }
    }

    // MARK: - Metadata Generation

    func analyzeEntryForMetadata(
        content: String,
        completion: @escaping (Result<(title: String, tags: [String]), AIServiceError>) -> Void
    ) {
        switch Self.activeProvider {
        case .claude:
            ClaudeService.shared.analyzeEntryForMetadata(content: content) { result in
                switch result {
                case .success(let metadata):
                    completion(.success((title: metadata.title, tags: metadata.tags)))
                case .failure(let error):
                    completion(.failure(self.convertClaudeError(error)))
                }
            }

        case .openAI:
            OpenAIService.shared.analyzeEntryForMetadata(content: content) { result in
                switch result {
                case .success(let metadata):
                    completion(.success((title: metadata.title, tags: metadata.tags)))
                case .failure(let error):
                    completion(.failure(self.convertOpenAIError(error)))
                }
            }
        }
    }

    // MARK: - Image Analysis

    func analyzeImages(
        _ images: [UIImage],
        completion: @escaping (Result<(descriptions: [String], combinedContext: String), AIServiceError>) -> Void
    ) {
        switch Self.activeProvider {
        case .claude:
            ClaudeService.shared.analyzeImages(images) { result in
                switch result {
                case .success(let analysis):
                    completion(.success((descriptions: analysis.descriptions, combinedContext: analysis.combinedContext)))
                case .failure(let error):
                    completion(.failure(self.convertClaudeError(error)))
                }
            }

        case .openAI:
            OpenAIService.shared.analyzeImages(images) { result in
                switch result {
                case .success(let analysis):
                    completion(.success((descriptions: analysis.descriptions, combinedContext: analysis.combinedContext)))
                case .failure(let error):
                    completion(.failure(self.convertOpenAIError(error)))
                }
            }
        }
    }

    // MARK: - Deep Research (OpenAI only for now)

    func generateDeepResearchTranscript(
        text: String,
        goals: [String],
        generationType: GenerationType,
        completion: @escaping (Result<DeepResearchResponse, AIServiceError>) -> Void
    ) {
        // Deep research is currently OpenAI-only (uses o3-deep-research model)
        print("⚡ Deep Research using OpenAI (specialized model)")
        OpenAIService.shared.generateDeepResearchTranscript(text: text, goals: goals, generationType: generationType) { result in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(self.convertOpenAIError(error)))
            }
        }
    }

    // MARK: - Error Conversion

    private func convertClaudeError(_ error: ClaudeError) -> AIServiceError {
        switch error {
        case .networkError:
            return .networkError
        case .parseError:
            return .parseError
        case .apiError(let message):
            return .apiError(message)
        case .invalidKey:
            return .invalidKey
        }
    }

    private func convertOpenAIError(_ error: OpenAIError) -> AIServiceError {
        switch error {
        case .networkError:
            return .networkError
        case .parseError:
            return .parseError
        case .apiError(let message):
            return .apiError(message)
        case .invalidKey:
            return .invalidKey
        case .deepResearchTimeout:
            return .apiError("Deep research timeout")
        case .deepResearchFailed:
            return .apiError("Deep research failed")
        }
    }
}
