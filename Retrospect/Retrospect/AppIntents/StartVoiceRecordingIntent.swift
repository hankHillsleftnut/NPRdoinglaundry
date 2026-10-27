import AppIntents
import SwiftUI
import UIKit
import AVFoundation

@available(iOS 16.0, *)
struct StartVoiceRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Voice Recording"
    
    static var description: IntentDescription? = IntentDescription(
        "Start voice recording with Live Activity",
        categoryName: "Journal",
        searchKeywords: ["voice", "record", "audio", "journal", "note"]
    )
    
    // App must open briefly to start audio recording (iOS requirement)
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("🎙️ Action Button pressed - Starting voice recording")
        
        // Set flag that persists even if app relaunches
        UserDefaults.standard.set(true, forKey: "shouldStartVoiceRecordingFromShortcut")
        UserDefaults.standard.synchronize()
        
        // Also post notification for already-running app
        NotificationCenter.default.post(
            name: NSNotification.Name("StartVoiceRecordingFromShortcut"),
            object: nil
        )
        
        // Small delay to let app process
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        print("✅ Recording intent completed")
        
        return .result()
    }
}

// App Shortcuts Provider
@available(iOS 16.0, *)
struct RetrospectShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartVoiceRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "Record a voice note in \(.applicationName)",
                "Start voice journal in \(.applicationName)"
            ],
            shortTitle: "Voice Recording",
            systemImageName: "waveform"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor {
        .tangerine
    }
}

