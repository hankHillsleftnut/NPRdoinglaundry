import Foundation

@MainActor
final class FirstPodcastOrchestrator: ObservableObject {
    static let shared = FirstPodcastOrchestrator()

    @Published private(set) var status: String = ""

    /// The one first episode, shared by everything in onboarding that wants it.
    /// The questions screen used to generate one and the finale a second, from
    /// scratch: two full episodes (~$4) per onboarding and a 3-5 minute wait at
    /// a fake 94% (19 October 2026). Now whoever asks first starts it; everyone
    /// else waits on the same request or reuses the finished episode.
    private var firstEpisodeTask: Task<PodcastEpisode, Error>?

    func firstEpisode() async throws -> PodcastEpisode {
        if let task = firstEpisodeTask { return try await task.value }
        let task = Task { [apiClient] in
            try await apiClient.generatePodcast(daysSince: 14, generationSource: .onboardingFirstEpisode)
        }
        firstEpisodeTask = task
        do {
            return try await task.value
        } catch {
            // A failed attempt shouldn't stop a later retry.
            firstEpisodeTask = nil
            throw error
        }
    }

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
        // Reuses the episode the questions screen already started, if any.
        let episode = try await firstEpisode()

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
