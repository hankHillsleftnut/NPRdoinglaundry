import ActivityKit
import AppIntents
import SwiftUI

// MARK: - Activity Attributes

@available(iOS 16.1, *)
public struct VoiceRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var recordingDuration: TimeInterval
        public var isRecording: Bool

        public init(recordingDuration: TimeInterval, isRecording: Bool) {
            self.recordingDuration = recordingDuration
            self.isRecording = isRecording
        }
    }

    public var startTime: Date

    public init(startTime: Date) {
        self.startTime = startTime
    }
}

// Note: StopRecordingIntent is defined in AppIntents/StopRecordingIntent.swift
