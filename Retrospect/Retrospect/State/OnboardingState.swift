//
//  OnboardingState.swift
//  Retrospect
//
//  Single source of truth for the iMessage-style onboarding flow.
//  Owned as a @StateObject by DarkOnboardingFlow so state survives
//  SwiftUI view recreation.
//

import SwiftUI
import Foundation

// MARK: - Onboarding Phase

enum OnboardingPhase: Int, CaseIterable {
    case integrations = 1
    case voicePersona = 2
    case goals = 3
    case closing = 4

    static let totalPhases = 4
}

// MARK: - Data Models

enum ChatMessageSender {
    case retrospect
    case user
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: ChatMessageSender
    let text: String
    var isSpecial: Bool = false
}

enum SendButtonStyle: Equatable {
    case `default`
    case sparkle
}

// MARK: - OnboardingState

final class OnboardingState: ObservableObject {

    // MARK: Sign-in gate

    @Published var hasSignedIn: Bool = false
    @Published var privacyAcknowledged: Bool = false
    @Published var integrationsCompleted: Bool = false
    @Published var personaCompleted: Bool = false

    // MARK: Phase & conversation

    @Published var phase: OnboardingPhase = .integrations
    @Published var messages: [ChatMessage] = []
    @Published var completedAnimationIds: Set<UUID> = []
    @Published var showTypingIndicator: Bool = false
    @Published var showActionButton: Bool = false

    // MARK: Goals multi-turn

    @Published var goalsTurn: Int = 1
    @Published var goalTurn1Text: String = ""
    @Published var goalTurn2Text: String = ""
    @Published var goalTurn2BotMessage: String = ""
    @Published var extractedGoalsFromConversation: [String] = []
    @Published var isLoadingGoalsReply: Bool = false

    // MARK: Integrations loading

    @Published var isConnectingGoogle: Bool = false
    @Published var googleError: String? = nil
    @Published var isRequestingHealth: Bool = false
    @Published var isConnectingScreenTime: Bool = false
    @Published var isSavingPersona: Bool = false

    // MARK: Pull-up-to-enter (closing phase)

    @Published var pullToEnterOffset: CGFloat = 0
    @Published var pullGestureDidPrepare: Bool = false

    // MARK: Input bar

    @Published var isAutoFillLocked: Bool = false
    @Published var showSkipLink: Bool = false
    @Published var sendButtonOverride: SendButtonStyle = .default

    // MARK: Keyboard

    @Published var keyboardHeight: CGFloat = 0

    // MARK: Session guard

    @Published var hasStartedConversation: Bool = false
    @Published var welcomeAnimationPlayed: Bool = false
    @Published var signInInProgress: Bool = false

    // MARK: Constants

    static let pullToEnterThreshold: CGFloat = 100
    static let pullToEnterMaxStretch: CGFloat = 140
    static let scrollBottomPadding: CGFloat = 180
    static let scrollBottomPaddingWithKeyboard: CGFloat = 24
    static let messageUnblurDuration: Double = 0.7

    static let goalsFirstQuestion = "How do you feel about the next couple of months? What would be ideal for you to have?"

    static let goalSuggestions = [
        "Exercise more", "Better sleep", "Read daily", "Learn something new",
        "Reduce stress", "Eat healthier", "Save money", "Be more present",
        "Improve focus", "Build habits"
    ]

    // MARK: Init

    init() {
        restoreFromDisk()
    }

    // MARK: Persistence

    private static let persistedStepKey = "onboardingCurrentStep"
    private static let signedInKey = "onboardingSignedIn"
    private static let privacyAcknowledgedKey = "onboardingPrivacyAcknowledged"
    private static let integrationsCompletedKey = "onboardingIntegrationsCompleted"
    private static let personaCompletedKey = "onboardingPersonaCompleted"

    func markSignedIn() {
        hasSignedIn = true
        UserDefaults.standard.set(true, forKey: Self.signedInKey)
        phase = .integrations
        persistPhase()
    }

