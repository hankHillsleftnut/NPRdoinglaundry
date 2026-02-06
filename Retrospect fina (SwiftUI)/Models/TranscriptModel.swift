import Foundation

struct TranscriptModel {
    let originalText: String
    let goals: [String]
    var processedTranscript: String?
    var audioFileURL: URL?
}
