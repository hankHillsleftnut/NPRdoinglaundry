import Foundation
import SwiftUI

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
