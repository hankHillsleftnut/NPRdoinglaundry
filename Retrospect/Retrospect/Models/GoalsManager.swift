import Foundation
import SwiftUI

// MARK: - Onboarding Podcast Context

struct OnboardingAnswer: Codable, Identifiable {
    var id: String { question }
    let question: String
    let answer: String
    let answeredAt: Date
}

struct OnboardingIntegrationsSnapshot: Codable {
    let googleDocsConnected: Bool
    let googleDocsEnabled: Bool
    let healthKitEnabled: Bool
    let screenTimeAuthorized: Bool
    let capturedAt: Date

    var promptSummary: String {
        [
            "Google Docs: \(googleDocsConnected && googleDocsEnabled ? "connected" : "not connected")",
            "Apple Health: \(healthKitEnabled ? "enabled" : "not enabled")",
            "Screen Time: \(screenTimeAuthorized ? "enabled" : "not enabled")"
        ]
        .joined(separator: "\n")
    }
}

struct OnboardingPodcastContext: Codable {
    var depthAnswers: [OnboardingAnswer]
    var extractedGoals: [RichGoal]
    var voicePersona: String
    var integrations: OnboardingIntegrationsSnapshot
    var createdAt: Date
    var completedAt: Date?

    var answeredQuestionCount: Int {
        depthAnswers.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    func promptContext(fullAnswers: Bool) -> String {
        var sections: [String] = []

        if fullAnswers {
            let answersText = depthAnswers.map { answer in
                """
                Q: \(answer.question)
                A: \(answer.answer)
                """
            }
            .joined(separator: "\n\n")

            if !answersText.isEmpty {
                sections.append("""
                Onboarding Answers:
                \(answersText)
                """)
            }
        } else {
            let stableSignals = depthAnswers.prefix(5).map { answer in
                "- \(answer.question) \(answer.answer)"
            }
            .joined(separator: "\n")

            if !stableSignals.isEmpty {
                sections.append("""
                Persistent User Context:
                \(stableSignals)
                """)
            }
        }

        if !extractedGoals.isEmpty {
            let goalsText = extractedGoals.map { goal in
                var line = "- \(goal.title)"
                if !goal.goalDescription.isEmpty {
                    line += ": \(goal.goalDescription)"
                }
                if !goal.motivation.isEmpty {
                    line += " Why it matters: \(goal.motivation)"
                }
                return line
            }
            .joined(separator: "\n")

            sections.append("""
            Goals Extracted During Onboarding:
            \(goalsText)
            """)
        }

        sections.append("""
        Preferred Podcast Voice:
        \(voicePersona)
        """)

        sections.append("""
        Connected Data Sources:
        \(integrations.promptSummary)
        """)

        return sections.joined(separator: "\n\n")
    }
}

@MainActor
final class OnboardingContextManager: ObservableObject {
    static let shared = OnboardingContextManager()

    @Published private(set) var context: OnboardingPodcastContext?

    private let defaults = UserDefaults.standard
    private nonisolated static let contextKey = "onboarding_podcast_context"
    private static let firstPodcastGeneratedKey = "onboarding_first_podcast_generated"

    private init() {
        loadContext()
    }

    var hasGeneratedFirstPodcast: Bool {
        defaults.bool(forKey: Self.firstPodcastGeneratedKey)
    }

    func markFirstPodcastGenerated() {
        defaults.set(true, forKey: Self.firstPodcastGeneratedKey)
    }

    func saveDepthAnswers(_ answers: [OnboardingAnswer]) {
        var next = context ?? makeEmptyContext()
        next.depthAnswers = answers
        next.integrations = captureIntegrationsSnapshot()
        next.voicePersona = currentVoicePersona
        save(next)
    }

    func saveExtractedGoals(_ goals: [RichGoal]) {
        var next = context ?? makeEmptyContext()
        next.extractedGoals = goals
        next.integrations = captureIntegrationsSnapshot()
        next.voicePersona = currentVoicePersona
        save(next)
    }

    func finalizeContext(extractedGoals: [RichGoal]) -> OnboardingPodcastContext {
        var next = context ?? makeEmptyContext()
        next.extractedGoals = extractedGoals.isEmpty ? GoalsManager.shared.richGoals : extractedGoals
        next.integrations = captureIntegrationsSnapshot()
        next.voicePersona = currentVoicePersona
        next.completedAt = Date()
        save(next)
        return next
    }