    func markPrivacyAcknowledged() {
        privacyAcknowledged = true
        UserDefaults.standard.set(true, forKey: Self.privacyAcknowledgedKey)
    }

    func markIntegrationsCompleted() {
        integrationsCompleted = true
        UserDefaults.standard.set(true, forKey: Self.integrationsCompletedKey)
    }

    func markPersonaCompleted() {
        personaCompleted = true
        UserDefaults.standard.set(true, forKey: Self.personaCompletedKey)
    }

    func persistPhase() {
        UserDefaults.standard.set(phase.rawValue, forKey: Self.persistedStepKey)
    }

    func restoreFromDisk() {
        hasSignedIn = UserDefaults.standard.bool(forKey: Self.signedInKey)
        privacyAcknowledged = UserDefaults.standard.bool(forKey: Self.privacyAcknowledgedKey)
        integrationsCompleted = UserDefaults.standard.bool(forKey: Self.integrationsCompletedKey)
        personaCompleted = UserDefaults.standard.bool(forKey: Self.personaCompletedKey)
        let stored = UserDefaults.standard.integer(forKey: Self.persistedStepKey)

        guard hasSignedIn else {
            phase = .integrations
            return
        }

        // Map legacy values (old 9-step -> 6-step -> new 4-step)
        let raw = max(1, min(stored == 0 ? 1 : stored, 9))
        let sixStep: Int = raw <= 2 ? 1 : raw == 3 ? 2 : raw <= 6 ? 3 : raw == 7 ? 4 : raw == 8 ? 5 : 6
        let fourStep: Int
        switch sixStep {
        case 1, 2, 3: fourStep = 1  // old intro/auth/integrations -> integrations
        case 4: fourStep = 2         // voicePersona
        case 5: fourStep = 3         // goals
        default: fourStep = 4        // closing
        }

        phase = OnboardingPhase(rawValue: fourStep) ?? .integrations
        if stored != fourStep {
            UserDefaults.standard.set(fourStep, forKey: Self.persistedStepKey)
        }
    }

    func clearPersistedStep() {
        UserDefaults.standard.removeObject(forKey: Self.persistedStepKey)
        UserDefaults.standard.removeObject(forKey: Self.signedInKey)
        UserDefaults.standard.removeObject(forKey: Self.privacyAcknowledgedKey)
        UserDefaults.standard.removeObject(forKey: Self.integrationsCompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.personaCompletedKey)
    }

    // MARK: Busy check

    var isBusyWithAction: Bool {
        isConnectingGoogle || isRequestingHealth || isConnectingScreenTime || isSavingPersona
    }

    // MARK: Script messages

    func scriptMessages(for p: OnboardingPhase) -> [ChatMessage] {
        switch p {
        case .integrations:
            return [
                ChatMessage(sender: .retrospect, text: "Welcome aboard. Let's get you set up."),
                ChatMessage(sender: .retrospect, text: "Let's connect your data sources — pick what matters to you. You can add more anytime in Settings."),
            ]
        case .voicePersona:
            return [
                ChatMessage(sender: .retrospect, text: "One more thing — who do you want speaking to you each week?"),
            ]
        case .goals:
            return goalsIntroMessages()
        case .closing:
            return [
                ChatMessage(sender: .retrospect, text: "Every journal entry, voice note, and stray thought — I'll turn them into something you actually want to hear."),
                ChatMessage(sender: .retrospect, text: "Your first podcast drops after your first week. Ready when you are."),
            ]
        }
    }

    func goalsIntroMessages() -> [ChatMessage] {
        if goalsTurn == 1 {
            return [ChatMessage(sender: .retrospect, text: Self.goalsFirstQuestion)]
        }
        if goalsTurn == 4 {
            let list = extractedGoalsFromConversation.prefix(3).joined(separator: ", ")
            return [ChatMessage(sender: .retrospect, text: "From what you've told me, it sounds like your focus areas are: \(list). Sound right?")]
        }
        return []
    }

