//
//  RetrospectApp.swift
//  Retrospect
//
//  Created by Shaurya Narang on 6/5/25.
//

import SwiftUI
import UIKit
import UserNotifications
import DeviceActivity

// MARK: - App Delegate for Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Initialize RevenueCat (no-op until the purchases-ios SDK is added). Must
        // run before any paywall queries customerInfo/offerings.
        SubscriptionManager.shared.configure()
        IntegrationBackgroundTasks.register()
        IntegrationBackgroundTasks.schedule()
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
    @State private var needsBackendAuth = false // true when onboarding done but no backend JWT
    @State private var isCreatingFirstPodcast = false
    @State private var isPreviewingPaywall = false
    @State private var firstPodcastTranscript: TranscriptModel?
    @State private var showFirstPodcastArrival = false
    @State private var firstPodcastError: String?
    @StateObject private var googleDocsService = GoogleDocsService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationService = PodcastNotificationService.shared
    @StateObject private var firstPodcastOrchestrator = FirstPodcastOrchestrator.shared
    @ObservedObject private var apiClient = RetrospectAPIClient.shared
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @State private var platform = Platform.Environment.live()
    @Environment(\.scenePhase) private var scenePhase

    private var isPodcastLayoutDiagnosticsMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PodcastLayoutDiagnostics")
        #else
        false
        #endif
    }

    /// Design lab (M14): the DesignSystemV2 gallery, motion lab and component catalogue.
    private var isDesignLabMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-DesignLab")
        #else
        false
        #endif
    }

    private var isAnimationPreviewMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-AnimationPreview")
        #else
        false
        #endif
    }

    private var isLearningTouchMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-LearningTouch")
        #else
        false
        #endif
    }

    private var isLearningTouchAutoMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-LearningTouchAuto")
        #else
        false
        #endif
    }

    private var isFirstPodcastFinaleMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-FirstPodcastFinale")
        #else
        false
        #endif
    }

    /// A stored JWT is the only thing that counts, in every configuration. A DEBUG-only
    /// bypass used to satisfy this without one, which let the app run signed-in while
    /// every authenticated call failed at the token guard and fell back to canned text.
    private var hasUsableBackendAuth: Bool {
        apiClient.isAuthenticated
    }
    
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
                if isDesignLabMode {
                    #if DEBUG
                    RDesignLab()
                    #endif
                } else if isFirstPodcastFinaleMode {
                    #if DEBUG
                    FirstPodcastFinaleDebugHost()
                    #endif
                } else if isLearningTouchAutoMode {
                    #if DEBUG
                    LearningTouchAutoDemo()
                    #endif
                } else if isLearningTouchMode {
                    #if DEBUG
                    LearningTouchDebugHost()
                    #endif
                } else if isAnimationPreviewMode {
                    AnimationPreviewView()
                } else if isPodcastLayoutDiagnosticsMode {
                    #if DEBUG
                    PodcastLayoutDiagnosticsHost()
                    #endif
                } else {
                // Hidden Screen Time backfill report (runs in background when user enables Screen Time)
                if screenTimeService.isBackfilling, let interval = screenTimeService.currentBackfillDateInterval {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("Total Activity"),
                        filter: DeviceActivityFilter(segment: .daily(during: interval))
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .zIndex(-1)
                }
                
                // Show transparent view when handling stop from widget
                if isProcessingStopFromWidget {
                    LinearColors.Minimal.pureBlack
                        .ignoresSafeArea()
                        .transition(.opacity)
                } else if isCreatingFirstPodcast {
                    FirstPodcastExperience(
                        transcript: firstPodcastTranscript?.processedTranscript
                            ?? firstPodcastTranscript?.originalText ?? "",
                        audioURL: firstPodcastTranscript?.audioFileURL,
                        podcastReady: firstPodcastTranscript != nil,
                        onComplete: { finishFinale() },
                        startAtPaywall: isPreviewingPaywall
                    )
                    .transition(.opacity)
                } else if !hasCompletedOnboarding {
                DarkOnboardingFlow(
                    onComplete: { goals in
                        startFirstPodcastHandoff(extractedGoals: goals)
                    },
                    onPreviewPaywall: {
                        previewPaywall()
                    },
                    onDebugGoHome: {
                        completeOnboardingShell()
                    }
                )
                    .transition(.opacity)
                } else if !hasUsableBackendAuth {
                    // Backend auth gate — user completed onboarding but has no valid JWT
                    BackendAuthGateView(onAuthenticated: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            needsBackendAuth = false
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
                
                if showGoogleAuth && isGoogleConfigured && hasCompletedOnboarding && isAuthenticated && apiClient.isAuthenticated {
                    GoogleAuthView(isPresented: $showGoogleAuth)
                        .transition(.opacity)
                        .zIndex(1)
                }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.5), value: showGoogleAuth)
            .animation(.easeInOut(duration: 0.4), value: isAuthenticated)
            .animation(.easeInOut(duration: 0.4), value: apiClient.isAuthenticated)
            .animation(.easeOut(duration: 0.2), value: isProcessingStopFromWidget)
            .environmentObject(themeManager)
            .environment(platform)
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
                
                // Schedule recurring notifications for existing users
                if hasCompletedOnboarding {
                    PodcastNotificationService.shared.scheduleAllRecurringNotifications()
                }
                
                // Show Google auth if properly configured, not connected, onboarding is complete, and backend-authenticated
                if hasCompletedOnboarding && isAuthenticated && apiClient.isAuthenticated && !googleDocsService.isConnected && isGoogleConfigured {
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
            .fullScreenCover(isPresented: $showFirstPodcastArrival) {
                if let transcript = firstPodcastTranscript {
                    NewPodcastArrivalView(
                        transcript: transcript,
                        onPlay: {
                            showFirstPodcastArrival = false
                            DarkAudioManager.shared.showTranscript(transcript: transcript)
                        },
                        onDismiss: {
                            showFirstPodcastArrival = false
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
                if newValue && hasCompletedOnboarding && apiClient.isAuthenticated && !googleDocsService.isConnected && isGoogleConfigured {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showGoogleAuth = true
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // If recording is active and app goes to background, keep it recording
                if newPhase == .background {
                    print("📱 App moved to background - recording continues")
                    IntegrationBackgroundTasks.schedule()
                }
                
                // Re-check Screen Time auth and refresh data when app becomes active.
                // Delayed refresh gives the hidden DeviceActivityReport time to trigger
                // the extension and write fresh data to the App Group.
                if newPhase == .active {
                    ScreenTimeService.shared.checkAuthorizationStatus()
                    ScreenTimeService.shared.refreshData()
                    IntegrationsSyncService.shared.syncIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        ScreenTimeService.shared.refreshData()
                        IntegrationsSyncService.shared.syncIfNeeded()
                    }
                }
            }
            .onOpenURL { url in
                guard url.scheme == "retrospect" else { return }
                
                if url.host == "start-recording" {
                    print("🎙️ Start recording triggered from Lock Screen control")

                    if hasCompletedOnboarding && isAuthenticated && apiClient.isAuthenticated {
                        shouldStartVoiceRecording = true
                    } else {
                        UserDefaults.standard.set(true, forKey: "shouldStartVoiceRecordingFromShortcut")
                    }
                } else if url.host == "stop-recording" {
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
                } else if url.host == "integration-connected" {
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let values = Dictionary(
                        uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
                            item.value.map { (item.name, $0) }
                        }
                    )
                    NotificationCenter.default.post(
                        name: .integrationConnectionChanged,
                        object: nil,
                        userInfo: values
                    )
                    IntegrationsSyncService.shared.syncIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Helper Methods

    private func startFirstPodcastHandoff(extractedGoals: [RichGoal]) {
        firstPodcastError = nil
        isPreviewingPaywall = false
        isCreatingFirstPodcast = true
        // Onboarding ends the moment the finale starts. The finale branch sits above
        // the onboarding branch in this ladder, so flipping the flag here changes
        // nothing on screen, but it guarantees that every way out of the finale —
        // finishing, dismissing, a failed generation, or the app being killed during
        // the several minutes generation takes — lands on the home screen instead of
        // dropping back into onboarding.
        hasCompletedOnboarding = true

        Task {
            do {
                let transcript = try await firstPodcastOrchestrator.runAfterOnboarding(extractedGoals: extractedGoals)
                await MainActor.run {
                    // Hand the ready episode to the finale. The FirstPodcastExperience
                    // (learning ritual → podcast + paywall → reflection) drives the rest
                    // and calls finishFinale() when the whole sequence is done.
                    firstPodcastTranscript = transcript
                }
            } catch {
                await MainActor.run {
                    firstPodcastError = error.localizedDescription
                    // Couldn't generate — end onboarding gracefully into the app.
                    finishFinale()
                }
            }
        }
    }

    /// Called by FirstPodcastExperience when the end-of-onboarding finale is complete
    /// (podcast finished + reflection, or backed out) → drop into the app.
    private func finishFinale() {
        completeOnboardingShell()
    }

    private func previewPaywall() {
        firstPodcastError = nil
        isPreviewingPaywall = true
        isCreatingFirstPodcast = true
    }

    private func completeOnboardingShell() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
            isAuthenticated = true
            needsBackendAuth = false
            isCreatingFirstPodcast = false
            isPreviewingPaywall = false
        }
    }
    
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
        
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioFileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        let hasUsableAudio = FileManager.default.fileExists(atPath: audioURL.path) && audioFileSize > 1000
        
        guard !trimmed.isEmpty || hasUsableAudio else {
            print("⚠️ Discarding empty voice recording — no transcription and no usable audio")
            return
        }
        
        // Generate simple title from transcription
        var title = "Voice Entry"
        if !trimmed.isEmpty {
            let words = trimmed.split(separator: " ").prefix(10)
            title = words.joined(separator: " ")
            if trimmed.split(separator: " ").count > 10 {
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
            content: trimmed,
            audioURL: FileStorageManager.shared.getAudioURL(for: entryId),
            aiGeneratedTitle: title,
            tags: []
        )
        
        EntryManager.shared.addEntry(entry)
        print("✅ Voice entry saved successfully!")
    }
}

private struct FirstPodcastCreationView: View {
    let status: String
    let errorMessage: String?

    var body: some View {
        RetrospectLoadingScreen(status: status, errorMessage: errorMessage)
    }
}

#if DEBUG
private struct PodcastLayoutDiagnosticsHost: View {
    @State private var showOnboardingLayer = false

    var body: some View {
        Color.red
            .ignoresSafeArea()
            .onAppear { showOnboardingLayer = true }
            .fullScreenCover(isPresented: $showOnboardingLayer) {
                PodcastLayoutDiagnosticsOnboardingLayer()
            }
    }
}

private struct PodcastLayoutDiagnosticsOnboardingLayer: View {
    @State private var showPodcast = false

    var body: some View {
        Color.blue
            .ignoresSafeArea()
            .onAppear { showPodcast = true }
            .fullScreenCover(isPresented: $showPodcast) {
                PodcastPaywallFlow(
                    audioURL: nil,
                    transcript: "There is a version of you that already knows what to do. You have spent the last few weeks moving fast, shipping, and quietly carrying a lot. The body keeps showing up in the data even when you do not mention it.",
                    teaseSeconds: 10_000,
                    diagnosticsEnabled: false
                )
            }
    }
}
#endif
