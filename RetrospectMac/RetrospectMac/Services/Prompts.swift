import Foundation

/// A curated, static set of gentle reflective prompts. No backend dependency — instant and
/// reliable. They rotate by day so the page feels fresh without ever nagging.
enum Prompts {
    static let all: [String] = [
        "What's sitting with you right now?",
        "What did today ask of you?",
        "What are you quietly proud of lately?",
        "What's one thing you noticed but haven't said out loud?",
        "Where did your attention keep going today?",
        "What would you tell yourself this morning, knowing what you know now?",
        "What felt heavier than it needed to?",
        "What are you moving toward?",
        "What did you make space for — and what got crowded out?",
        "If nothing were watching, what would you write?",
        "What's true today that wasn't true a month ago?",
        "What are you ready to put down?",
        "Who were you with, and how did it leave you feeling?",
        "What surprised you?",
        "What do you want to remember about right now?",
    ]

    /// Deterministic per-day pick so the prompt is stable through the day.
    static func today() -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all[day % all.count]
    }
}
