# Retrospect iOS app: plumbing reference (origin/main)

Snapshot: `origin/main` at `a679fec` (Merge PR #51, ds/c08-segmented), read 2026-10-21.
All paths are relative to `Retrospect/` (the Xcode project folder), i.e. `Retrospect/Retrospect/...` in the repo
unless noted. Line numbers are from origin/main. Nothing was modified; no secrets printed (the Google OAuth client id is
already a public value in Info.plist; team id stated because asked).

Sections
0. Twelve findings that shape the Platform plan
1. RetrospectApp.swift (AppDelegate, state, root ladder, onOpenURL, scenePhase, launch args, injection points)
2. RetrospectAPIClient.swift (config, auth, Keychain, request, decoder, errors, endpoints)
3. ElevenLabsService JWT bridge
4. OnboardingState sign-in gate and keys (AC-1)
5. Entry / EntryManager / FileStorageManager / stale idempotency comment
6. GoalsManager / RichGoal / OnboardingContextManager
7. TranscriptViewModel (init sites, podcasts.json, audio download)
8. SubscriptionManager, PaywallView, PodcastPaywallFlow
9. PodcastNotificationService
10. Live Activities
11. NotificationCenter names and routing/deep-link UserDefaults keys; full key inventory
12. Info.plist, entitlements, background modes, URL schemes, build settings, synchronized groups
13. Package dependencies and .gitignore
14. Tests, scheme TestAction, CI
15. Top-level type names (collision list)
16. DesignV2Switches.swift
17. -DesignLab / RDesignLab / RLabPage

---

## 0. Twelve findings that shape the Platform plan

1. **No composition root exists.** Every service is a `static let shared` singleton; `RetrospectApp` holds them as
   `@StateObject`/`@ObservedObject` (RetrospectApp.swift:69-74) and only injects `themeManager` via `.environmentObject`
   (:242). A `Platform.Environment` can be built as a `@State`/`@StateObject` on `RetrospectApp` and injected with
   `.environment(...)` on the `ZStack` at :147 (alongside :242), and wired from `AppDelegate.didFinishLaunching` (:15-23)
   for anything that must exist before the UI (push delegate, StoreKit `Transaction.updates`, BG tasks).
2. **New files are auto-compiled.** The app target uses a `PBXFileSystemSynchronizedRootGroup` on `Retrospect/`
   (pbxproj :121-129); a new `Retrospect/Retrospect/Platform/` folder joins the app target with no pbxproj edit. Only
   exceptions: `Info.plist` excluded from the app target; `Models/VoiceRecordingActivity.swift` additionally compiled into
   the widget extension (:104-110). Anything Platform wants shared with widgets needs a new membership exception.
3. **Swift 5 mode, no strict concurrency.** App target: `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`, no
   `OTHER_SWIFT_FLAGS`, no `SWIFT_DEFAULT_ACTOR_ISOLATION`, no approachable concurrency (extensions have
   `SWIFT_APPROACHABLE_CONCURRENCY = YES`). App deployment target inherits project **iOS 18.1**; widgets 26.0, ScreenTimeReport 26.2.
   SwiftData/`@Observable`/StoreKit 2/`AppTransaction` are all available at 18.1.
4. **Keychain layout to migrate (exact):** generic password, service `com.retrospect.api`, accounts `jwt_token`,
   `user_id`, `apple_user_id`; no `kSecAttrAccessible`, no access group, no synchronizable flag (so defaults:
   `WhenUnlocked`, app-only). Auth state at launch = token AND user_id present. `currentEmail` is never restored on launch.
   A second reader duplicates the service/account strings in ElevenlabsService.swift:83-84; it must move with the migration.
5. **401 handling is global and destructive**: `request()` on any authenticated 401 calls `signOut()` and
   `OnboardingState.clearSignInGate()` (RetrospectAPIClient.swift:559-567). No refresh exists; `refreshToken()` just signs out (:132-135).
   Sign-in uses no nonce (WelcomeSignInPage.swift:30, AuthenticationScreen.swift:138).
6. **There is no `hasSignedInBefore` flag anywhere.** The only sign-in flag is `onboardingSignedIn` (OnboardingState.swift:127),
   and it is cleared by `clearSignInGate()` (:204-206), by `clearPersistedStep()` (:208-216, called when onboarding
   finishes, DarkOnboardingFlow.swift:65/69 and iMessageOnboardingView.swift:966) and by Replay Onboarding
   (DarkSettingsView.swift:1353). So after onboarding completes it is always gone. AC-1 (signInReturning) needs a new,
   durable flag (Keychain survives reinstall; UserDefaults does not). `apple_user_id` in Keychain is the nearest existing
   signal but `signOut()` deletes it.
7. **Entry upload has no idempotency key and no entry id.** `syncEntryToBackend` sends only `contentType`, `content`,
   `contentDate` (EntryModel.swift:137-141 → RetrospectAPIClient.swift:146-157); failures are only printed, never retried;
   `resyncAllEntriesToBackend` re-posts everything (dupes). The comment at VoiceRecordingView.swift:357-358 claims
   "keyed by the entry id" - false. Only `uploadIntegrationItems` has an idempotency key (SHA-256 of sorted JSON, :172-189).
   The outbox should key on `Entry.id`.
8. **Two local stores with absolute file URLs baked in.** Entries: `Documents/RetrospectData/Entries/<UUID>.json`
   (ISO-8601 dates, sorted keys, `audioURL`/`videoURL`/`imageURLs` stored as absolute `file://` URLs that break when the
   container path changes). Podcasts: `Documents/podcasts.json`, a `[TranscriptModel]` array, written by **every**
   `TranscriptViewModel` instance (11 init sites) with last-writer-wins, and remote/backend audio downloaded into
   `tmp/podcast_<id>.mp3` (purgeable) whose URL is persisted. The GRDB importer must re-resolve paths by id.
9. **Push does not exist.** No `aps-environment` entitlement, no `registerForRemoteNotifications`, no device-token
   delegate. All notifications are local. Notification tap routing posts `ShowPodcastFromNotification` → a fullScreenCover
   whose `onPlay` posts `PlayPodcast`, **which nothing observes** (RetrospectApp.swift:313-317). Observers in `.onAppear`
   (:278-301) are never removed (duplicate on re-appear). Recurring reminders are scheduled at launch before
   `isAuthorized` is known (async), so the guard at PodcastNotificationService.swift:287 usually drops them at launch.
10. **StoreKit is a stub.** `SubscriptionManager` fails closed (`purchase`/`restore` set `lastError`), invariant comment
   forbids compile-time entitlement branches. Prices disagree: SubscriptionManager `$19.99/m` / `$239.99/y` (:24-25) vs
   PaywallView `$12.99` / `$139.99` (PaywallView.swift:160,176). Product ids `com.retrospect.premium.monthly|yearly`
   (PaywallView.swift:485-486). No `.storekit` config file, no StoreKit capability in entitlements (not required for IAP).
11. **Tests are effectively not run.** Scheme TestAction has no `<Testables>` (`shouldAutocreateTestPlan = "YES"`), no
   `.xctestplan` exists, CI only `xcodebuild ... build` (quality.yml) and SwiftLint/SwiftFormat only cover
   `DesignSystemV2` and `Features` (.swiftlint.yml `included`). Unit tests use Swift Testing with
   `@testable import Retrospect` and a TEST_HOST = the app, so tests boot the full app (AppDelegate configures
   SubscriptionManager and registers BG tasks). A `Platform/` folder must be added to `.swiftlint.yml` and the
   swift-quality SwiftFormat path list to be linted.
12. **Package graph has no lock.** Only Google packages (GoogleSignIn-iOS `upToNextMajor 8.0.0`; google-api-objectivec-client
   `branch = main`, unpinned). `Package.resolved` is git-ignored in both `.gitignore` files. Adding GRDB means a third
   XCRemoteSwiftPackageReference; without a committed resolved file, CI builds float.

Also worth knowing: type names `Layout`, `MeshGradient`, `Entry`, `Spacing`, `Animations`, `AudioPlayer`, `APIError`,
`UserProfile`, `SubscriptionPlan`, `SubscriptionManager`, `PodcastPlayback` (protocol) already exist at module top level
(full list in §15); `Layout` and `MeshGradient` shadow SwiftUI types.

---

## 1. RetrospectApp.swift (591 lines)

### 1.1 Imports and AppDelegate (lines 8-48)
Imports: `SwiftUI`, `UIKit`, `UserNotifications`, `DeviceActivity`.

`class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` (:14)
- `application(_:didFinishLaunchingWithOptions:)` :15-23
  ```swift
  UNUserNotificationCenter.current().delegate = self
  SubscriptionManager.shared.configure()
  IntegrationBackgroundTasks.register()
  IntegrationBackgroundTasks.schedule()
  return true
  ```
  (comment :17-18 still mentions RevenueCat, stale.)
- `userNotificationCenter(_:willPresent:withCompletionHandler:)` :26-29 → `completionHandler([.banner, .sound, .badge])`
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` :32-47 → if `userInfo["podcastId"]` and
  `userInfo["type"]` is `"newPodcast"` or `"followUp"`, posts `NSNotification.Name("ShowPodcastFromNotification")`
  with `userInfo: ["podcastId": podcastId]`. Types `weeklyReflection` / `midWeekCheckIn` are ignored on tap.
- Not implemented: `didRegisterForRemoteNotificationsWithDeviceToken`, `didFailToRegister...`, `didReceiveRemoteNotification`,
  scene delegate, `application(_:open:)`, `continue userActivity`.

### 1.2 `@main struct RetrospectApp: App` (:50-549) state
- `@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate` :52
- `@AppStorage("hasCompletedOnboarding") hasCompletedOnboarding = false` :54
- `@AppStorage("useDarkUI") useDarkUI = true` :55 (unused in body)
- `@AppStorage("faceIDEnabled") faceIDEnabled = true` :56
- `@State`: `showGoogleAuth` :57, `shouldStartVoiceRecording` :58, `isProcessingStopFromWidget` :59, `isAuthenticated` :60
  (this is the Face-ID/local unlock flag, NOT backend auth), `showPodcastFromNotification` :61, `notificationPodcastId: String?` :62,
  `needsBackendAuth` :63 (written, never read), `isCreatingFirstPodcast` :64, `isPreviewingPaywall` :65,
  `firstPodcastTranscript: TranscriptModel?` :66, `showFirstPodcastArrival` :67 (never set true), `firstPodcastError: String?` :68
- `@StateObject`: `googleDocsService = GoogleDocsService.shared` :69, `themeManager = ThemeManager.shared` :70,
  `notificationService = PodcastNotificationService.shared` :71, `firstPodcastOrchestrator = FirstPodcastOrchestrator.shared` :72,
  `screenTimeService = ScreenTimeService.shared` :74
- `@ObservedObject apiClient = RetrospectAPIClient.shared` :73
- `@Environment(\.scenePhase) scenePhase` :75

### 1.3 Launch-argument checks (all `#if DEBUG`, else `false`)
| computed property | line | argument |
|---|---|---|
| `isPodcastLayoutDiagnosticsMode` | 77-83 | `-PodcastLayoutDiagnostics` |
| `isDesignLabMode` | 86-92 | `-DesignLab` |
| `isAnimationPreviewMode` | 94-100 | `-AnimationPreview` |
| `isLearningTouchMode` | 102-108 | `-LearningTouch` |
| `isLearningTouchAutoMode` | 110-116 | `-LearningTouchAuto` |
| `isFirstPodcastFinaleMode` | 118-124 | `-FirstPodcastFinale` |
Elsewhere: `-DesignV2Off` (DesignV2Switches.swift:51), `-MockProEntitlement` (SubscriptionManager.swift:34/39),
`-DesignLabPage <page>` and `-devAPIBaseURL <url>` are read as UserDefaults argument-domain keys
(RMotionLab.swift:21, RetrospectAPIClient.swift:20-26).

Other computed: `hasUsableBackendAuth { apiClient.isAuthenticated }` :129-131; `isGoogleConfigured` :133-138 (reads
`GIDClientID` from Info.plist and returns false if it equals the shipped placeholder id, so Google auth overlay is
effectively disabled); `shouldShowSplash { faceIDEnabled && !isAuthenticated && hasCompletedOnboarding }` :141-143.

### 1.4 Root view ladder (`body`, :145-416; `WindowGroup { ZStack { ... } }` :146-147)
Debug branches first:
1. `isDesignLabMode` → `RDesignLab()` (#if DEBUG) :148-151
2. `isFirstPodcastFinaleMode` → `FirstPodcastFinaleDebugHost()` :152-155
3. `isLearningTouchAutoMode` → `LearningTouchAutoDemo()` :156-159
4. `isLearningTouchMode` → `LearningTouchDebugHost()` :160-163
5. `isAnimationPreviewMode` → `AnimationPreviewView()` (not DEBUG-gated) :164-165
6. `isPodcastLayoutDiagnosticsMode` → `PodcastLayoutDiagnosticsHost()` :166-169
7. else (:170-235):
   - Hidden Screen Time `DeviceActivityReport(.init("Total Activity"), filter: .daily(during: interval))` 1x1, opacity 0,
     when `screenTimeService.isBackfilling` :172-181 (always rendered beneath, not part of the if-chain)
   - if-chain:
     a. `isProcessingStopFromWidget` → `LinearColors.Minimal.pureBlack.ignoresSafeArea()` :184-187
     b. `isCreatingFirstPodcast` → `FirstPodcastExperience(transcript:audioURL:podcastReady:onComplete: finishFinale, startAtPaywall: isPreviewingPaywall)` :188-197
     c. `!hasCompletedOnboarding` → `DarkOnboardingFlow(onComplete: startFirstPodcastHandoff, onPreviewPaywall: previewPaywall, onDebugGoHome: completeOnboardingShell)` :198-210
     d. `!hasUsableBackendAuth` → `BackendAuthGateView(onAuthenticated: { needsBackendAuth = false; isAuthenticated = true })` :211-219
     e. `shouldShowSplash` → `DarkSplashScreen(isAuthenticated: $isAuthenticated)` :220-223
     f. else → `DarkAppContainer(shouldStartVoiceRecording: $shouldStartVoiceRecording)` :224-228
   - overlay `GoogleAuthView(isPresented: $showGoogleAuth)` zIndex 1 when `showGoogleAuth && isGoogleConfigured && hasCompletedOnboarding && isAuthenticated && apiClient.isAuthenticated` :230-234

Modifiers on the ZStack (:237-415): `.animation` on hasCompletedOnboarding / showGoogleAuth / isAuthenticated /
apiClient.isAuthenticated / isProcessingStopFromWidget (:237-241), `.environmentObject(themeManager)` :242,
`.animatedThemeTransition()` :243, `.onAppear` :244-302, two `.fullScreenCover`s :303-338, three `.onChange` :339-372,
`.onOpenURL` :373-415.

### 1.5 `.onAppear` (:244-302)
- `if !faceIDEnabled { isAuthenticated = true }` :246-248
- Reads `UserDefaults "shouldStartVoiceRecordingFromShortcut"`; if true, clears it and (if onboarded && isAuthenticated)
  sets `shouldStartVoiceRecording = true` after 0.3s :251-263
- `if hasCompletedOnboarding { PodcastNotificationService.shared.scheduleAllRecurringNotifications() }` :266-268
- Google auth overlay trigger after 1s :271-275
- `NotificationCenter.addObserver(forName: "StartVoiceRecordingFromShortcut")` :278-289 (block, never removed)
- `NotificationCenter.addObserver(forName: "ShowPodcastFromNotification")` :292-301 → sets `notificationPodcastId`,
  `showPodcastFromNotification = true`

### 1.6 fullScreenCovers
- :303-324 `showPodcastFromNotification` → `NewPodcastArrivalView(transcript: findOrCreateTranscript(for:), onPlay: post "PlayPodcast" userInfo ["podcastId"], onDismiss:)`.
  `findOrCreateTranscript` (:475-500) builds a placeholder `TranscriptModel` (never looks up saved podcasts).
- :325-338 `showFirstPodcastArrival` → `NewPodcastArrivalView(... onPlay: DarkAudioManager.shared.showTranscript(transcript:))` (flag never set).

### 1.7 onChange / scenePhase
- `googleDocsService.isConnected` :339-344; `isAuthenticated` :345-352
- `scenePhase` :353-372:
  ```swift
  if newPhase == .background { IntegrationBackgroundTasks.schedule() }
  if newPhase == .active {
      ScreenTimeService.shared.checkAuthorizationStatus()
      ScreenTimeService.shared.refreshData()
      IntegrationsSyncService.shared.syncIfNeeded()
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          ScreenTimeService.shared.refreshData()
          IntegrationsSyncService.shared.syncIfNeeded()
      }
  }
  ```
  This is the natural hook for `outbox.flush()` and `session.validate()` on `.active`.

### 1.8 `.onOpenURL` (:373-415)
`guard url.scheme == "retrospect"` then by `url.host`:
- `start-recording` :376-383 → if onboarded && isAuthenticated && apiClient.isAuthenticated: `shouldStartVoiceRecording = true`,
  else `UserDefaults.set(true, forKey: "shouldStartVoiceRecordingFromShortcut")`
- `stop-recording` :384-400 → `isProcessingStopFromWidget = true`; post `"StopVoiceRecordingFromLiveActivity"`; reset after 1.5s
- `integration-connected` :401-414 → query items to `[String:String]`, post `.integrationConnectionChanged` with that
  userInfo; `IntegrationsSyncService.shared.syncIfNeeded()`
No universal links, no `NSUserActivity`, no other hosts.

### 1.9 Helpers
`startFirstPodcastHandoff(extractedGoals:)` :421-450 (sets `hasCompletedOnboarding = true` immediately at :431, then
`firstPodcastOrchestrator.runAfterOnboarding`); `finishFinale()` :454-456; `previewPaywall()` :458-462;
`completeOnboardingShell()` :464-472; `findOrCreateTranscript` :475-500; `saveVoiceEntry(audioURL:transcription:)` :503-548
(unused private; same logic as StopRecordingIntent). Private views: `FirstPodcastCreationView` :551-558 (unused),
`PodcastLayoutDiagnosticsHost` :561-572, `PodcastLayoutDiagnosticsOnboardingLayer` :574-589 (DEBUG).

### 1.10 Where a `Platform.Environment` goes
- Build: a new `@State private var platform = Platform.Environment.live()` (or `@StateObject`) beside :69-74; or
  `AppDelegate` owns it and the App reads `appDelegate.platform` (AppDelegate is created first, so things needing
  launch-time setup — UNUserNotificationCenter delegate, `registerForRemoteNotifications`, `Transaction.updates` listener,
  BG task registration — fit in `didFinishLaunching` :15-23).
- Inject: on the ZStack next to `.environmentObject(themeManager)` (:242), e.g. `.environment(platform)`. Note the
  fullScreenCovers (:303, :325) are attached after :242 so they inherit it.
- Route: `.onOpenURL` (:373) and the AppDelegate tap handler (:32-47) are the two inputs for a typed router;
  `scenePhase` onChange (:353) for lifecycle hooks.

---

## 2. RetrospectAPIClient.swift (836 lines)

### 2.1 Class, config, state
```swift
class RetrospectAPIClient: ObservableObject {          // :9  (not @MainActor, not final)
    static let shared = RetrospectAPIClient()          // :10
    static let productionBaseURL = "https://retrospect-api.onrender.com"   // :13
    #if DEBUG
    static let devBaseURLKey = "devAPIBaseURL"         // :20  (launch arg -devAPIBaseURL http://localhost:3000)
    private let baseURL: String = { UserDefaults override, else productionBaseURL }()  // :22-26
    #else
    private let baseURL = RetrospectAPIClient.productionBaseURL                         // :28
    #endif
    @Published var isAuthenticated: Bool = false       // :31
    @Published var currentUserId: String?              // :32
    @Published var currentEmail: String?               // :33
    private let session: URLSession                    // :35
    private let keychainService = "com.retrospect.api" // :36
    private let tokenKey = "jwt_token"                  // :37
    private let userIdKey = "user_id"                  // :38
    private let appleUserIdKey = "apple_user_id"       // :39
```
`private init()` :41-53: `URLSessionConfiguration.default`, `timeoutIntervalForRequest = 480`, `timeoutIntervalForResource = 600`;
restores: `if readKeychain(tokenKey) != nil, let userId = readKeychain(userIdKey) { isAuthenticated = true; currentUserId = userId }`.
(Email is not restored.)

### 2.2 signIn (:59-82)
```swift
func signIn(appleUserId: String, email: String? = nil, identityToken: String? = nil) async throws -> (userId: String, email: String?)
```
Request: `POST /auth/signin`, unauthenticated, JSON body `{"appleUserId": String, "email"?: String, "identityToken"?: String}`.
Response `SignInResponse` (:639-653): `{ success: Bool, data?: { token: String, user: { id: String, email: String? } }, error?: String }`
(decoded with `convertFromSnakeCase`). On `!success || data == nil` → `APIError.authFailed(error ?? "Unknown error")`.
Then `saveKeychain(tokenKey, data.token)`, `saveKeychain(userIdKey, data.user.id)`, `saveKeychain(appleUserIdKey, appleUserId)`,
then on MainActor sets the three published properties.
Callers: WelcomeSignInPage.swift:~199 (then `state.markSignedIn()` :207), BackendAuthGateView.swift:109 (then `onAuthenticated()` :116).

DEBUG `signInAsDevTestUser()` :92-114: `POST /auth/dev/test-user` body `{}` unauthenticated; same response; saves token+user_id, **deletes** `apple_user_id`.
Callers: WelcomeSignInPage.swift:~229 (+ `OnboardingContextManager.shared.resetForFreshOnboarding()`, `state.markSignedIn()` :242), BackendAuthGateView.swift:136.

### 2.3 signOut (:118-128) / refreshToken (:132-135)
```swift
func signOut() {
    deleteKeychain(key: tokenKey)
    deleteKeychain(key: userIdKey)
    deleteKeychain(key: appleUserIdKey)
    DispatchQueue.main.async { self.isAuthenticated = false; self.currentUserId = nil; self.currentEmail = nil }
}
func refreshToken() async throws {
    signOut()
    throw APIError.authFailed("Please sign in with Apple again")
}
```
Callers of signOut: request() 401 path (:560), DarkSettingsView.swift:283 inside `fullSignOut(wipeOnboarding:)` :278-284
(which first calls `OnboardingContextManager.shared.resetForFreshOnboarding()` if wiping, then `OnboardingState.clearSignInGate()`);
buttons at DarkSettingsView.swift:155 ("Log Out") and :161 ("Wipe & Log Out"). Server-side logout endpoint: none called.

### 2.4 Endpoints (all through `request`)
| method | path | body / notes | line |
|---|---|---|---|
| POST | /content | `contentType`, `content`, `contentDate?` (ISO8601DateFormatter, no fractional), `metadata?` → `GenericResponse` | 140-158 |
| POST | /integrations/{id}/device-batches (native: healthkit, screen_time, calendar, apple_music, photos, contacts) or /integrations/{id}/items | `idempotencyKey: "ios:<sha256 of sortedKeys JSON of providerId,runType,cursorBefore,cursorAfter,items>"`, `runType`, `cursorBefore`, `cursorAfter`, `items` | 163-191 |
| POST | /integrations/{id}/connect/start | `{}` → `authorizationUrl` | 193-202 |
| POST | /integrations/{id}/imports, PUT signed URL, POST /integrations/imports/{importId}/complete `{sha256}` | archive import | 210-239 |
| POST | /integrations/{id}/assets, PUT signed URL, POST /integrations/assets/{assetId}/complete | asset upload | 241-276 |
| GET | /integrations | `[BackendIntegrationCatalogItem]` | 278-284 |
| POST | /integrations/connections/{id}/sync | | 286-291 |
| DELETE | /integrations/connections/{id} and /…/{id}/data | | 293-299 |
| GET/POST/PATCH | /goals, /goals/{id} (`isActive`) | syncRichGoals | 305-369 |
| POST | /goals/{serverId}/decline | | 373-375 |
| POST | /goals/extract-and-save, /goals/synthesize | `{text}` | 386-419 |
| PATCH | /profile/persona | `{persona}` | 424-429 |
| GET | /profile | `UserProfile` | 432-438 |
| GET | /podcasts?limit=&offset=, /podcasts/latest, /podcasts/{id} | `PodcastEpisode` | 443-460 |
| POST | /podcasts/generate | `daysSince`, `generationSource?` | 463-477 |
| POST | /claude/generate | `maxTokens`, `systemPrompt?`, `userMessage?`, `messages?` | 482-497 |
| GET | /pipeline/insights?limit=&goalId= | | 502-507 |

### 2.5 Generic request (:511-576), verbatim core
```swift
private func get<T: Decodable>(path: String) async throws -> T { try await request(method: "GET", path: path, body: nil) }
private func post<T: Decodable>(path: String, body: [String: Any], authenticated: Bool = true) async throws -> T { ... }
private func patch<T: Decodable>(path: String, body: [String: Any]) async throws -> T { ... }
private func delete<T: Decodable>(path: String) async throws -> T { ... }

private func request<T: Decodable>(method: String, path: String, body: [String: Any]?, authenticated: Bool = true) async throws -> T {
    guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let body = body {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if authenticated {
        guard let token = readKeychain(key: tokenKey) else { throw APIError.notAuthenticated }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, httpResponse) = try await session.data(for: request)
    guard let response = httpResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
    if response.statusCode == 401 && authenticated {
        signOut()
        OnboardingState.clearSignInGate()
        throw APIError.authFailed("Please sign in with Apple again")
    }
    guard (200...299).contains(response.statusCode) else {
        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
        throw APIError.serverError("HTTP \(response.statusCode): \(errorBody)")
    }
    return try JSONDecoder.apiDecoder.decode(T.self, from: data)
}
```
No retries, no request id, no idempotency header (only the body field for integration items), no User-Agent/app-version header.
Bodies are `[String: Any]` via JSONSerialization (not Encodable).

### 2.6 Keychain helpers (:580-615), verbatim
```swift
private func saveKeychain(key: String, value: String) {
    let data = Data(value.utf8)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
    var addQuery = query
    addQuery[kSecValueData as String] = data
    SecItemAdd(addQuery as CFDictionary, nil)
}

private func readKeychain(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}

private func deleteKeychain(key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
}
```
Migration notes: values are UTF-8 strings; no `kSecAttrAccessible` (system default `kSecAttrAccessibleWhenUnlocked`) — a
BG-task/outbox flush while the device is locked cannot read the JWT; moving to `AfterFirstUnlockThisDeviceOnly` needs an
update (`SecItemUpdate` with the new accessibility) or delete+add. Return statuses are ignored.

### 2.7 apiDecoder (:818-836) and APIError (:619-635)
```swift
extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
}

enum APIError: LocalizedError {
    case invalidURL, invalidResponse, notAuthenticated
    case authFailed(String)
    case serverError(String)
    // errorDescription: "Invalid URL" / "Invalid response from server" / "Not authenticated" /
    // "Authentication failed: \(msg)" / "Server error: \(msg)"
}
```
`JSONDecoder.apiDecoder` is a module-wide extension name; a new client should not redeclare it. `APIError` is a top-level
module name (collision risk).

Response envelope convention: `{ success: Bool, data?: T, error?: String }` (+ `processingNotes` for goal extraction).
Private response structs (:639-788): SignInResponse, RefreshResponse (unused), GenericResponse, OAuthStartResponse,
ImportStartResponse, AssetStartResponse, IntegrationsResponse, GoalsListResponse, GoalSingleResponse, PodcastListResponse,
PodcastSingleResponse, ClaudeProxyResponse, InsightsListResponse, ProfileResponse, GoalExtractionAPIResponse.
Public: BackendIntegrationCatalogItem :711, BackendIntegrationConnection :720, ExtractedGoalFromBackend :790,
GoalExtractionResponse :796, UserProfile :803 (`id, email?, voicePersona?, createdAt: Date, availablePersonas?`),
VoicePersonaOption :811. Backend models (PodcastEpisode, BackendGoal, BackendInsight, BackendObservation, AnyCodable, …)
live in Models/BackendModels.swift.

---

## 3. ElevenlabsService.swift — the JWT bridge
File `Services/ElevenlabsService.swift`, class `ElevenLabsService` (:6), `static let shared` (:7), own URLSession
(timeout 300/600, :11-16). `POST {baseURL}/speech/synthesize`, headers Content-Type json, `Accept: audio/mpeg`,
`Authorization: Bearer <jwt>` (:33-47), body `{"text": text}`; writes mp3 to `Documents/reflection_<epoch>.mp3` (:22-24).
On non-2xx it does NOT sign out (no 401 handling).

Base URL (:71-79) mirrors the client: DEBUG reads `RetrospectAPIClient.devBaseURLKey`, else `RetrospectAPIClient.productionBaseURL`.

JWT read, verbatim (:81-101):
```swift
/// These must stay identical to the Keychain identifiers `RetrospectAPIClient`
/// stores the backend JWT under; its own copies are private.
private static let keychainService = "com.retrospect.api"
private static let keychainTokenKey = "jwt_token"

private static func authToken() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainTokenKey,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
```
`ElevenLabsError`: `invalidURL`, `notAuthenticated`, `audioGenerationFailed` (:104-). No other file reads the Keychain
(grep for `kSec` across app/widgets/ScreenTimeReport: only these two files).

---

## 4. OnboardingState.swift (359 lines) — sign-in gate

`final class OnboardingState: ObservableObject` (:45), owned as `@StateObject` by DarkOnboardingFlow. Published gate
flags :49-54: `hasSignedIn`, `questionsCompleted`, `privacyAcknowledged`, `integrationsCompleted`, `personaCompleted`, `userName`.

UserDefaults keys (:126-132, all `private static`):
| constant | key |
|---|---|
| persistedStepKey | `onboardingCurrentStep` (Int, 1-4; legacy 9/6-step values remapped in restoreFromDisk :183-197) |
| signedInKey | `onboardingSignedIn` |
| questionsCompletedKey | `onboardingQuestionsCompleted` |
| userNameKey | `onboardingUserName` |
| privacyAcknowledgedKey | `onboardingPrivacyAcknowledged` |
| integrationsCompletedKey | `onboardingIntegrationsCompleted` |
| personaCompletedKey | `onboardingPersonaCompleted` |

Writers: `markSignedIn()` :134-139 (sets `onboardingSignedIn = true`, phase `.integrations`, persists step),
`markQuestionsCompleted(name:)` :141-148, `markPrivacyAcknowledged()` :150-153, `markIntegrationsCompleted()` :155-158,
`markPersonaCompleted()` :160-163, `persistPhase()` :165-167. `restoreFromDisk()` :169-198 (called from init :120-122).

```swift
static func clearSignInGate() {                       // :204-206
    UserDefaults.standard.removeObject(forKey: signedInKey)
}
func clearPersistedStep() {                           // :208-216 removes ALL seven keys above
```
Callers: `clearSignInGate` → RetrospectAPIClient.swift:566 (401), DarkSettingsView.swift:282 (fullSignOut).
`clearPersistedStep` → DarkOnboardingFlow.swift:65 and :69 (closing page onPlay/onPreviewPaywall),
iMessageOnboardingView.swift:966 (completeOnboarding). Literal-key duplicates (bypass the constants):
DarkSettingsView.swift:1352-1354 Replay Onboarding sets `onboardingCurrentStep = 1`, removes `onboardingSignedIn`,
`onboardingIntegrationsCompleted`.

`hasSignedInBefore` / `hasEverSignedIn` / similar: **does not exist** (grep: no matches). Related app-level keys:
`hasCompletedOnboarding` (@AppStorage RetrospectApp.swift:54; reset to false by
`OnboardingContextManager.resetForFreshOnboarding()` GoalsManager.swift:136), `onboarding_first_podcast_generated`
(GoalsManager.swift:115), `faceIDEnabled`, `lastSuccessfulAuth` (SplashScreen). For AC-1 a returning-user signal must be
new; Keychain `apple_user_id` is removed by `signOut()`, so it is not durable either.

---

## 5. Entries

### 5.1 Model (Models/EntryModel.swift)
`enum EntryType: String, Codable { case text, video, voice }` (:4-17); `backendContentType`: text→`text_entry`,
voice→`voice_recording`, video→`video_entry`.

`struct Entry: Codable, Identifiable, Hashable` (:20-95), **no custom CodingKeys** (JSON keys = property names):
`id: UUID`, `date: Date`, `type: EntryType`, `content: String`, `videoURL: URL?`, `audioURL: URL?`, `imageURLs: [URL]?`,
`aiGeneratedTitle: String?` (var), `tags: [String]` (var), `isIncludedInInsights: Bool` (var). Init defaults: id UUID(),
date Date(), tags [], isIncludedInInsights true. Computed: `displayTitle`, `hasValidContent` (text needs text; voice/video
need text or an existing file), `contentPreview`.

### 5.2 EntryManager (`@MainActor class EntryManager: ObservableObject`, :98)
`@Published var entries: [Entry]`, `static let shared`, `init()` loads (internal init, not private).
```swift
func addEntry(_ entry: Entry) {                                        // :111-123
    guard entry.hasValidContent else { print(...); return }
    entries.append(entry)
    saveEntry(entry)
    print(...)
    // Sync to backend (non-blocking)
    syncEntryToBackend(entry)
}

/// Upload an entry to the Retrospect backend for the observation/insight pipeline.
private func syncEntryToBackend(_ entry: Entry) {                     // :126-147
    guard RetrospectAPIClient.shared.isAuthenticated else {
        print("⚠️ Skipping backend sync — not authenticated")
        return
    }
    guard !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        print("⚠️ Skipping backend sync — empty content for \(entry.id)")
        return
    }
    Task {
        do {
            try await RetrospectAPIClient.shared.uploadContent(
                contentType: entry.type.backendContentType,
                content: entry.content,
                contentDate: entry.date
            )
            print("✅ Entry \(entry.id) synced to backend as '\(entry.type.backendContentType)'")
        } catch {
            print("❌ Entry sync failed for \(entry.id): \(error.localizedDescription)")
        }
    }
}
```
`resyncAllEntriesToBackend()` :151-182: same guard, filters non-empty content, sequentially calls `uploadContent` with the
same three fields, 200 ms sleep between, counts success/fail; called only from DarkSettingsView.swift:1271 (dev button).
No sync state is stored on the entry (no `syncedAt`/`serverId`); failed uploads are lost; resync duplicates.

**/content body sent for entries:** `{"contentType": "text_entry"|"voice_recording"|"video_entry", "content": <text>, "contentDate": "<ISO8601 no fractional>"}` — no id, no metadata, no audio/image.
Other `/content` callers: GoalsManager.swift:201 (`onboarding_profile` + metadata), DarkAppContainer.swift:1154
(`onboarding_profile`, dev), Transcriptviewmodel.swift:551 (`journal_entry`, metadata source `ios_manual_reflection`).

`addEntry` call sites: RetrospectApp.swift:546 (unused helper), VideoJournalViewModel.swift:167,182,
StopRecordingIntent.swift:88, DarkVoiceRecordingView.swift:279, FirstPodcastExperience.swift:111, HomeScreen.swift:953,968,1016,1031,
DarkAppContainer.swift:1130 (text journal composer), VoiceRecordingView.swift:354,374, AttachmentPickerSheet.swift:220.
Other mutators: `updateEntry` :196, `deleteEntry(withId:)` :204 (local only, no backend delete), `deleteEntries` :215,
`toggleInclusionStatus` :229 (local only), `clearAllEntries` :256.

### 5.3 FileStorageManager (Services/FileStorageManager.swift, `class`, `private init`)
Paths (:12-38):
- `Documents/RetrospectData/` root
- `…/Entries/<UUID>.json` (entry), `<UUID>.txt` (text content copy), `<UUID>_transcript.txt` (voice content copy)
- `…/Videos/<UUID>.mov`, `…/Audios/<UUID>.m4a`, `…/Images/<UUID>_<index>.jpg`
- `…/index.json`
Encoding (:68-73): `JSONEncoder`, `.iso8601` dates, `[.prettyPrinted, .sortedKeys]`. Decode `.iso8601` (:102-105, :120-122).
`loadAllEntries()` enumerates `*.json` in Entries (sorted newest first). **Every `saveEntry` calls `updateIndex()` which
re-reads and decodes all entries** (:354-368), O(n) per write.

`index.json` format (private `EntryIndex`, :348-352), encoder `.iso8601`, `.prettyPrinted`:
```json
{ "lastUpdated": "2026-10-21T10:00:00Z", "entryCount": 12, "entryIds": ["UUID", "..."] }
```
Migration (:372-436): one-time from UserDefaults `unifiedEntries` (Data, default JSONDecoder) guarded by
`hasCompletedFileStorageMigration`. Media helpers: `getAudioURL(for:)` :204, `moveAudio(from:to:)` :209, `getVideoURL` :177,
`moveVideo` :182, `saveImages(for:images:)` :231, `deleteEntry(id:)` :134-175. `StorageInfo` struct :501.

### 5.4 Stale idempotency comment
`Views/VoiceRecordingView.swift:357-358`:
```swift
// addEntry uploads it (as voice_recording, keyed by the entry id). A second
// upload here as voice_journal used to write every voice note twice.
```
"keyed by the entry id" is false: `uploadContent` sends no id or idempotency key.

---

## 6. Goals (Models/GoalsManager.swift)

`struct RichGoal: Codable, Identifiable, Equatable` (:259-303): `id: UUID`, `serverId: String?`, `title`, `goalDescription`,
`motivation`, `category` (default "Other"), `actionItems: [String]`, `createdAt: Date`. `hasDepth`, `backendDescription`
(description + "Why: …" + "Next steps: a; b").

`class GoalsManager: ObservableObject` (:307, not @MainActor), `static let shared`, `private init` → `loadGoals()`.
`@Published var richGoals: [RichGoal]`. Keys: `rich_goals` (Data, **default JSONEncoder → Date as Double since 2001**,
written on a background queue :420-427), `simple_goals` (legacy [String], migrated then removed :462-470),
`onboarding_profile_context` (String, `static let onboardingProfileContextKey`).

Every mutation (`addRichGoal`, `addRichGoals`, `removeRichGoal`, `addGoal`, `removeGoal(at:)`, `removeGoal(_:)`,
`clearAllGoals`, `importGoals`) → `saveGoals()` = `persistLocally()` + `syncToBackend()` (:415-418).

`syncToBackend()` (:429-441): if authenticated, snapshot → `RetrospectAPIClient.shared.syncRichGoals(snapshot)` →
`applyServerIds` on MainActor (persists without re-sync). Logic of `syncRichGoals` (RetrospectAPIClient.swift:314-369):
GET /goals; index server goals by id and by normalized title (active wins); for each local goal match by `serverId` else
title; no match → POST /goals `{title, description: backendDescription}` and record id; match without local serverId →
record; match inactive → PATCH `{isActive: true}`; if local list non-empty, PATCH `{isActive:false}` every active server
goal not matched. Returns `[localUUID: serverId]`. Fire-and-forget, no retry, concurrent syncs can interleave.
`declineGoal(serverId:)` POST /goals/{id}/decline.

Same file: `OnboardingAnswer`, `OnboardingIntegrationsSnapshot`, `OnboardingPodcastContext`,
`@MainActor final class OnboardingContextManager` (:108) with keys `onboarding_podcast_context` (Data, ISO-8601),
`onboarding_first_podcast_generated` (Bool), reads `voice_persona`, `healthKitEnabled`; `resetForFreshOnboarding()`
(:132-139) removes those + `onboarding_profile_context`, sets `hasCompletedOnboarding = false`, clears goals (which syncs
an empty list - guarded server-side by the non-empty check, so no deactivation).

---

## 7. TranscriptViewModel (ViewModels/Transcriptviewmodel.swift, 1273 lines)

`class TranscriptViewModel: ObservableObject` (:54), not a singleton, not @MainActor. Init (:110-123):
`init(openAIService: OpenAIService, textToSpeechService: TextToSpeechService, elevenLabsService: ElevenLabsService = .shared, googleDocsService: GoogleDocsService = .shared)`
→ `loadSavedPodcasts()` which reads disk and then `fetchBackendPodcasts()` (network GET /podcasts on every construction).

Init sites (all `TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)`):
| file:line | form |
|---|---|
| Views/DarkAppContainer.swift:142 | @StateObject (the live app) |
| Views/DarkSettingsView.swift:1201 | @StateObject |
| Views/DarkPodcastsView.swift:540 | inline argument |
| Views/OptimizedHomeScreen.swift:9 | @StateObject |
| Views/HomeScreen.swift:20 and :1412 | @StateObject |
| Views/PolaroidHomeView.swift:8 | @StateObject |
| Views/Components/PolaroidPlayingControls.swift:237 | inline argument |
| Views/Components/TransformingLoadingPill.swift:204 | `let vm =` (preview) |
| Views/Components/DarkLoadingPill.swift:100 | preview |
| Services/FirstPodcastOrchestrator.swift:60 | `let persistenceViewModel = …; persistenceViewModel.savePodcast(transcript)` |

podcasts.json: `Documents/podcasts.json` (:91-94). `private static let podcastsKey = "saved_podcasts"` (:89, unused
legacy). Format: JSON array of `TranscriptModel`, `JSONEncoder` with `.iso8601`, default formatting (:155-165);
decode `.iso8601` (:167-191). `TranscriptModel` (Models/TranscriptModel.swift:41-) fields: `id: UUID`, `originalText`,
`goals: [String]`, `processedTranscript?`, `audioFileURL: URL?`, `mood?`, `generationType: GenerationType?`
(`good_listener`/`growth_mentor`), `googleDocsInfo?`, `isDeepResearch` (default false), `citations: [Citation]?`,
`researchQueries?`, `createdAt` (default Date()), `backendEpisodeId?`, `insightIds?`. Equatable on id+createdAt.
`savePodcast` inserts at 0 or replaces by id (:127-141). `fetchBackendPodcasts` (:196-225) merges backend episodes by
id (`UUID(uuidString: episode.id)`) into memory only (does not persist until next save); `PodcastEpisode.toTranscriptModel()`
(BackendModels.swift:69-96) stores the **remote** `audioUrl` as `audioFileURL`.

Audio download (:605-618), used after `generatePodcast` (:570-582):
```swift
let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("podcast_\(id).mp3")
try? FileManager.default.removeItem(at: localURL)
try FileManager.default.moveItem(at: tempURL, to: localURL)
```
i.e. `tmp/podcast_<episodeId>.mp3`, persisted into podcasts.json as an absolute path. ElevenLabs output:
`Documents/reflection_<epoch>.mp3`. FirstPodcastOrchestrator saves the episode with its remote URL (no download).

---

## 8. Subscriptions

### 8.1 Services/SubscriptionManager.swift (52 lines) header, verbatim (:1-18)
```swift
import Foundation
import SwiftUI

// SubscriptionPlan (.monthly / .yearly) is defined in PaywallView.swift.

/// Subscription entitlement.
///
/// INVARIANT: `isSubscribed` may only become true from a StoreKit transaction that
/// the backend has validated. No purchase path exists yet, so `purchase` and
/// `restore` fail closed with a visible error rather than granting Pro. The only
/// other writer is a `#if DEBUG` launch-argument override, which cannot compile
/// into Release.
///
/// A previous version wrapped a RevenueCat implementation in `#if canImport(RevenueCat)`
/// with a mock `#else` branch. The SDK was never added to the package graph, so the
/// mock was the branch that compiled in every configuration — including Release —
/// and it granted the entitlement unconditionally. Do not reintroduce a
/// compile-time guard that can silently select an entitlement-granting branch.
```
Public API (`@MainActor final class SubscriptionManager: ObservableObject`, :19-52):
- `static let shared`
- `@Published private(set) var isSubscribed = false` :23
- `@Published var monthlyPriceString = "$19.99/m"` :24, `@Published var yearlyPriceString = "$239.99/y"` :25
- `@Published private(set) var isPurchasing = false` :26 (never set)
- `@Published var lastError: String?` :27
- `private static let unavailableMessage = "Subscriptions aren't available in this build yet. You have not been charged."` :29-30
- `#if DEBUG static let mockEntitlementArgument = "-MockProEntitlement"` :33-35
- `func configure()` :37-43 (DEBUG arg sets isSubscribed); called from AppDelegate :19
- `func purchase(_ plan: SubscriptionPlan) async` :45-47 → `lastError = unavailableMessage`
- `func restore() async` :49-51 → same

### 8.2 PaywallView (Views/Components/PaywallView.swift)
Used only from AdvancedSettingsView.swift:149. Selected plan default `.yearly` (:12). Prices:
- :158-163 `PricingCard(plan: .yearly, title: "Yearly", price: "$139.99", period: "per year", savings: "Save 7%", …)`
- :174-179 `PricingCard(plan: .monthly, title: "Monthly", price: "$12.99", period: "per month", savings: nil, …)`
- `startSubscription()` :262-274 is a TODO that spins 2 s and does nothing (does not call SubscriptionManager).
- `enum SubscriptionPlan: String, CaseIterable { case monthly = "monthly", yearly = "yearly" }` :479-489,
  `identifier`: `com.retrospect.premium.monthly` / `com.retrospect.premium.yearly`.

### 8.3 PodcastPaywallFlow (Views/PodcastPaywallFlow.swift)
`struct PodcastPaywallFlow: View` (:48) params: `audioURL`, `transcript`, `teaseSeconds = 10`, `onClose`, `onFinished`,
`diagnosticsEnabled`, `usesTransparentBackground`, `startWithPaywall`, `onDebugGoHome`.
- :60 `@ObservedObject private var subs = SubscriptionManager.shared`
- :151-156 `.onChange(of: subs.isSubscribed)` → hide paywall, resume playback
- :160-169 `.alert("Subscription Unavailable", isPresented: Binding(get: { subs.lastError != nil }, …))`
- :208 tease guard `!subs.isSubscribed`
- :711 `bluePriceButton(subs.monthlyPriceString) { Task { await subs.purchase(.monthly) } }`
- :712 `creamPriceButton(subs.yearlyPriceString) { Task { await subs.purchase(.yearly) } }`
- :718 `Button("Restore") { Task { await subs.restore() } }`; "Privacy notice" button empty.
Usage sites: FirstPodcastExperience.swift:56 (onboarding finale), VoiceGoalsPage.swift:261 (teaseSeconds 40,
prefetched episode), RetrospectApp.swift:582 (DEBUG diagnostics, teaseSeconds 10_000).

---

## 9. PodcastNotificationService (Services/PodcastNotificationService.swift, 322 lines)
`@MainActor class PodcastNotificationService: ObservableObject`, `static let shared`, `private init` → `checkAuthorizationStatus()` (async callback).
- `@Published var isAuthorized`, `@Published var pendingNotification: PodcastNotification?`
- `requestAuthorization() async -> Bool` :25-38, options `[.alert, .sound, .badge]`. Call sites:
  iMessageOnboardingView.swift:970 (completeOnboarding → then `scheduleAllRecurringNotifications()` :972),
  VoiceGoalsPage.swift:1326-1327, DarkSettingsView.swift:1588 (settings toggle).
- No `UNNotificationCategory` / `setNotificationCategories` / actions anywhere. No `categoryIdentifier`, no thread ids.
- Requests:
  | identifier | trigger | userInfo | line |
  |---|---|---|---|
  | `podcast-<podcastId>` | nil (immediate), badge 1 | `podcastId`, `type: "newPodcast"` | 50-83 (only caller DarkSettingsView.swift:1652, dev) |
  | `podcast-followup-<podcastId>-<delayHours>` | UNTimeInterval delayHours*3600 | `podcastId`, `type: "followUp"` | 87-114 (no callers) |
  | `weekly-reflection-reminder` | calendar weekday 1 (Sunday) 10:00 repeats | `type: "weeklyReflection"` | 218-249 |
  | `midweek-checkin` | calendar weekday 4 (Wednesday) 20:00 repeats | `type: "midWeekCheckIn"` | 252-283 |
- `scheduleAllRecurringNotifications()` :286-290 `guard isAuthorized` then the two calendar ones; called from
  RetrospectApp.swift:267 (every launch, onAppear), iMessageOnboardingView.swift:972, VoiceGoalsPage.swift:1327.
- `cancelRecurringNotifications()` :293-298; `clearPendingNotification()` :302-305; `clearAllNotifications()` :307-312.
- `struct PodcastNotification: Identifiable { id, title, hook, timestamp }` :316-321.
- Copy strings use emoji ("You have a new podcast ready 🎧", "Still haven't listened? 👀").

---

## 10. Live Activities
- `VoiceRecordingAttributes: ActivityAttributes` — Models/VoiceRecordingActivity.swift:7 (`public`, `@available(iOS 16.1, *)`):
  static `startTime: Date`; `ContentState { recordingDuration: TimeInterval; isRecording: Bool }`. Compiled into both the app
  and the widget extension (pbxproj membership exception :104-110).
- `AudioPlaybackAttributes: ActivityAttributes` — Models/AudioPlaybackAttributes.swift:4: no static attrs;
  `ContentState { title: String; currentTime: TimeInterval; duration: TimeInterval; isPlaying: Bool }`. **Never requested**;
  its widget `AudioPlaybackLiveActivity` (Views/AudioPlaybackLiveActivity.swift:5) is in the app target, not in any bundle.
- Started: `AudioRecordingManager.swift:358-362` and `BackgroundAudioRecordingManager.swift:351-355`:
  `Activity.request(attributes: VoiceRecordingAttributes(startTime: Date()), content: .init(state:…, staleDate: nil), pushType: nil)`.
  **pushType is `nil` in both** (no push-to-start/update). Ended with `.end(..., dismissalPolicy: .immediate)` (:397 / :389).
  Guarded by `ActivityAuthorizationInfo().areActivitiesEnabled`.
- Widgets: `RetrospectWidgets/RetrospectWidgetsLiveActivity.swift:8` `VoiceRecordingLiveActivityWidget` (in the bundle,
  RetrospectWidgetsBundle.swift:19, iOS 16.2+) and a duplicate same-named struct in the app target
  `Retrospect/Widgets/VoiceRecordingLiveActivityWidget.swift:7` (different module, unused). Both link
  `retrospect://stop-recording` (:31, :84). Control widget `RetrospectWidgetsControl` kind
  `com.shauryanarang.Retrospect.startVoiceNote`, `OpenURLIntent(retrospect://start-recording)` (RetrospectWidgetsControl.swift:15-18).
- `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (app target). No `NSSupportsLiveActivitiesFrequentUpdates`.

---

## 11. Routing: NotificationCenter names and UserDefaults keys

### 11.1 Custom notification names
| name | declared | posted | observed |
|---|---|---|---|
| `"ShowPodcastFromNotification"` (string literal) | — | RetrospectApp.swift:39-43 (AppDelegate didReceive) | RetrospectApp.swift:292-301 (onAppear addObserver, never removed) |
| `"PlayPodcast"` | — | RetrospectApp.swift:313-317 (NewPodcastArrivalView onPlay) | **none** (comment claims DarkAppContainer handles it; grep finds no observer) |
| `"StartVoiceRecordingFromShortcut"` | — | AppIntents/StartVoiceRecordingIntent.swift:28-31 | RetrospectApp.swift:278-289 |
| `"StopVoiceRecordingFromLiveActivity"` | — | RetrospectApp.swift:392-395 (onOpenURL stop-recording) | Views/DarkVoiceRecordingView.swift:55, Views/VoiceRecordingView.swift:53 (`.onReceive`) |
| `.integrationConnectionChanged` = `"IntegrationConnectionChanged"` | Models/IntegrationCatalog.swift:3-4 | RetrospectApp.swift:408-412 (userInfo = URL query items) | Views/IntegrationsDataView.swift:65, Views/IntegrationsSetupPage.swift:81 |
| `.recordingDidFinish` = `"CameraViewModel.recordingDidFinish"` | ViewModels/CameraViewModel.swift:261 | CameraViewModel.swift:183 | (none found outside) |
| `.recordingDidFail` = `"CameraViewModel.recordingDidFail"` | CameraViewModel.swift:262 | CameraViewModel.swift:190 | (none found outside) |
System observers (keyboard, AVPlayerItem) exist in DarkGoalsView:205/217, DarkEntriesView:144/156, DarkAppContainer:1196/1208, VideoLogView:85, PodcastPlayer:128, AudioPlayerContainer:72 — not routing.

### 11.2 Routing / deep-link UserDefaults keys
| key | written | read |
|---|---|---|
| `shouldStartVoiceRecordingFromShortcut` (Bool) | StartVoiceRecordingIntent.swift:24; RetrospectApp.swift:382 (onOpenURL when not ready) | RetrospectApp.swift:251-253 (onAppear, cleared), :284 (cleared in observer) |
| `hasCompletedOnboarding` (@AppStorage) | RetrospectApp.swift:431,466; GoalsManager.swift:136 | RetrospectApp ladder |
| `faceIDEnabled` (@AppStorage, default true) | settings | RetrospectApp.swift:56,142,246; SplashScreenView.swift:25 |
| `DesignLabPage` (String) | launch arg | RMotionLab.swift:21 |
| `designV2.<code>` (Bool) | debug | DesignV2Switches.swift:54 |
| `devAPIBaseURL` | launch arg | RetrospectAPIClient.swift:23, ElevenlabsService.swift:73 |
Bundle id / BG ids: `com.shauryanarang.Retrospect.integrations.refresh` / `.processing` (IntegrationsSyncService.swift:5-6).

### 11.3 Full UserDefaults/@AppStorage key inventory (grep of `@AppStorage("…")`, `forKey: "…"`, and `…Key = "…"`; count = occurrences)
healthKitEnabled(12) faceIDEnabled(9) devMode(9) audioTestMode(9) userName(7) voice_persona(6)
shouldStartVoiceRecordingFromShortcut(5) generationType(4) screenTimeWeeklyHistory(3) screenTimeExtensionLog(3)
mockAPICalls(3) isDarkMode(3) integration.photos.uploadOriginalMedia(3) experimentalViewEnabled(3) deepResearchMode(3)
backgroundAudioEnabled(3) screenTimeRequestedDate(2) screenTimeDailySummary(2) onboardingSignedIn(2)
onboardingIntegrationsCompleted(2) onboardingCurrentStep(2) integration.photos.connected(2) integration.contacts.connected(2)
integration.calendar.connected(2) integration.appleMusic.connected(2) hasCompletedOnboarding(2) videoJournalEntries
useDarkUI unifiedEntries simple_goals screenTimeUserApproved screenTimeLastSyncDate saved_podcasts rich_goals podcastCadence
playbackSpeed onboarding_profile_context onboarding_podcast_context onboarding_first_podcast_generated onboardingUserName
onboardingQuestionsCompleted onboardingPrivacyAcknowledged onboardingPersonaCompleted lastSuccessfulAuth
integrationSync.v2.photos.uploadedOriginalAssetIds integrationSync.v2.healthkit.syncedDays
integrationSync.v2.healthkit.pendingDays integrationSync.v2.healthkit.initialSyncCompleted
integrationSync.v2.<source>.lastSuccessfulSync integrationSync.v2.<provider>.initialSyncCompleted
integration.photos.uploadOriginalsOnCellular hasCompletedFileStorageMigration googleDocsEnabled googleAuthCompleted
devAPIBaseURL designV2.<code> autoPlayEnabled audioQuality DesignLabPage
(Keychain accounts `jwt_token`, `user_id`, `apple_user_id` under service `com.retrospect.api` also matched the grep.)
App Group defaults: `UserDefaults(suiteName: "group.com.retrospect.shared")` in ScreenTimeService.swift:35/148/225/246/257 and
ScreenTimeReport/TotalActivityReport.swift:147/184.

---

## 12. Info.plist, entitlements, build settings

### 12.1 Retrospect/Info.plist (all keys, merged with generated keys)
`BUNDLE_ID` = `com.shauryanarang.Retrospect` (custom, informational); a stray top-level `CFBundleURLSchemes` string (Google
reversed client id; misplaced, harmless); `CFBundleURLTypes`: (1) `GoogleSignIn` → `com.googleusercontent.apps.554366364287-…`,
(2) `Retrospect` → `retrospect`; `GIDClientID`; `NSFamilyControlsUsageDescription`; `NSCalendarsFullAccessUsageDescription`;
`NSCalendarsUsageDescription`; `NSAppleMusicUsageDescription`; `NSPhotoLibraryUsageDescription`; `NSContactsUsageDescription`;
`BGTaskSchedulerPermittedIdentifiers` [`com.shauryanarang.Retrospect.integrations.refresh`, `…integrations.processing`];
`PLIST_VERSION` "1"; `UIAppFonts` (Geist, Libre Baskerville, Adamina, EB Garamond family, Hedvig Letters Serif, 42
ExposureTrial/ExposureItalicTrial weights); `UIBackgroundModes` [`audio`, `fetch`, `processing`] (no `remote-notification`).
Generated (`INFOPLIST_KEY_*`, app Debug+Release, pbxproj ~:657-671 / :702-716): CFBundleDisplayName "Retrospect-2026",
LSApplicationCategoryType "", NSAppleMusicUsageDescription (different text, conflicts with plist), NSCameraUsageDescription,
NSFaceIDUsageDescription ("need to use faceid"), NSHealthShareUsageDescription, NSHealthUpdateUsageDescription,
NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription, NSSupportsLiveActivities YES,
UIApplicationSceneManifest_Generation YES, UIApplicationSupportsIndirectInputEvents YES, UILaunchScreen_Generation YES,
orientations portrait (iPhone) / all (iPad). No `ITSAppUsesNonExemptEncryption`, no PrivacyInfo.xcprivacy in the tree.
`GoogleService-Info.plist` is present in the app folder but no Firebase package is linked.
Widgets Info.plist: only `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
ScreenTimeReport Info.plist: `EXAppExtensionAttributes.EXExtensionPointIdentifier = com.apple.deviceactivityui.report-extension`.

### 12.2 Entitlements
- `Retrospect/Retrospect.entitlements` (the one used, `CODE_SIGN_ENTITLEMENTS` app :646/:691):
  `com.apple.developer.applesignin` [Default]; `com.apple.developer.healthkit` true;
  `com.apple.developer.healthkit.background-delivery` true; `com.apple.security.application-groups` [`group.com.retrospect.shared`].
  **Absent:** `aps-environment` (push), `com.apple.developer.family-controls` (FamilyControls is used — check signing),
  `keychain-access-groups`, associated domains.
- `Retrospect/Retrospect fina (SwiftUI).entitlements` — **unused** leftover (macOS sandbox keys, camera/mic, network client,
  healthkit + health-records). Not referenced by any build setting.
- `ScreenTimeReport/ScreenTimeReport.entitlements`: app group `group.com.retrospect.shared`.
- Widget extension: no entitlements file (so it cannot read the app group or the Keychain).

### 12.3 Build settings (project.pbxproj, objectVersion 77, 1036 lines)
| target | bundle id | deploy target | SWIFT_VERSION | other |
|---|---|---|---|---|
| project-level Debug/Release | — | 18.1 (:573, :630) | — | `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"` Debug only (:579); ENABLE_USER_SCRIPT_SANDBOXING YES; LOCALIZATION_PREFERS_STRING_CATALOGS YES |
| Retrospect (app) | `com.shauryanarang.Retrospect` (:677, :722) | inherits 18.1 | 5.0 (:680, :725) | CODE_SIGN_STYLE Automatic; DEVELOPMENT_TEAM `8W78P34Q9S`; TARGETED_DEVICE_FAMILY 1,2; MARKETING_VERSION 1.0; CURRENT_PROJECT_VERSION 1; GENERATE_INFOPLIST_FILE YES + INFOPLIST_FILE; odd absolute `FRAMEWORK_SEARCH_PATHS` entry `$(SDKROOT)/../../…/Users/shauryanarang/Documents/Retrospectapp/Retrospect` (:651-654, :696-699) |
| RetrospectTests | `com.shauryanarang.retrospect.2026a1b7.tests` | 18.1 | 5.0 | TEST_HOST = app, BUNDLE_LOADER = TEST_HOST |
| RetrospectUITests | `com.shauryanarang.retrospect.2026a1b7.uitests` | inherits 18.1 | 5.0 | |
| RetrospectWidgetsExtension | `com.shauryanarang.Retrospect.widgets` | **26.0** (:814, :845) | 5.0 | SWIFT_APPROACHABLE_CONCURRENCY YES; SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY YES; STRING_CATALOG_GENERATE_SYMBOLS YES |
| ScreenTimeReport (ExtensionKit) | `com.shauryanarang.Retrospect.ScreenTimeReport` | **26.2** (:875, :905) | 5.0 | same three as widgets |
`SWIFT_STRICT_CONCURRENCY`: absent everywhere. `OTHER_SWIFT_FLAGS`: absent everywhere. `SWIFT_DEFAULT_ACTOR_ISOLATION`: absent.
Capabilities: there is no `SystemCapabilities` block (Xcode 16+ derives from entitlements). Team id present (`8W78P34Q9S`) on every target.
Targets: app depends on widgets + ScreenTimeReport and embeds them ("Embed Foundation Extensions", "Embed ExtensionKit Extensions").
Linked system frameworks visible: HealthKit, WidgetKit, SwiftUI.

### 12.4 Synchronized groups (pbxproj :89-156)
- Root groups: `Retrospect` (app), `RetrospectTests`, `RetrospectUITests`, `RetrospectWidgets`, `ScreenTimeReport`.
- Exception sets:
  - "Exceptions for Retrospect folder in Retrospect target" (:90-96): `membershipExceptions = (Info.plist,)` (excluded from app)
  - "Exceptions for RetrospectWidgets folder in RetrospectWidgetsExtension target" (:97-103): `Info.plist`
  - "Exceptions for Retrospect folder in RetrospectWidgetsExtension target" (:104-110): `Models/VoiceRecordingActivity.swift`
    (included into the widget target)
  - "Exceptions for ScreenTimeReport folder in ScreenTimeReport target" (:111-117): `Info.plist`
Consequence: any `.swift` under `Retrospect/Retrospect/` (including a new `Platform/`) is compiled into the app; resources
(e.g. a `.storekit` file, a `.sql` migration) placed there are copied into the bundle automatically.

---

## 13. Package dependencies and .gitignore
XCRemoteSwiftPackageReference (pbxproj :983-1000):
- `GoogleSignIn-iOS` — `https://github.com/google/GoogleSignIn-iOS`, `kind = upToNextMajorVersion; minimumVersion = 8.0.0;` →
  products GoogleSignIn, GoogleSignInSwift
- `google-api-objectivec-client-for-rest` — `https://github.com/google/google-api-objectivec-client-for-rest`,
  `kind = branch; branch = main;` → products GoogleAPIClientForRESTCore, _Docs, _Document, _Drive
All product deps are on the app target only. No GRDB, no RevenueCat, no analytics SDK.

Package.resolved exclusion:
- `Retrospect/.gitignore`: line 29 `Package.resolved`, line 30 `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  (also line 25 `.swiftpm/`, line 2 `*.xcodeproj/*` with `!project.pbxproj`, `!xcshareddata/`; line 34 `*.xcworkspace`).
- repo-root `.gitignore`: line 31 `Package.resolved`, line 32 the same xcshareddata path; line 27 `.swiftpm/`; line 36 `*.xcworkspace`.
No Package.resolved is tracked (`git ls-tree` confirms).

---

## 14. Tests, scheme, CI
- `RetrospectTests/RetrospectTests.swift`: Swift Testing template, `import Testing`, `@testable import Retrospect`,
  `struct RetrospectTests { @Test func example() async throws {} }`.
- `RetrospectTests/SleepMathTests.swift` (64 lines): `struct SleepMathTests`, 7 `@Test` funcs with `#expect`, testing
  `SleepMath.hoursAsleep` / `stageHours` (pure functions in Services/SleepMath.swift). This is the one real test file.
- `RetrospectUITests/*`: XCTest templates (`testExample`, `testLaunchPerformance`, `testLaunch`).
- Scheme `Retrospect.xcscheme` TestAction, verbatim:
  ```xml
  <TestAction
     buildConfiguration = "Debug"
     selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
     selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
     shouldUseLaunchSchemeArgsEnv = "YES"
     shouldAutocreateTestPlan = "YES">
  </TestAction>
  ```
  No `<Testables>`, no test plan reference; no `.xctestplan` in the repo. `xcodebuild test -scheme Retrospect` will not run
  RetrospectTests until a Testable or test plan is added. Scheme has no CommandLineArguments.
  Second scheme: `RetrospectWidgetsExtension.xcscheme`.
- CI (`.github/workflows/quality.yml` job `ios`): `xcodebuild -project Retrospect/Retrospect.xcodeproj -scheme Retrospect -sdk iphonesimulator -configuration Debug -derivedDataPath "$RUNNER_TEMP/dd" CODE_SIGNING_ALLOWED=NO build`
  — build only, self-hosted macOS runner. `swift-quality.yml`: SwiftLint 0.65.1 `--strict` and SwiftFormat 0.64.0 `--lint`
  over `Retrospect/Retrospect/DesignSystemV2` and `Retrospect/Retrospect/Features` only (`.swiftlint.yml` `included` same two,
  `.swiftformat` `--swiftversion 5.10`, `--maxwidth 160`, `--self remove`). Lint rules include `force_unwrapping`,
  `file_length 600`, `type_body_length 400`. Also `design-system.yml`, `secrets.yml` workflows.

---

## 15. Top-level type names in the app module (collision list)
Method: regex over every `.swift` under `Retrospect/Retrospect/` for lines starting (column 0) with optional attributes/
modifiers then `struct|class|enum|protocol|typealias|actor <Name>`. 454 internal names + 74 file-private names.
Only protocol: `PodcastPlayback` (Views/Components/PodcastPlayer.swift). Only typealias: `UIFont = NSFont` under
`#elseif canImport(AppKit)` (Utilities/Typography.swift:7, never active on iOS). No actors. Duplicate: `PodcastTranscriptLine`
(private in two files).

Shadowing/generic names to avoid or namespace around: `Layout` (shadows SwiftUI.Layout, Utilities/DesignSystem.swift:158),
`MeshGradient` (shadows SwiftUI.MeshGradient, Views/MeshGradient.swift:4), `Entry` (EntryModel.swift:20; widgets also have
`SimpleEntry`), `Spacing`, `Animations`, `Shadows`, `BorderRadius`, `BorderWidth`, `IconSize`, `AudioPlayer`, `PreviewView`,
`BlurView`, `TimePeriod`, `InputField`, `Citation`, `AnyCodable`, `StorageInfo`, `APIError`, `UserProfile`, `TabItem`,
`HomeTab`, `SettingsRow`, `SettingsSection`, `ShareSheet`, `DocumentPicker`, `Pod` (private).
Platform-relevant existing names: `RetrospectAPIClient`, `APIError`, `SubscriptionManager`, `SubscriptionPlan`,
`PaywallView`, `PaywallBenefit`, `PodcastNotificationService`, `PodcastNotification`, `IntegrationsSyncService`,
`IntegrationBackgroundTasks`, `AppDelegate`, `RetrospectApp`, `UserProfile`, `AuthenticationScreen`,
`AppleSignInCoordinator`, `BackendAuthGateView`, `FileStorageManager`, `EntryManager`, `GoalsManager`, `OnboardingState`,
`OnboardingContextManager`, `ThemeManager`, `ThemeManagerKey`, `KeyboardManager`, `HapticManager`. No existing `Platform`,
`Session`, `Store`, `Outbox`, `Router`, `Route`, `Analytics`, `Environment`, `AppEnvironment`, `Endpoint`, `HTTPClient`,
`Keychain`, `Database`, `Push`, `Entitlement`, `DeepLink`, `Logger`, `Event`. Module-level extensions to be aware of:
`JSONDecoder.apiDecoder`, `Notification.Name.integrationConnectionChanged/.recordingDidFinish/.recordingDidFail`,
19 `extension View`, `EnvironmentValues` (3 files), `Font`, `Color`, `Calendar`, `FileManager`.
Other modules (separate namespaces): widgets `Provider`, `SimpleEntry`, `RetrospectWidgets`, `RetrospectWidgetsBundle`,
`RetrospectWidgetsControl`, `RetrospectWidgetsEntryView`, `LinearColors` (dup of app's), `VoiceRecordingLiveActivityWidget`,
`VoiceRecordingLockScreenView`; ScreenTimeReport `AppUsageData`, `CategoryUsageData`, `ScreenTimeDailySummary`,
`ScreenTimeReport`, `TotalActivityReport`, `TotalActivityView`, `ViewData`.

Full internal list (alphabetical):
AIProvider AIReflectionStylePicker AIReflectionStylePicker_Previews AIServiceError AIServiceManager APIError AVPlayerViewControllerRepresentable AdvancedSettingsView AnimatedMeshGradient AnimationPreviewView AnimationVariant AnimationVariantGrid Animations AnyCodable AppDataExporter AppDataImporter AppDelegate AppExportData AppUsageEntry AppearanceSettingsView AppleHealthOnboardingScreen AppleSignInCoordinator AttachmentPickerSheet AudioControlButton AudioPlaybackAttributes AudioPlaybackLiveActivity AudioPlayer AudioPlayerContainer AudioPlayerState AudioPlayerView AudioRecordingError AudioRecordingManager AudioSessionManager AudioSettingsView AuthenticationScreen BackendAuthGateView BackendGoal BackendInsight BackendIntegrationCatalogItem BackendIntegrationConnection BackendObservation BackgroundAudioRecordingManager BenefitCard BlurView BorderRadius BorderWidth BottomMiniPlayer BottomNavigationBar CameraPreview CameraPreviewViewRepresentable CameraView CameraViewModel CategoryUsageEntry ChatMessage ChatMessageSender Citation ClaudeError ClaudeService ClickyButton ClickyButtonStyle CoStarIconButton CoStarMinimalButton CoStarPillButton CoStarPrimaryButton CoStarSearchInput CoStarSecondaryButton CoStarSingleLineInput CoStarTextInput ComingSoonIntegration CompactTabButton ContentReference DailyHealthSnapshot DarkAdvancedSettingsView DarkAppContainer DarkAppearanceSettingsView DarkAppleHealthOnboardingScreen DarkAudioManager DarkAudioPlayerView DarkAudioSettingsView DarkEntriesView DarkEntryCard DarkEntryDetailView DarkEntryFilter DarkFeaturedPodcastCard DarkFilterTab DarkFilterTabs DarkFilterTabsCompact DarkFocusModeCard DarkGoalsOnboardingScreen DarkGoalsView DarkGoogleDocsOnboardingScreen DarkInsightsSheet DarkIntegrationsDataView DarkJournalView DarkLoadingPill DarkMiniPlayer DarkOnboardingFlow DarkOnboardingScreenTemplate DarkPageCountPill DarkPageScaffold DarkPageTitle DarkPodcastCard DarkPodcastsView DarkPrivacyAndSecurityView DarkPrivacyOnboardingScreen DarkProfilePersonalizationView DarkSearchBar DarkSearchBarCompact DarkSettingsCard DarkSettingsView DarkSplashScreen DarkTeleprompterView DarkTranscriptSheet DarkVoicePersonaOnboardingScreen DarkVoiceRecordingView DataActionButton DataExplanationScreen DataManagementSection DataStatCard DataStatisticsView DeepResearchGeneratingView DeepResearchRequest DeepResearchResponse DesignV2 DesignV2Screen DevelopmentModeToggle DocumentCard DocumentContentSheet DocumentPicker EditNameView ElevenLabsError ElevenLabsService EnhancedBenefitCard EnhancedSingleLineTextField EnhancedTextField EntriesFloatingSearchBar EntriesView Entry EntryCard EntryDetailView EntryFilterType EntryManager EntryType ExpandableCard ExpandedAddGoalOverlay ExpandedSearchOverlay ExperimentalView ExposureFont ExtractedGoalFromBackend FeatureCard FigmaLightCountPill FigmaLightDivider FigmaLightInlineEntryReader FigmaLightPageScaffold FigmaLightRowCard FigmaLightSectionLabel FigmaLightTheme FileStorageManager FilterTab FirstPodcastError FirstPodcastExperience FirstPodcastFinaleDebugHost FirstPodcastOrchestrator FirstReflectionView FloatingGenerateButton FloatingSearchAddBar FloatingSearchBar FloatingTabButton FluidDotsView FluidVariants FocusModeCard FontPreviewTile FramedCameraView FramedCameraView_Previews FullscreenPodcastCard GeneratingLoadingView GenerationType GoalCategory GoalExtractionResponse GoalPill GoalsFloatingBar GoalsInputMode GoalsManager GoalsView GoalsView_Previews GoogleAuthView GoogleDocComment GoogleDocRevision GoogleDocsContent GoogleDocsDataModel GoogleDocsDataSection GoogleDocsDetailView GoogleDocsError GoogleDocsInfo GoogleDocsIntegrationView GoogleDocsModel GoogleDocsOnboardingScreen GoogleDocsService GoogleDocsSettingsView GrainEffect GroupedEntriesContainer GroupedEntryRow GroupedSettingsContainer GroupedSettingsRow HamburgerButton HapticManager HeadlineAnimationTracker HealthDataBadge HealthKitManager HoldToActivateButton HoldToActivateButton_Previews HomeScreen HomeTab IconSize ImageAttachmentPicker InfoCard InfoItem InfoRow InfoSection InputField InputSheet InsightCard InsightGeneratingView IntegrationBackgroundTasks IntegrationCatalogItem IntegrationCategory IntegrationConnectionKind IntegrationsDataView IntegrationsSetupPage IntegrationsSyncService IntegrationsView IntegrationsView_Previews JournalEntryCard KeyboardAvoidanceBehavior KeyboardAware KeyboardBehaviorExamples KeyboardManager LargeMediaControlStyle Layout LearningAboutYouView LearningHaptics LearningTouchAutoDemo LearningTouchDebugHost LearningTouchRenderer LegacyHomeScreen LightCadenceOption LightSettingsInfoRow LightSettingsInputRow LightSettingsToggleRow LinearColors MarkHalfPath MarkdownView MarkdownView_Previews MeshGradient MetalViewRepresentable MiniPlayerView MinimalHomeScreen MinimalJournalInput MinimalPillButton MinimalPillButtonLarge MinimalTab MinimalTabBar MinimalTabButton MockPodcast ModeSegmentedControl NameInputCard NativeSourcesManager NavBarButton NavBarContainer NewPodcastArrivalView NewPodcastArrivalView_Previews OnboardingAnswer OnboardingClosingPage OnboardingContextManager OnboardingFlow OnboardingIntegrationsSnapshot OnboardingOptionRow OnboardingPhase OnboardingPodcastContext OnboardingPrimaryButton OnboardingPrivacyPage OnboardingScaffold OnboardingScreenTemplate OnboardingState OnboardingStatusPill OnboardingStyle OnboardingTextInput OpenAIError OpenAIService OptimizedAudioPlayerView OptimizedHomeScreen OptimizedTabView PaywallBenefit PaywallView PermissionRow PermissionToggle PersonaPickerPage PodcastCadence PodcastCitation PodcastEpisode PodcastFlowPreview PodcastFlowStage PodcastGenerationSource PodcastMood PodcastNotification PodcastNotificationService PodcastOutlineData PodcastPaywallFlow PodcastPlayback PodcastPlayerTheme PodcastSegment PodcastSegmentData PodcastTranscript PodcastTranscriptReader PodcastTranscriptSurfaceStyle PodcastTranscriptTypography PodcastTransport PolaroidFrame PolaroidHomeView PolaroidPlayingControls PressAction PreviewView PricingCard PrivacyAndSecurityView PrivacyAndSecurityView_Previews PrivacyScreen ProfilePersonalizationView PulseAnimation RButton RColor RDesignLab RDimension RFamily RFoundationGallery RHairline RHaptic RIconSize RIconWell RKnowsYouTrack RLabPage RMotion RMotionLab RNumber RParts1Gallery RParts2Gallery RPressStyle RProgressHairline RSectionLabel RSegmented RSegmentedGallery RSettingsGroup RSettingsRow RSettingsRowGallery RSourceStatus RSpinner RStatusDot RSymbol RTextStyle RWaveform ReferenceChip ReflectionsInputCard ReflectionsInputState RetrospectAPIClient RetrospectApp RetrospectLoadingMark RetrospectLoadingScreen RetrospectShortcuts RichGoal RichGoalCard RotateModifier ScreenTimeDetailView ScreenTimeService ScreenTimeSummary ScrollOffsetPreferenceKey SendButtonStyle SettingsCategoryCard SettingsDivider SettingsGroup SettingsRow SettingsSection SettingsSubsection SettingsToggleRow SettingsView SettingsView_Previews Shadows ShareSheet SideOverPanel SimpleCameraView SimplePhotoPicker SimplePolaroid SkeuomorphicTile SleepMath Spacing SpeechRecognizerManager SplashScreenView SpringHapticController SquircleLogo StackingCardModifier StackingListView StackingScrollView StartVoiceRecordingIntent StatCard StopRecordingIntent StorageInfo StorageInfoView StorageStatCard StreamingPodcastPlayback SubscriptionManager SubscriptionPlan SupportAndDataView SupportAndDataView_Previews TabItem TerraCottaPillButtonStyle TextToSpeechService ThemeManager ThemeManagerKey TimePeriod TipCard TipsView TopNavigationBar TopNavigationState TranscriptDetailsCard TranscriptModalView TranscriptModel TranscriptViewModel TranscriptionError TranscriptionService TransformingLoadingPill TypographyKerning TypographySpacing UIFont UserProfile VideoJournalEntry VideoJournalListView VideoJournalListView_Previews VideoJournalManager VideoJournalView VideoJournalViewModel VideoLogEntryCard VideoLogView VideoLogView_Previews VideoPlayerView VoiceEntryPlayerView VoiceGoalsPage VoicePersonaOption VoiceRecordingAttributes VoiceRecordingLiveActivityWidget VoiceRecordingLockScreenView VoiceRecordingView WelcomeCardScreen WelcomeFeaturePage WelcomeSignInPage WhiteSquareButtonStyle iMessageOnboardingView

File-private top-level names:
AckDissolveParticle AckParticleField AckTextSizeKey AnimationCard AppleNotesPDFImporter AssetStartResponse CardTopEdge ChatBubbleView ClaudeProxyResponse DynamicSafeAreaBottomKey DynamicSafeAreaTopKey FirstPodcastCreationView FlowPhase GenericResponse GoalChecklistRow GoalExtractionAPIResponse GoalSingleResponse GoalsListResponse ImportStartResponse ImportedPDFNote InsightsListResponse IntegrationCardStack IntegrationsResponse NetworkProbeContinuation NoiseTexture OAuthStartResponse OpenSidePanelKey PDFImportResult PersonaCard PersonaCardStack PhotoDayStats Pod PodcastGeometryPreferenceKey PodcastLayoutDiagnosticsHost PodcastLayoutDiagnosticsOnboardingLayer PodcastListResponse PodcastSingleResponse PodcastTranscriptLine PodcastTranscriptSegment PrimaryBody ProfileResponse Question RAppear RButtonStyle REqualWidthHStack RFloat RLastTouchKey RLifeHost RPendingDots RPop RProportionalHStack RSegmentStyle RSegmentedThumb RSegmentedTrack RSettingsRowStyle RShake RTextModifier RefreshResponse ScrollTarget ShakeEffect SideOverPanelEntryRow SideOverPanelRow SidePanelProgressKey SignInResponse StatefulPreviewWrapper ThinkingDots TouchObserver TouchObserverHostView TouchObserverInstaller TypingIndicatorView TypingRevealText VariableBlurView WorkoutDaySummary iMessageBubble

---

## 16. DesignSystemV2/DesignV2Switches.swift (68 lines, full API)
```swift
enum DesignV2Screen: String, CaseIterable {
    // first run
    case splashSignIn = "ON-1/2", questions = "ON-3–9", privacy = "ON-5", connect = "ON-6"
    case gettingReady = "ON-10", tease = "ON-11", paywall = "ON-12", firstHome = "ON-13"
    // daily loop
    case journal = "JR-1", todaysBrief = "JR-2", allEntries = "JR-3", oneEntry = "JR-4"
    // podcasts
    case podcasts = "PC-1", player = "PC-2", whyThisIsHere = "PC-3"
    // goals
    case goals = "GL-1", oneGoal = "GL-2"
    // you
    case you = "YO-1", search = "YO-2", aSource = "YO-3", aNode = "YO-4", whatIKnow = "YO-5"
    // settings and account
    case settings = "ST-1", dailyBrief = "ST-2", sources = "ST-3", aSourceSettings = "ST-4"
    case privacySettings = "ST-5", howStraight = "ST-6", voice = "ST-7", whatIveLearned = "ST-8"
    case account = "ST-9", signInReturning = "AC-1", signingOut = "AC-2"
    // outside the app
    case share = "EX-1", lockScreen = "EX-2", notifications = "EX-3", widgets = "EX-4"
}

enum DesignV2 {
    static let liveForEveryone: Set<DesignV2Screen> = []
    static func isOn(_ screen: DesignV2Screen) -> Bool {
        if liveForEveryone.contains(screen) { return true }
        if let forced = override(for: screen) { return forced }
        return isDebugOrTestFlight
    }
    private static func override(for screen: DesignV2Screen) -> Bool? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DesignV2Off") { return false }
        if let value = UserDefaults.standard.object(forKey: "designV2.\(screen.rawValue)") as? Bool { return value }
        #endif
        return nil
    }
    private static var isDebugOrTestFlight: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
```
Notes: 39 cases; raw values contain "/" and an en dash ("ON-3–9"), so the per-screen override keys are e.g.
`designV2.ON-1/2`. No call sites on main yet (grep: none outside this file). `appStoreReceiptURL` is deprecated as of
iOS 18; StoreKit 2's `AppTransaction.shared` `environment` is the replacement, which a StoreKit Platform module could own.

---

## 17. -DesignLab / RDesignLab / RLabPage (DesignSystemV2/RMotionLab.swift, current main)
Entry: `-DesignLab` → RetrospectApp.swift:86-92 → first ladder branch :148-151 `RDesignLab()` (DEBUG).
Whole file is inside `#if DEBUG` (:9 … :172). Recent commits: `f6f4617` "wire the lab's parts page", `38a9536`, `5075179`.
```swift
/// The lab's pages. `-DesignLabPage parts` opens one directly (for screenshots and recordings).
enum RLabPage: String, CaseIterable, Identifiable {
    case motion, foundation, parts
    var id: String { rawValue }
    static var launch: RLabPage {
        UserDefaults.standard.string(forKey: "DesignLabPage").flatMap(RLabPage.init(rawValue:)) ?? .motion
    }
}

struct RDesignLab: View {
    @State private var page = RLabPage.launch
    var body: some View {
        VStack(spacing: 0) {
            Picker("lab", selection: $page) { ForEach(RLabPage.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .padding(.vertical, RDimension.space2)
            switch page {
            case .motion: RMotionLab()
            case .foundation: RFoundationGallery()
            case .parts:
                ScrollView { VStack(alignment: .leading, spacing: RDimension.space8) { RParts1Gallery(); RParts2Gallery() } }
            }
        }
        .background(RColor.backgroundCanvas)
        .rLifeHost()
    }
}
```
`RMotionLab` :53-170, `#Preview("motion lab") { RDesignLab() }` :171. Galleries: `RFoundationGallery`
(RFoundationGallery.swift:8), `RParts1Gallery` (Parts/RParts1.swift:124, in #if DEBUG), `RParts2Gallery` (Parts/RParts2.swift:100,
in #if DEBUG). `RSegmentedGallery` (Components/RSegmented.swift:169, DEBUG) and `RSettingsRowGallery`
(Components/RSettingsRow.swift:222, not DEBUG-gated) exist but are **not** on any lab page (Preview only).
Mechanism to add a page: add a case to `RLabPage` and a `switch` arm; launch with `-DesignLab -DesignLabPage <rawValue>`.
`.rLifeHost()` (RMotionModifiers.swift:145) must be at the root for touch-stilling ambient motion.
