//
//  PodcastNotificationService.swift
//  Retrospect
//
//  Handles push notifications for new podcast episodes
//  Sends personalized, cheeky notifications based on podcast content
//

import Foundation
import UserNotifications

@MainActor
class PodcastNotificationService: ObservableObject {
    static let shared = PodcastNotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotification: PodcastNotification?
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Send Notification
    
    func sendPodcastNotification(
        title: String = "You have a new podcast ready 🎧",
        cheekyHook: String,
        podcastId: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = cheekyHook
        content.sound = .default
        content.badge = 1
        content.userInfo = ["podcastId": podcastId, "type": "newPodcast"]
        
        // Send immediately
        let request = UNNotificationRequest(
            identifier: "podcast-\(podcastId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            } else {
                print("✅ Podcast notification sent!")
            }
        }
        
        // Store for in-app handling
        pendingNotification = PodcastNotification(
            id: podcastId,
            title: title,
            hook: cheekyHook
        )
    }
    
    // MARK: - Schedule Follow-up Notifications
    
    func scheduleFollowUpNotification(
        hook: String,
        podcastId: String,
        delayHours: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Still haven't listened? 👀"
        content.body = hook
        content.sound = .default
        content.userInfo = ["podcastId": podcastId, "type": "followUp"]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(delayHours * 3600),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "podcast-followup-\(podcastId)-\(delayHours)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule follow-up: \(error)")
            }
        }
    }
    
    // MARK: - Generate Cheeky Hook
    
    func generateCheekyHook(from transcript: TranscriptModel) -> String {
        // Extract key content from transcript for personalized hook
        let content = transcript.originalText
        
        // If we have actual content, try to extract names and make it personal
        if !content.isEmpty {
            // Try to find a name in the content for ultra-personal hooks
            if let name = extractName(from: content) {
                return generateNameBasedHook(name: name, content: content)
            }
            
            // Look for personal topics
            let topicHooks: [(keywords: [String], hook: String)] = [
                (["broke up", "breakup", "ex ", "ended things"], "We found the real reason it didn't work out."),
                (["relationship", "dating", "partner"], "That person you keep thinking about? We need to talk."),
                (["quit", "leaving", "resign", "new job"], "You already know what you need to do about work."),
                (["boss", "manager", "coworker"], "That thing at work is more about you than them."),
                (["anxiety", "anxious", "worried", "panic"], "The anxiety isn't random—here's where it's coming from."),
                (["stress", "overwhelm", "burned out"], "You're not lazy, you're exhausted. Here's why."),
                (["mom", "mother", "dad", "father", "parent"], "Your parents shaped more than you realize."),
                (["friend", "friendship", "best friend"], "That friendship might be changing for a reason."),
                (["money", "debt", "broke", "afford"], "The money thing? It's not actually about money."),
                (["sleep", "tired", "exhausted", "insomnia"], "Your sleep says a lot about what you're avoiding."),
                (["weight", "body", "eating", "diet"], "This isn't really about how you look."),
                (["love", "loving", "loved"], "You're afraid of the thing you want most."),
                (["angry", "anger", "mad", "furious"], "The anger is protecting something softer underneath."),
                (["sad", "crying", "tears", "depressed"], "There's a reason you've been feeling this way."),
                (["goal", "dream", "want to", "someday"], "That dream you keep postponing? Time to face it."),
                (["scared", "fear", "afraid"], "The fear is pointing exactly where you need to go."),
                (["alone", "lonely", "isolated"], "You're not as alone as you feel right now."),
                (["happy", "excited", "good news"], "Something shifted this week. You felt it too."),
                (["therapy", "therapist", "counseling"], "Your therapist would agree with this episode."),
                (["decision", "choice", "deciding"], "You already made the decision. You just haven't admitted it.")
            ]
            
            for (keywords, hook) in topicHooks {
                for keyword in keywords {
                    if content.lowercased().contains(keyword) {
                        return hook
                    }
                }
            }
        }
        
        // Fallback hooks - still punchy single sentences
        let fallbackHooks = [
            "This week told a story you haven't admitted to yourself yet.",
            "We found the pattern you've been ignoring.",
            "There's something you need to hear about yourself.",
            "Your subconscious had a lot to say this week.",
            "This one might hit different."
        ]
        
        return fallbackHooks.randomElement() ?? fallbackHooks[0]
    }
    
    /// Try to extract a proper name from the content
    private func extractName(from content: String) -> String? {
        // Common name patterns - look for capitalized words that might be names
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        
        // Common names to look for (could be expanded)
        let commonNames = ["Amanda", "Sarah", "Jessica", "Emily", "Ashley", "Michael", "David", "James", "John", "Chris", 
                          "Matt", "Alex", "Sam", "Jake", "Ryan", "Tyler", "Brandon", "Justin", "Nick", "Josh",
                          "Katie", "Lauren", "Rachel", "Megan", "Hannah", "Nicole", "Stephanie", "Jennifer", "Lisa", "Amy",
                          "Mom", "Dad", "Brother", "Sister"]
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if commonNames.contains(where: { $0.lowercased() == cleanWord.lowercased() }) {
                return cleanWord.capitalized
            }
        }
        
        return nil
    }
    
    /// Generate a hook that includes a specific name
    private func generateNameBasedHook(name: String, content: String) -> String {
        let lowercased = content.lowercased()
        
        if lowercased.contains("broke up") || lowercased.contains("breakup") || lowercased.contains("ex ") {
            return "This is why things with \(name) didn't work out."
        } else if lowercased.contains("fight") || lowercased.contains("argument") || lowercased.contains("angry") {
            return "That thing with \(name)? Here's what's really going on."
        } else if lowercased.contains("miss") || lowercased.contains("thinking about") {
            return "You're still thinking about \(name) for a reason."
        } else if lowercased.contains("love") || lowercased.contains("feeling") {
            return "Your feelings about \(name) finally make sense."
        } else if lowercased.contains("talk") || lowercased.contains("said") || lowercased.contains("told") {
            return "\(name) said something that stuck with you."
        } else {
            return "We need to talk about \(name)."
        }
    }
    
    // MARK: - Clear Notifications
    
    func clearPendingNotification() {
        pendingNotification = nil
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().setBadgeCount(0)
        pendingNotification = nil
    }
}

// MARK: - Podcast Notification Model
struct PodcastNotification: Identifiable {
    let id: String
    let title: String
    let hook: String
    var timestamp: Date = Date()
}

