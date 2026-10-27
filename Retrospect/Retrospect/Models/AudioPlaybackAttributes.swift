import ActivityKit
import Foundation

struct AudioPlaybackAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var currentTime: TimeInterval
        var duration: TimeInterval
        var isPlaying: Bool
    }
}
