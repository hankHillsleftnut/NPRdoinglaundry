import Foundation

extension Notification.Name {
    static let integrationConnectionChanged = Notification.Name("IntegrationConnectionChanged")
}

enum IntegrationCategory: String, CaseIterable, Identifiable {
    case available = "Connect now"
    case behavioral = "Digital life"
    case conversations = "Optional files"

    var id: String {
        rawValue
    }
}

enum IntegrationConnectionKind: Equatable {
    case healthKit
    case screenTime
    case googleDocs
    case calendar
    case appleMusic
    case photos
    case contacts
    case oauth
    case archiveImport
    case planned
}

struct IntegrationCatalogItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: IntegrationCategory
    let connectionKind: IntegrationConnectionKind
    let plannedStatus: String?

    static let all: [IntegrationCatalogItem] = [
        .init(
            id: "healthkit",
            title: "Apple Health",
            subtitle: "Sleep, activity, heart rate, and daily rhythms.",
            icon: "heart.fill",
            category: .available,
            connectionKind: .healthKit,
            plannedStatus: "Device sync"
        ),
        .init(
            id: "screen_time",
            title: "Screen Time",
            subtitle: "Where your attention goes across apps and categories.",
            icon: "chart.bar.fill",
            category: .available,
            connectionKind: .screenTime,
            plannedStatus: "Device sync"
        ),
        .init(
            id: "google_docs",
            title: "Google Docs",
            subtitle: "The thoughts and work you have already written.",
            icon: "doc.text.fill",
            category: .available,
            connectionKind: .oauth,
            plannedStatus: "Continuous sync"
        ),
        .init(
            id: "calendar",
            title: "Calendar",
            subtitle: "Your commitments, routines, and the shape of your time.",
            icon: "calendar",
            category: .available,
            connectionKind: .calendar,
            plannedStatus: "Device sync"
        ),
        .init(
            id: "apple_music",
            title: "Apple Music",
            subtitle: "Listening patterns, favorites, and recent music.",
            icon: "music.note",
            category: .available,
            connectionKind: .appleMusic,
            plannedStatus: "Device sync"
        ),
        .init(
            id: "photos",
            title: "Photos",
            subtitle: "Activity and memory patterns from your photo library.",
            icon: "photo.on.rectangle.angled",
            category: .available,
            connectionKind: .photos,
            plannedStatus: "Device sync"
        ),
        .init(
            id: "contacts",
            title: "Contacts",
            subtitle: "The people and relationships present in your life.",
            icon: "person.2.fill",
            category: .available,
            connectionKind: .contacts,
            plannedStatus: "Device sync"
        ),

        .init(
            id: "spotify",
            title: "Spotify",
            subtitle: "Recently played music, favorites, playlists, and taste.",
            icon: "music.note.list",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "Continuous sync"
        ),
        .init(
            id: "youtube",
            title: "YouTube",
            subtitle: "Subscriptions, playlists, likes, and available activity.",
            icon: "play.rectangle.fill",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "API-visible sync"
        ),
        .init(
            id: "reddit",
            title: "Reddit",
            subtitle: "Saved posts, comments, subscriptions, and interests.",
            icon: "bubble.left.and.bubble.right.fill",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "Continuous sync"
        ),
        .init(
            id: "gmail",
            title: "Gmail",
            subtitle: "Communication patterns, relationships, and commitments.",
            icon: "envelope.fill",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "Verification-gated sync"
        ),
        .init(
            id: "tiktok",
            title: "TikTok",
            subtitle: "Profile, public videos, and approved activity access.",
            icon: "play.square.stack.fill",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "API-visible sync"
        ),
        .init(
            id: "x",
            title: "X",
            subtitle: "Available posts, bookmarks, likes, and social interests.",
            icon: "at",
            category: .behavioral,
            connectionKind: .oauth,
            plannedStatus: "API-tier gated sync"
        ),

        .init(
            id: "chatgpt",
            title: "ChatGPT",
            subtitle: "Conversation files you already have.",
            icon: "message.fill",
            category: .conversations,
            connectionKind: .archiveImport,
            plannedStatus: "Optional file import"
        ),
        .init(
            id: "claude",
            title: "Claude",
            subtitle: "Conversation files you already have.",
            icon: "text.bubble.fill",
            category: .conversations,
            connectionKind: .archiveImport,
            plannedStatus: "Optional file import"
        ),
        .init(
            id: "grok",
            title: "Grok",
            subtitle: "Conversation files you already have.",
            icon: "text.bubble",
            category: .conversations,
            connectionKind: .archiveImport,
            plannedStatus: "Optional file import"
        ),
        .init(
            id: "netflix",
            title: "Netflix",
            subtitle: "Viewing files you already have.",
            icon: "tv.fill",
            category: .conversations,
            connectionKind: .archiveImport,
            plannedStatus: "Optional file import"
        ),
    ]
}