    func currentPromptContext(fullAnswers: Bool) -> String? {
        context?.promptContext(fullAnswers: fullAnswers)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    nonisolated static func persistedPromptContext(fullAnswers: Bool) -> String? {
        guard let context = persistedContext() else { return nil }
        return context.promptContext(fullAnswers: fullAnswers)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    nonisolated private static func persistedContext() -> OnboardingPodcastContext? {
        guard let data = UserDefaults.standard.data(forKey: contextKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OnboardingPodcastContext.self, from: data)
    }

    func uploadContextForFirstPodcastIfPossible(_ context: OnboardingPodcastContext) async throws {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        let metadata: [String: Any] = [
            "source": "onboarding",
            "generationSource": PodcastGenerationSource.onboardingFirstEpisode.rawValue,
            "questionCount": context.answeredQuestionCount,
            "goalsCount": context.extractedGoals.count,
            "voicePersona": context.voicePersona,
            "googleDocsConnected": context.integrations.googleDocsConnected,
            "googleDocsEnabled": context.integrations.googleDocsEnabled,
            "healthKitEnabled": context.integrations.healthKitEnabled,
            "screenTimeAuthorized": context.integrations.screenTimeAuthorized
        ]

        try await RetrospectAPIClient.shared.uploadContent(
            contentType: "onboarding_profile",
            content: context.promptContext(fullAnswers: true),
            contentDate: context.completedAt ?? Date(),
            metadata: metadata
        )
    }

    private var currentVoicePersona: String {
        defaults.string(forKey: "voice_persona") ?? "thoughtful_friend"
    }

    private func makeEmptyContext() -> OnboardingPodcastContext {
        OnboardingPodcastContext(
            depthAnswers: [],
            extractedGoals: [],
            voicePersona: currentVoicePersona,
            integrations: captureIntegrationsSnapshot(),
            createdAt: Date(),
            completedAt: nil
        )
    }

    private func captureIntegrationsSnapshot() -> OnboardingIntegrationsSnapshot {
        OnboardingIntegrationsSnapshot(
            googleDocsConnected: GoogleDocsService.shared.isConnected,
            googleDocsEnabled: GoogleDocsService.shared.isGoogleDocsEnabled,
            healthKitEnabled: defaults.bool(forKey: "healthKitEnabled"),
            screenTimeAuthorized: ScreenTimeService.shared.isAuthorized,
            capturedAt: Date()
        )
    }

    private func save(_ next: OnboardingPodcastContext) {
        context = next
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(next) {
            defaults.set(data, forKey: Self.contextKey)
        }
    }

    private func loadContext() {
        guard let data = defaults.data(forKey: Self.contextKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        context = try? decoder.decode(OnboardingPodcastContext.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Rich Goal Model

struct RichGoal: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var goalDescription: String
    var motivation: String
    var category: String
    var actionItems: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String = "",
        motivation: String = "",
        category: String = "Other",
        actionItems: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.motivation = motivation
        self.category = category
        self.actionItems = actionItems
        self.createdAt = createdAt
    }

    var hasDepth: Bool {
        !goalDescription.isEmpty || !motivation.isEmpty || !actionItems.isEmpty
    }

    var backendDescription: String {
        var parts: [String] = []
        if !goalDescription.isEmpty { parts.append(goalDescription) }
        if !motivation.isEmpty { parts.append("Why: \(motivation)") }
        if !actionItems.isEmpty { parts.append("Next steps: \(actionItems.joined(separator: "; "))") }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Goals Manager

class GoalsManager: ObservableObject {
    static let shared = GoalsManager()

    @Published var richGoals: [RichGoal] = []

    private let userDefaults = UserDefaults.standard
    private static let richGoalsKey = "rich_goals"
    private static let legacyGoalsKey = "simple_goals"
    static let onboardingProfileContextKey = "onboarding_profile_context"

    /// Backward-compatible computed property — returns goal titles as [String].
    /// All existing consumers (podcast gen, UI counts, etc.) continue to work unchanged.
    var goals: [String] {
        richGoals.map { $0.title }
    }

    /// Richer goal strings for podcast generation — includes description if available.
    var goalContextForGeneration: [String] {
        richGoals.map { goal in
            if goal.goalDescription.isEmpty {
                return goal.title
            }
            return "\(goal.title) — \(goal.goalDescription)"
        }
    }

    var onboardingProfileContext: String? {
        let context = userDefaults.string(forKey: Self.onboardingProfileContextKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return context?.isEmpty == false ? context : nil
    }

    var goalsCount: Int {
        richGoals.count
    }

    func getGoalsCount() -> Int {
        richGoals.count
    }

    private init() {
        loadGoals()
    }

    // MARK: - Rich Goal API

    func addRichGoal(_ goal: RichGoal) {
        guard !goal.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !richGoals.contains(where: { $0.title.lowercased() == goal.title.lowercased() }) else { return }
        richGoals.append(goal)
        saveGoals()
    }

    func addRichGoals(_ goals: [RichGoal]) {
        for goal in goals {
            addRichGoal(goal)
        }
    }

    func removeRichGoal(id: UUID) {
        richGoals.removeAll { $0.id == id }
        saveGoals()
    }

    // MARK: - Backward-compatible String API

    func addGoal(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !richGoals.contains(where: { $0.title.lowercased() == trimmed.lowercased() }) else { return }
        richGoals.append(RichGoal(title: trimmed))
        saveGoals()
    }

    func removeGoal(at index: Int) {
        guard index < richGoals.count else { return }
        richGoals.remove(at: index)
        saveGoals()
    }

    func removeGoal(_ goal: String) {
        richGoals.removeAll { $0.title == goal }
        saveGoals()
    }

    func clearAllGoals() {
        richGoals.removeAll()
        saveGoals()
    }

    func importGoals(_ importedGoals: [String]) {
        richGoals = importedGoals.map { RichGoal(title: $0) }
        saveGoals()
    }

    // MARK: - Persistence

    private func saveGoals() {
        let snapshot = self.richGoals
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard self != nil else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: GoalsManager.richGoalsKey)
            }
        }
        syncToBackend()
    }

    func syncToBackend() {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        let snapshot = self.richGoals
        Task {
            do {
                try await RetrospectAPIClient.shared.syncRichGoals(snapshot)
                print("Goals synced to backend (\(snapshot.count) goals)")
            } catch {
                print("Goal sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadGoals() {
        if let data = userDefaults.data(forKey: GoalsManager.richGoalsKey),
           let decoded = try? JSONDecoder().decode([RichGoal].self, from: data) {
            richGoals = decoded
            return
        }

        // Migrate from legacy string goals
        if let legacy = userDefaults.stringArray(forKey: GoalsManager.legacyGoalsKey), !legacy.isEmpty {
            richGoals = legacy.map { RichGoal(title: $0) }
            if let data = try? JSONEncoder().encode(richGoals) {
                userDefaults.set(data, forKey: GoalsManager.richGoalsKey)
            }
            userDefaults.removeObject(forKey: GoalsManager.legacyGoalsKey)
            return
        }

        richGoals = []
    }
}
