import Foundation

// MARK: - Backend Goal

struct BackendGoal: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Backend Observation

struct BackendObservation: Codable, Identifiable {
    let id: String
    let userId: String
    let goalId: String
    let rawContentId: String?
    let content: String
    let reasonWhy: String
    let confidenceScore: Double
    let observationDate: Date
    let metadata: [String: AnyCodable]?
    let createdAt: Date
}

// MARK: - Backend Insight

struct BackendInsight: Codable, Identifiable {
    let id: String
    let userId: String
    let goalId: String
    let title: String
    let content: String
    let evidenceSummary: String
    let supportingObservationIds: [String]
    let confidenceScore: Double
    let timeRangeStart: Date?
    let timeRangeEnd: Date?
    let metadata: [String: AnyCodable]?
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Podcast Episode (from backend)

struct PodcastEpisode: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let script: String
    let audioUrl: String?
    let durationSeconds: Int?
    let mood: String?
    let generationType: String
    let status: String
    let insightIds: [String]
    let goalIds: [String]
    let researchCitations: [PodcastCitation]?
    let outline: PodcastOutlineData?
    let episodeNumber: Int?
    let coversPeriodStart: Date?
    let coversPeriodEnd: Date?
    let topicsCovered: [String]?
    let createdAt: Date
    let updatedAt: Date

    /// Convert to the app's existing TranscriptModel for playback
    func toTranscriptModel() -> TranscriptModel {
        let citations = (researchCitations ?? []).map { citation in
            Citation(
                title: citation.source,
                url: citation.url ?? "",
                startIndex: 0,
                endIndex: 0
            )
        }

        var model = TranscriptModel(
            id: UUID(uuidString: id) ?? UUID(),
            originalText: "Backend-generated podcast episode",
            goals: [],
            processedTranscript: script,
            audioFileURL: audioUrl.flatMap { URL(string: $0) },
            mood: mood?.capitalized ?? "Reflective",
            generationType: .growthMentor,
            googleDocsInfo: nil,
            isDeepResearch: true,
            citations: citations.isEmpty ? nil : citations,
            researchQueries: researchCitations?.map(\.query),
            createdAt: createdAt
        )
        model.backendEpisodeId = id
        model.insightIds = insightIds
        return model
    }
}

// MARK: - Podcast Citation

struct PodcastCitation: Codable {
    let query: String
    let source: String
    let snippet: String
    let url: String?
}

// MARK: - Podcast Outline Data

struct PodcastOutlineData: Codable {
    let theme: String?
    let segments: [PodcastSegmentData]?
    let estimatedMinutes: Int?
}

struct PodcastSegmentData: Codable {
    let title: String?
    let type: String?
    let talkingPoints: [String]?
    let estimatedSeconds: Int?
}

// MARK: - AnyCodable helper for flexible metadata

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map(\.value)
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int: try container.encode(intVal)
        case let doubleVal as Double: try container.encode(doubleVal)
        case let boolVal as Bool: try container.encode(boolVal)
        case let stringVal as String: try container.encode(stringVal)
        default: try container.encodeNil()
        }
    }
}