    // MARK: Replay & append

    func replayMessagesForPhase() {
        messages = []
        for p in OnboardingPhase.allCases {
            if p.rawValue < phase.rawValue {
                if p == .goals && phase == .closing {
                    continue
                }
                appendPhaseMessages(for: p)
            } else if p == phase {
                break
            }
        }
        completedAnimationIds = Set(messages.map(\.id))
    }

    func appendPhaseMessages(for p: OnboardingPhase) {
        let newMessages = scriptMessages(for: p)
        for msg in newMessages {
            let isDuplicate = messages.contains { existing in
                existing.sender == msg.sender && existing.text == msg.text
            }
            if !isDuplicate {
                messages.append(msg)
            }
        }
    }

    // MARK: Helpers

    func addUserBubble(_ text: String) {
        let msg = ChatMessage(sender: .user, text: text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            messages.append(msg)
        }
        HapticManager.shared.playMediumImpact()
    }

    func personaDisplayName(_ id: String) -> String {
        switch id {
        case "wise_mentor": return "Wise Mentor"
        case "energetic_host": return "Energetic Host"
        default: return "Thoughtful Friend"
        }
    }

    func personaPreviewText(_ id: String) -> String {
        switch id {
        case "wise_mentor": return "Calm and grounded. I'll let insights land with weight."
        case "energetic_host": return "Dynamic and engaging. I'll celebrate your wins."
        default: return "Warm and conversational. Like catching up over coffee."
        }
    }

    func fallbackGoalsReplyForTurn(_ turn: Int) -> String {
        if turn == 2 {
            let trimmed = goalTurn1Text.trimmingCharacters(in: .whitespacesAndNewlines)
            let phrase = trimmed.isEmpty ? "something to focus on" : String(trimmed.prefix(60))
            if phrase.count < trimmed.count {
                return "You mentioned \(phrase)... Tell me more about why that matters to you right now."
            }
            return "You said: \"\(phrase)\" — what would it look like to get there, day to day?"
        }
        return "What else matters to you right now?"
    }

    func extractGoalsFromTurnsFallback() -> [String] {
        let combined = [goalTurn1Text, goalTurn2Text]
            .joined(separator: " ")
            .lowercased()
        var goals: [String] = []
        let themes: [(keywords: [String], goal: String)] = [
            (["exercise", "workout", "gym", "fitness", "run", "move", "stronger", "muscle"], "Exercise more"),
            (["sleep", "rest", "tired", "energy", "well-rested"], "Better sleep"),
            (["read", "book", "reading"], "Read daily"),
            (["learn", "skill", "study", "course", "education"], "Learn something new"),
            (["stress", "calm", "anxiety", "overwhelm", "peaceful"], "Reduce stress"),
            (["eat", "food", "diet", "healthier", "nutrition"], "Eat healthier"),
            (["money", "save", "spend", "financial", "finances", "budget"], "Save money"),
            (["present", "moment", "mindful", "mindfulness"], "Be more present"),
            (["focus", "concentrate", "distract", "attention"], "Improve focus"),
            (["habit", "routine", "consistent", "discipline"], "Build habits"),
            (["relationship", "friend", "family", "connect", "social"], "Improve relationships"),
            (["career", "work", "job", "professional", "promotion"], "Career growth"),
            (["creative", "create", "write", "art", "artistic"], "Creativity"),
        ]
        for (keywords, goal) in themes {
            if keywords.contains(where: { combined.contains($0) }), !goals.contains(goal) {
                goals.append(goal)
            }
        }
        if goals.isEmpty {
            let sentences = [goalTurn1Text, goalTurn2Text].joined(separator: " ").components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 10 }
            goals = sentences.prefix(3).map { String($0.prefix(40)) }
            if goals.isEmpty { goals = ["Personal growth"] }
        }
        return Array(goals.prefix(3))
    }
}
