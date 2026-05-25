import Foundation

@MainActor
final class FirstPodcastOrchestrator: ObservableObject {
    static let shared = FirstPodcastOrchestrator()

    @Published private(set) var status: String = ""

    private let contextManager: OnboardingContextManager
    private let apiClient: RetrospectAPIClient

    private init() {
        self.contextManager = .shared
        self.apiClient = .shared
    }

    func runAfterOnboarding(extractedGoals: [RichGoal]) async throws -> TranscriptModel {
        status = "Building your onboarding profile..."
        let context = contextManager.finalizeContext(extractedGoals: extractedGoals)

        if !extractedGoals.isEmpty {
            status = "Saving your goals..."
            GoalsManager.shared.addRichGoals(extractedGoals)
        }

        guard apiClient.isAuthenticated else {
            throw FirstPodcastError.backendAuthenticationRequired
        }

        status = "Sending your onboarding profile to the podcast agent..."
        try await contextManager.uploadContextForFirstPodcastIfPossible(context)

        status = "Creating your first Retrospect podcast..."
        let episode = try await apiClient.generatePodcast(
            daysSince: 14,
            generationSource: .onboardingFirstEpisode
        )

        let transcript = episode.toTranscriptModel()
        let persistenceViewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
        persistenceViewModel.savePodcast(transcript)

        contextManager.markFirstPodcastGenerated()
        status = "Your first podcast is ready."
        return transcript
    }
}

enum FirstPodcastError: LocalizedError {
    case backendAuthenticationRequired

    var errorDescription: String? {
        switch self {
        case .backendAuthenticationRequired:
            return "Sign in is required before the first podcast agent can run."
        }
    }
}
