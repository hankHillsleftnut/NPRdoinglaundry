//
//  RetrospectApp.swift
//  Retrospect
//
//  Created by Shaurya Narang on 6/5/25.
//

import SwiftUI
import UIKit
import UserNotifications

// MARK: - App Delegate for Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let podcastId = userInfo["podcastId"] as? String,
           let type = userInfo["type"] as? String,
           type == "newPodcast" || type == "followUp" {
            // Post notification to show the podcast arrival view
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowPodcastFromNotification"),
                object: nil,
                userInfo: ["podcastId": podcastId]
            )
        }
        
        completionHandler()
    }
}

@main
struct RetrospectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("useDarkUI") private var useDarkUI: Bool = true // Default to new dark UI
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    @State private var showGoogleAuth = false
    @State private var shouldStartVoiceRecording = false
    @State private var isProcessingStopFromWidget = false
    @State private var isAuthenticated = false
    @State private var showPodcastFromNotification = false
    @State private var notificationPodcastId: String?
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationService = PodcastNotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    private var isGoogleConfigured: Bool {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return false
        }
        return !clientID.isEmpty && clientID != "554366364287-po5osj24tcqrom1lhfkitm3c4qsb3i2c.apps.googleusercontent.com"
    }
    
    // Check if we need to show splash screen
    private var shouldShowSplash: Bool {
        return faceIDEnabled && !isAuthenticated && hasCompletedOnboarding
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Show transparent view when handling stop from widget
                if isProcessingStopFromWidget {
                    Color.black
                        .ignoresSafeArea()
                        .transition(.opacity)
                } else if !hasCompletedOnboarding {
                    DarkOnboardingFlow(onComplete: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasCompletedOnboarding = true
                            // Auto-authenticate after onboarding (don't require Face ID immediately)
                            isAuthenticated = true
                        }
                    })
                    .transition(.opacity)
                } else if shouldShowSplash {
                    // Show Face ID splash screen
                    DarkSplashScreen(isAuthenticated: $isAuthenticated)
                    .transition(.opacity)
                } else {
                    // Use new dark UI by default
                    DarkAppContainer(shouldStartVoiceRecording: $shouldStartVoiceRecording)
                        .transition(.opacity)
                }
                
                if showGoogleAuth && isGoogleConfigured && hasCompletedOnboarding && isAuthenticated {
                    GoogleAuthView(isPresented: $showGoogleAuth)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.5), value: showGoogleAuth)
            .animation(.easeInOut(duration: 0.4), value: isAuthenticated)
            .animation(.easeOut(duration: 0.2), value: isProcessingStopFromWidget)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentColorScheme)
            .animatedThemeTransition()
            .onAppear {
                // If Face ID is disabled, mark as authenticated
                if !faceIDEnabled {
                    isAuthenticated = true
                }
                
                // Check if launched from shortcut (persisted flag)
                if UserDefaults.standard.bool(forKey: "shouldStartVoiceRecordingFromShortcut") {
                    UserDefaults.standard.set(false, forKey: "shouldStartVoiceRecordingFromShortcut")
                    UserDefaults.standard.synchronize()
                    
                    print("🎙️ App launched from shortcut - starting voice recording")
                    
                    if hasCompletedOnboarding && isAuthenticated {
                        // Small delay to let UI settle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldStartVoiceRecording = true
                        }
                    }
                }
                
                // Show Google auth if properly configured, not connected, and onboarding is complete
                if hasCompletedOnboarding && isAuthenticated && !googleDocsService.isConnected && isGoogleConfigured {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showGoogleAuth = true
                    }
                }
                
                // Listen for voice recording shortcut trigger (when app is already running)
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("StartVoiceRecordingFromShortcut"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // Clear the flag in case it was set
                    UserDefaults.standard.set(false, forKey: "shouldStartVoiceRecordingFromShortcut")
                    
                    if hasCompletedOnboarding && isAuthenticated {
                        shouldStartVoiceRecording = true
                    }
                }
                
                // Listen for podcast notification tap
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowPodcastFromNotification"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let podcastId = notification.userInfo?["podcastId"] as? String {
                        notificationPodcastId = podcastId
                        showPodcastFromNotification = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showPodcastFromNotification) {
                // Show the podcast arrival view
                if let podcastId = notificationPodcastId {
                    // Try to find existing transcript or create a placeholder
                    let transcript = findOrCreateTranscript(for: podcastId)
                    NewPodcastArrivalView(
                        transcript: transcript,
                        onPlay: {
                            showPodcastFromNotification = false
                            // Navigate to podcast player (handled by DarkAppContainer)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("PlayPodcast"),
                                object: nil,
                                userInfo: ["podcastId": podcastId]
                            )
                        },
                        onDismiss: {
                            showPodcastFromNotification = false
                        }
                    )
                }
            }
            .onChange(of: googleDocsService.isConnected) { _, isConnected in
                // Hide Google auth when connected
                if isConnected && showGoogleAuth {
                    showGoogleAuth = false
                }
            }
            .onChange(of: isAuthenticated) { _, newValue in
                // Show Google auth after authentication
                if newValue && hasCompletedOnboarding && !googleDocsService.isConnected && isGoogleConfigured {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showGoogleAuth = true
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // If recording is active and app goes to background, keep it recording
                if newPhase == .background {
                    print("📱 App moved to background - recording continues")
                }
                // Re-authenticate when app becomes active (optional - for higher security)
                // Uncomment the following if you want to require Face ID every time app opens:
                // if newPhase == .active && oldPhase == .background && faceIDEnabled {
                //     isAuthenticated = false
                // }
            }
            .onOpenURL { url in
                guard url.scheme == "retrospect" else { return }
                
                if url.host == "stop-recording" {
                    print("💾 Save recording triggered from Live Activity")
                    
                    // Show black screen immediately (don't show app UI)
                    isProcessingStopFromWidget = true
                    
                    // Notify VoiceRecordingView to stop and save
                    // This will trigger the proper save flow in VoiceRecordingView
                    NotificationCenter.default.post(
                        name: NSNotification.Name("StopVoiceRecordingFromLiveActivity"),
                        object: nil
                    )
                    
                    // Give time for the save to complete, then hide black screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isProcessingStopFromWidget = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Find existing transcript or create placeholder for notification
    private func findOrCreateTranscript(for podcastId: String) -> TranscriptModel {
        // Check if we have a pending notification with this podcast
        if let pending = notificationService.pendingNotification,
           pending.id == podcastId {
            return TranscriptModel(
                id: UUID(uuidString: podcastId) ?? UUID(),
                originalText: "Your weekly reflection is ready.",
                goals: [],
                processedTranscript: "# Weekly Reflection\n\nYour personalized podcast is ready to play.",
                audioFileURL: nil,
                mood: "Positive",
                createdAt: pending.timestamp
            )
        }
        
        // Fallback placeholder
        return TranscriptModel(
            id: UUID(uuidString: podcastId) ?? UUID(),
            originalText: "Your weekly reflection is ready.",
            goals: [],
            processedTranscript: "# Weekly Reflection\n\nYour personalized podcast is ready to play.",
            audioFileURL: nil,
            mood: "Positive",
            createdAt: Date()
        )
    }
    
    /// Save voice entry with audio file and transcription
    @MainActor
    private func saveVoiceEntry(audioURL: URL, transcription: String) async {
        print("💾 Saving voice entry...")
        
        // Generate simple title from transcription
        var title = "Voice Entry"
        if !transcription.isEmpty {
            // Use first few words of transcription as title
            let words = transcription.split(separator: " ").prefix(10)
            title = words.joined(separator: " ")
            if transcription.split(separator: " ").count > 10 {
                title += "..."
            }
        }
        
        // Move audio file from temp to permanent storage
        let entryId = UUID()
        do {
            try FileStorageManager.shared.moveAudio(from: audioURL, to: entryId)
            print("✅ Audio file moved to permanent storage")
        } catch {
            print("❌ Failed to move audio file: \(error.localizedDescription)")
            return
        }
        
        // Create and save entry
        let entry = Entry(
            id: entryId,
            type: .voice,
            content: transcription,
            audioURL: FileStorageManager.shared.getAudioURL(for: entryId),
            aiGeneratedTitle: title,
            tags: []
        )
        
        EntryManager.shared.addEntry(entry)
        print("✅ Voice entry saved successfully!")
    }
}
