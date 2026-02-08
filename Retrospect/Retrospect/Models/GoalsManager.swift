import Foundation
import SwiftUI

class GoalsManager: ObservableObject {
    static let shared = GoalsManager()
    
    @Published var goals: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let goalsKey = "simple_goals"
    
    private init() {
        loadGoals()
    }
    
    func addGoal(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        // Prevent duplicates
        guard !goals.contains(where: { $0.lowercased() == trimmedText.lowercased() }) else { return }
        
        goals.append(trimmedText)
        saveGoals()
    }
    
    func removeGoal(at index: Int) {
        guard index < goals.count else { return }
        goals.remove(at: index)
        saveGoals()
    }
    
    func removeGoal(_ goal: String) {
        goals.removeAll { $0 == goal }
        saveGoals()
    }
    
    func clearAllGoals() {
        goals.removeAll()
        saveGoals()
    }
    
    func importGoals(_ importedGoals: [String]) {
        goals = importedGoals
        saveGoals()
    }
    
    var goalsCount: Int {
        return goals.count
    }
    
    func getGoalsCount() -> Int {
        return goals.count
    }
    
    private func saveGoals() {
        let currentGoals = self.goals
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.userDefaults.set(currentGoals, forKey: self.goalsKey)
        }
        // Sync to backend if authenticated
        syncToBackend()
    }
    
    /// Sync goals to the Retrospect backend (non-blocking).
    func syncToBackend() {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        let currentGoals = self.goals
        Task {
            do {
                try await RetrospectAPIClient.shared.syncGoals(currentGoals)
                print("Goals synced to backend (\(currentGoals.count) goals)")
            } catch {
                print("Goal sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadGoals() {
        goals = userDefaults.stringArray(forKey: goalsKey) ?? []
    }
} 