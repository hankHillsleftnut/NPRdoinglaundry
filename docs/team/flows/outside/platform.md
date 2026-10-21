# Outside the app · Platform cards

Contract: [07-outside.md](../../contracts/07-outside.md). The app engineer builds these from the Platform side (client, store, push, router, extensions). Each one lists its tests by layer (testing.md). "Integrator" bytes (`INT7.x`) are changes to `project.pbxproj`, entitlements and `RetrospectApp.swift`, which only the integrator edits (integrator.md §1.3). They're dependencies here, not cards.

**Integrator bytes this side needs:**
- **INT7.1 · targets and entitlements:**
  - a share extension target `RetrospectShare` (bundle `com.shauryanarang.Retrospect.share`, iOS 18.1)
  - the widget extension's deployment target lowered from **26.0 to 18.1** (today the widget only installs on iOS 26: app-reference §12.3)
  - a synchronized folder `Retrospect/Outside/` that is a member of the app, the widget and the share targets
  - the app group `group.com.retrospect.shared` on the widget and share targets (only the app and ScreenTimeReport have it today)
  - `keychain-access-groups` `$(AppIdentifierPrefix)com.retrospect.outside` on the app and the share extension
  - `PrivacyInfo.xcprivacy` for each new target (PL7.1's pattern)
- **INT7.2 · the bridge in `RetrospectApp.swift`:** start `Outside.InboxImporter` and `Push.Categories.register()` from `AppDelegate.didFinishLaunching`, and forward `didReceive` to `Push.Taps` (PL5.3).

**The tree on this side:**
- **base** › the Outside folder (PL7.2) · the token mirror (PL7.3)
- **share** › the inbox (PL7.4) · the extension reading (PL7.5a) · the extension saving (PL7.5b)
- **lock screen** › Now Playing (PL7.6) · the recording Live Activity (PL7.7)
- **notifications** › categories and taps (PL5.3) · background refresh (PL7.9) · preferences and the lock-screen choice (PL7.10)
- **widgets** › the snapshot writer (PL7.8a) · the timeline and intents (PL7.8b)
- **retiring** › the ledger (X01) · old services (X05a–c) · old local data (X06a–f) · the final sweep (X09)

**Order:**
1. INT7.1 → PL7.2 → PL7.3 → PL7.4
2. PL5.3 (needs PL5.1 from first run) → PL7.10 → PL7.9
3. PL7.8a → PL7.8b
4. PL7.5a → PL7.5b
5. PL7.6 → PL7.7

Founder question Q8 (README §8) asks to pull PL7.6 into Beta 1.

---

## Base

### PL7.2 · The Outside folder: what the app and its extensions share          size: M
Place in the tree: outside › base › `Retrospect/Outside/`
Repo · branch: NPRdoinglaundry · `pl/PL7.2-outside-folder`
Needs: INT7.1, PL0.2 (namespaces, log sink), contract 07 + fixtures      Unblocks: PL7.3, PL7.4, PL7.8a/b, PL7.5a/b

Why: the app, the widget and the share sheet agree on exactly the same shapes, so a saved link or a widget state can't be read differently by two parts of the same app.

Inputs:
- Contract 07 §1, §3, §4; every `fixtures/07/*.json`.
- Reference: app-reference §12.2–§12.4 (entitlements, targets, synchronized groups), §15 (top-level name collisions: no `Outside` exists).

Spec:
- Namespace `enum Outside {}` in `Retrospect/Outside/Outside.swift`. Everything here is compiled into three targets, so it uses **Foundation only** (no SwiftUI, no GRDB, no `Platform`), value types that are `Sendable`, and no singletons.
- `Outside.AppGroup`:
  - `static let id = "group.com.retrospect.shared"`
  - `static func container() throws -> URL`
  - `static func directory(_ d: Directory) throws -> URL` with `Directory` = `.widget`, `.inbox`, `.inboxUnreadable`, created on first use with `FileProtectionType.completeUntilFirstUserAuthentication`
- `Outside.AtomicFile.write(_ data: Data, to url: URL) throws` (temp file in the same folder, `replaceItemAt`) and `read(_:) throws -> Data?`.
- Contract types with explicit `CodingKeys` where names differ, and closed enums with `unknown`:
  - `Outside.WidgetSnapshot` (+ `BriefState`, `EpisodeState`)
  - `Outside.InboxItem`
  - `Outside.SharesCreateRequest`, `SharesPreviewRequest`, `SharesPreviewResponse`, `SharedThing` (+ `Kind`, `LengthUnit`, `GoalChoice`, `Reading`)
  - `Outside.PushPayload` (`r` only: `v`, `kind`, `id`, `link`, `scope`, `sentAt`; `Kind` closed with `unknown`)
- `Outside.Log`: a closed enum of events (`snapshotWritten(state:)`, `inboxWritten`, `inboxImported(count:)`, `inboxUnreadable`, `shareSent(status:)`, `previewShown(reading:)`) and a sink protocol. The app plugs `Platform.Log` in, and the extensions use an `os.Logger` sink with every field `.private` except the enum names.
- `Outside.Clock` and `Outside.IDs` protocols, so tests inject time and UUIDs.

Steps: folder (INT7.1) → namespace and files → types → fixture decoding tests in the app test target → a small decoding test target for the extension (or the share extension's test plan, if INT7.1 adds one).

Acceptance:
- All three targets build with the folder.
- Every `fixtures/07` file decodes, unknown states land on `.unknown`, and extra fields are ignored.

Tests (layer 4–5):
- `every contract 07 fixture decodes`
- `an unknown brief state decodes as unknown`
- `an unknown push kind decodes as unknown and keeps its link`
- `a snapshot written atomically is never read half-written` (write and read on two tasks, 1,000 times)
- `the app group directories are created with complete-until-first-auth protection`
- `nothing in Outside imports SwiftUI, GRDB or Platform` (a grep test)

Proof: test output; the three targets building in CI.

Watch out: the app target is in Swift 5 mode and the extensions use approachable concurrency. Write code that is correct in both: no implicit `@MainActor`, no global mutable state.

---

### PL7.3 · The access-token mirror for the share extension                  size: S
Place in the tree: outside › base › `Outside.TokenMirror`
Repo · branch: NPRdoinglaundry · `pl/PL7.3-token-mirror`
Needs: PL7.2, PL1.3, PL1.5, INT7.1 (`keychain-access-groups`)      Unblocks: PL7.5a, PL7.5b

Why: the share sheet can save straight to Retro without opening the app, and never holds anything that could sign you in for long.

Inputs: contract 07 §4 (the token rule); contract 00 §3 (15-minute access tokens, rotating refresh tokens); PL1.3 (`Session.Store`, `AfterFirstUnlockThisDeviceOnly`); PL1.5 (refresh, sign-out).

Spec:
- `Outside.TokenMirror` reads and writes one generic-password item: service `com.retrospect.outside`, account `access`, access group `$(AppIdentifierPrefix)com.retrospect.outside`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Its value is JSON `{ accessToken, expiresAt, userIdHash }`, where `userIdHash` is the SHA-256 of the user id, so the extension can tell an account changed without holding the id.
- **The app writes it** after every sign-in and refresh (a call from `Session.Refresher`, added in this PR with one line in PL1.5's code path) and **deletes it** at sign-out and delete-account.
- **The extension only reads it.** `func validToken(now:) -> String?` returns nil if the token expires within 60 seconds.
- **The refresh token is never mirrored.** A test asserts the mirror's JSON has exactly the three keys.

Tests (layer 5, fake Keychain):
- `sign-in writes the mirror`
- `refresh replaces it`
- `sign-out deletes it`
- `the mirror never contains the refresh token`
- `a token expiring within a minute is treated as missing`
- `writes request after-first-unlock-this-device-only and the shared access group`

Proof: test output; one simulator run where the share extension reads a mirrored token (integrator, test account).

Watch out: Keychain access groups need the team prefix at runtime. Read it from the entitlement (`SecTask`) or the app's `AppIdentifierPrefix` Info key, and never hard-code `8W78P34Q9S`.

---

## Share (EX-1)

### PL7.4 · The share inbox and its importer                                   size: M
Place in the tree: outside › EX-1 share › plumbing › `Outside.Inbox` + `Store.InboxImporter`
Repo · branch: NPRdoinglaundry · `pl/PL7.4-share-inbox`
Needs: PL7.2, PL2.2 (the outbox), PL2.1, BE7.2b (live target; fixtures until then), INT7.2 (the launch hook)      Unblocks: PL7.5b, T05d

Why: something you save while offline, or while the share sheet ran out of time, is sent exactly once the next time Retro runs, and is never lost.

Inputs: contract 07 §4; PL2.2 (operations, keys, drain); fixtures `inbox.item*.json`.

Spec:
- `Outside.Inbox` (in the shared folder, used by the extension):
  - `put(_ item: InboxItem) throws` writes `<clientEntryId>.json` atomically
  - `markSent(_ id:) throws` sets `sentByExtension = true`
  - `all() -> [Result<InboxItem, Unreadable>]`
- `Store.InboxImporter` (in `Platform/`, an actor):
  - runs on launch, on `.active` and after a silent push (PL7.9)
  - for each file: `sentByExtension` → delete; otherwise `Outbox.enqueue(operation: .shareCreate, key: clientEntryId, body: request)`, in one GRDB transaction that also records the import in a new table `inbox_imports (client_entry_id TEXT PRIMARY KEY, imported_at TEXT)` (a store migration in this PR), then delete the file
  - if the app dies between the commit and the delete, the next run sees the id in `inbox_imports` and only deletes
- An unreadable file moves to `inbox/unreadable/` and is logged `inboxUnreadable` (no content). The app never deletes it; X06f clears it after 30 days.
- The outbox already sends `share.create` with the idempotency key. A 404 on the goal (contract 07 §8) is retried once without the goal under a new key; this is the outbox operation's own handling.
- Journal echo: an imported share appears in today's thread like any entry (contract 02 `today` merge in PL3.1a), as "waiting to send" until sent.

Steps: `Inbox` → importer + migration (`inbox_imports`) → outbox operation `shareCreate` → tests.

Acceptance:
- Ten files with three marked sent → seven outbox items and zero files.
- A crash between commit and delete never sends twice.
- An unreadable file is set aside, counted, and never blocks the others.

Tests (layer 5):
- `an inbox item becomes one outbox item and the file is removed`
- `an item the extension already sent is only deleted`
- `a crash after the commit and before the delete imports nothing twice`
- `an unreadable file is moved aside and the rest import`
- `running the importer twice does nothing the second time`
- `the same item sent by the extension and by the outbox creates one entry` (URLProtocol stub returning 201 then 200 replay)
- `a goal that's gone is retried once without it under a new key`
- `offline, imported items wait in the outbox`
- `no log line carries a url, text or note`

Proof: test output; a recording of a share saved in airplane mode appearing in the journal once after reconnecting (T05d's scenario).

Watch out: the extension may write while the importer reads. Atomic writes plus reading whole files make this safe, so never stream a half-written file.

---

### PL7.5a · Share extension: what was shared, and Retro's read               size: M
Place in the tree: outside › EX-1 share › plumbing › `ShareModel` (reading)
Repo · branch: NPRdoinglaundry · `pl/PL7.5a-share-reading`
Needs: INT7.1 (the target), PL7.2, PL7.3, BE7.1b (live; fixtures until then)      Unblocks: PL7.5b, P34

Why: whatever app you're in, sharing to Retro shows you right away what it got, and in a moment what it makes of it.

Inputs: contract 07 §2.1, §8; fixtures `share.preview.*`; Apple: `NSExtensionContext`, `NSItemProvider` (`UTType.url`, `.plainText`), activation rule.

Spec:
- Activation rule (`Info.plist` `NSExtensionActivationRule`): `NSExtensionActivationSupportsWebURLWithMaxCount = 1`, `NSExtensionActivationSupportsText = YES`. No images or files in v1 (founder question 5).
- `ShareModel` (`@MainActor @Observable final class`, in the extension target):
  - `state: .reading(SiteOnly) | .read(Preview) | .unreadable(SiteOnly) | .textOnly(String) | .signedOut | .refused(String)`
  - `extract()`: loads the first URL provider, falling back to text. A text share whose content is exactly one URL is treated as a URL (Safari sometimes shares both). `site` is parsed on the phone (host without `www.`) so the card shows something at once.
  - `preview()`: posts to `/v2/shares/preview` with the mirrored token (PL7.3) through a tiny `Outside.SharesClient`, which uses `URLSession` with a 8 s timeout, contract 00 headers (`X-App-Version`, `X-Time-Zone`, `Accept-Language`) and decoding of the 00 envelope. With no token → `.signedOut`.
  - The base URL comes from the app's build configuration via the shared `Info.plist` key `RetrospectAPIBaseURL` (set by INT7.1 from the same xcconfig as the app). Never hard-coded.
- Memory: share extensions have about 120 MB. No images are loaded and nothing beyond the item and one response is held.

Tests (layer 5, URLProtocol stubs, a fake `NSExtensionContext`):
- `a shared url shows its site at once and the read when it arrives`
- `a text share that is only a url is treated as a url`
- `an unreadable page shows the site only`
- `no token shows signed out and sends nothing`
- `a slow preview stops waiting at eight seconds and leaves save available`
- `spend limited shows no read and save still works`
- `a waitlisted account shows open retrospect to finish signing in`
- `requests carry the contract 00 headers`

Proof: test output; simulator screenshots of each state next to `1H1M-0` (with P34).

Watch out: Safari, Notes and Messages hand over providers in different orders. Test against a fixture list of real provider type orders (types only, no content).

---

### PL7.5b · Share extension: saving, and the queue                           size: M
Place in the tree: outside › EX-1 share › plumbing › `ShareModel` (saving)
Repo · branch: NPRdoinglaundry · `pl/PL7.5b-share-saving`
Needs: PL7.5a, PL7.4, BE7.2b      Unblocks: P34, T05d

Why: tapping save is always safe. Either it's in your bank, or it's waiting on your phone and you're told so.

Inputs: contract 07 §2.2, §4, §8; fixtures `share.create.*`, `inbox.item*`, `error.share.*`.

Spec:
- `save(note:goalChoice:)`:
  1. make `clientEntryId` (injected `IDs`)
  2. **write the inbox item first** (`Outside.Inbox.put`) so a crash can't lose it
  3. if a valid token exists, `POST /v2/shares` with `Idempotency-Key`, a 10 s timeout and up to 2 attempts (`attempts` updated in the file)
  4. on 200/201 → `markSent` → state `.saved(line)`; offline, no token or timeout → `.queued`
  5. on 404 (goal) → resend once without the goal under a new id, and replace the inbox file
  6. on other 4xx → `.refused(message)` and the file is removed (the server won't take it)
- The saved line: "it'll be in tomorrow's brief" when the app last wrote `brief.state != off` in the widget snapshot (the extension reads it, with no network); otherwise "it's in your journal." (founder copy, contract 07 §12.8).
- `completeRequest` is called only after the state has been shown for `motion.duration.toastVisible` (4 s) or the person taps done. A background `URLSession` is **not** used: the item is already safe in the inbox, and the app sends it.
- The voice "add why": the compact composer (C42) in the extension uses on-device `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`). The transcript becomes the note and no audio is kept or sent. If on-device recognition is unavailable, the mic is hidden.

Tests (layer 5):
- `save writes the inbox before sending`
- `a successful save marks the item sent`
- `offline save leaves the item queued and says so`
- `a refused save removes the item and shows why`
- `a goal that's gone is resent once without it`
- `two taps on save send once` (the button is disabled after the first; the test proves the model ignores a second call)
- `the saved line follows the brief switch in the snapshot`
- `the voice note is recognised on device and no audio is written`

Proof: recordings of saved, queued (airplane mode) and refused, plus the T05d scenario.

Watch out: never call `completeRequest` before the inbox write returns.

---

## Lock screen (EX-2)

### PL7.6 · Now Playing and remote commands                                   size: M
Place in the tree: outside › EX-2 lock screen › `Media.NowPlaying`
Repo · branch: NPRdoinglaundry · `pl/PL7.6-now-playing`
Needs: the playback engine (**gap:** no card owns `Media.Player`, the `AVPlayer`, audio session, interruption and route-change owner. Lean: the integrator assigns it to PL3.1b's split, since the brief plays first), PL7.10 (the lock-screen choice), C40.4 (the artwork)      Unblocks: P35, T05d

Why: your brief keeps going with the phone locked, and you can pause, skip and scrub it from the lock screen, your AirPods or the car without opening the app.

Inputs:
- Contract 07 §6.
- Reference §C40 (EX-2: title, subtitle, ↺15 ‖ 30↻), §C24/C25 (in-app transport; "the media keys and the lock screen are plumbing's").
- app-reference §10 (`AudioPlaybackAttributes` never requested), §12.1 (`UIBackgroundModes` includes `audio`).

Spec:
- `Media.NowPlaying` (`@MainActor final class`), owned by `Media.Player`. The only writer of `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
- On play, it sets:
  - title and artist per contract 07 §6's table, reading `Outside.lockScreenDetail` (PL7.10)
  - artwork (`MPMediaItemArtwork` from C40.4's renderer, cached per brief id)
  - `MPMediaItemPropertyPlaybackDuration`, `MPNowPlayingInfoPropertyElapsedPlaybackTime`, `MPNowPlayingInfoPropertyPlaybackRate`, `MPNowPlayingInfoPropertyMediaType = .audio`, `MPNowPlayingInfoPropertyIsLiveStream = false`
- It updates elapsed time and rate **only on state changes** (play, pause, seek, part change, rate). The system extrapolates, and a timer write is a battery cost and a known jitter source.
- Part change (brief): when the spoken part changes, the title updates (detail on) or "part n of m" updates (detail off).
- `MPRemoteCommandCenter`:
  - enabled: `play`, `pause`, `togglePlayPause`, `skipBackward` (15), `skipForward` (30), `changePlaybackPosition`
  - disabled: next/previous track, ratings, like
  - each handler returns `.success` or `.noActionableNowPlayingItem` and calls the player's own API, so lock-screen and in-app controls share one path
- Clearing: on stop, end or sign-out, `nowPlayingInfo = nil` and the handlers are removed.
- Audio session `.playback`, mode `.spokenAudio` (the system pauses rather than ducks for navigation prompts). Interruptions are the player's job, and Now Playing mirrors them.

Tests (layer 5, a fake info center and command center behind protocols):
- `playing a brief publishes title, artist, duration, elapsed and rate`
- `with lock-screen detail off the title says tuesday's brief, never the part's words`
- `with detail on the title is the part being spoken`
- `a part change updates the title once`
- `skip forward from the lock screen moves 30 seconds through the player's own api`
- `scrubbing from the lock screen seeks the player`
- `stopping clears now playing and removes the handlers`
- `sign-out clears now playing`
- `no timer writes elapsed time` (a count of writes over a simulated 60 s of playback is ≤ the state changes)

Proof: device recording (founder's phone, layer 11) of the lock screen, Control Center and AirPods pause, light and dark, detail off and on.

Watch out: a part title can be long. The system truncates, but **never put the brief's words in the artist field**, which shows in more places (CarPlay lists, the watch).

---

### PL7.7 · The recording Live Activity, on the new recorder                  size: S
Place in the tree: outside › EX-2 lock screen › recording Live Activity
Repo · branch: NPRdoinglaundry · `pl/PL7.7-recording-activity`
Needs: #56 `RVoiceComposer` and the journal's voice recording path (PL3.1a `sendVoice`), INT7.1      Unblocks: X10g (removing the duplicate widget)

Why: while you're recording a voice note, the lock screen shows it's recording and lets you stop, exactly as today.

Inputs:
- app-reference §10:
  - `VoiceRecordingAttributes` (static `startTime`; `ContentState { recordingDuration, isRecording }`), compiled into the app and the widget
  - started by `AudioRecordingManager.swift:358-362` with `pushType: nil`
  - "stop" links `retrospect://stop-recording`
- PL5.2 (`.stopRecording` destination).

Spec:
- `Media.RecordingActivity`: `start(at:)` requests the activity when `ActivityAuthorizationInfo().areActivitiesEnabled`; `update(duration:)` at most once a second while the screen is off (the activity shows a system timer with `Text(timerInterval:)`, so updates are rare); `end()` with `.immediate`.
- The new recorder calls it. The router's `.stopRecording` reaches the new recorder (a bridge listed in the PR).
- **No words are ever shown**, only the timer and stop (contract 07 §6). Its look stays as today until Paper draws it (README §8, "also asked elsewhere").

Tests: `starting a recording requests one activity` · `stopping ends it immediately` · `a stop link ends the recording and the activity` · `no activity is requested when they're disabled`.

Proof: device recording.

---

## Notifications (EX-3)

### PL5.3 · Notification categories and taps                                 size: M
Place in the tree: outside › EX-3 notifications › `Push.Categories`, `Push.Taps`
Repo · branch: NPRdoinglaundry · `pl/PL5.3-push-taps`
Needs: PL5.1 (registration, first run's), PL5.2 (+ the `.compose` and `.goal` destinations, contract 07 §11.3), PL7.2, INT7.2      Unblocks: P36, PL7.9, T05d

Why: tapping a notification opens exactly what it's about, and "play" starts the brief straight away.

Inputs:
- Contract 07 §5.2, §7; push fixtures.
- app-reference §1.1 (`AppDelegate` tap handler `:32-47`, `willPresent` `:26-29`), §9 (old local notifications and their identifiers), §11.1 (`ShowPodcastFromNotification`, `PlayPodcast` with no observer).

Spec:
- `Push.Categories.register()` sets `UNUserNotificationCenter.setNotificationCategories` once at launch:
  - `BRIEF_READY` and `EPISODE_READY`, each with action `PLAY` (title "play", options `.foreground`)
  - `QUESTION`, `CHECK_IN` and `EXPORT_READY` with no actions
  - every category gets `hiddenPreviewsBodyPlaceholder` "retrospect" and no `.customDismissAction`
- `Push.Taps.handle(response:)`:
  1. decode `r` with `Outside.PushPayload`, then `Routing.Parser.parse(link)`; an unknown kind or an unparsable link opens the app with nothing routed
  2. `UNNotificationDefaultActionIdentifier` → `router.open(destination)`
  3. `PLAY` → `router.open(destination)` plus `Media.Player.play(…, autoplay: true)` once the destination's data has loaded (a pending intent consumed by the player, never a play before sign-in)
  4. log `pushTapped(kind:, action:)` with no ids
- `willPresent` (in the foreground): `[]` for `briefReady` and `episodeReady` when that brief or episode is already on screen; otherwise `[.banner, .list]`. Never `.badge` (we don't use the badge).
- **Bridge:** the old `ShowPodcastFromNotification` post stays for local notifications the old app already scheduled, until X10g. The dead `PlayPodcast` post is a findings-log entry here, not a fix.

Tests (layer 5):
- `a brief-ready tap opens that brief`
- `play on brief-ready opens and plays it once`
- `play before sign-in waits and plays after the brief has loaded`
- `a question tap opens the guess`
- `an unknown kind opens the app and routes nowhere`
- `a link that fails the parser routes nowhere`
- `a brief-ready banner is hidden while that brief is on screen`
- `categories register once`
- `no log carries an id or a link`
- every push fixture decodes

Proof: test output; `xcrun simctl push` runs with each fixture (screenshots of the result, test account).

Watch out: `didReceive` must call its completion handler on every path, including unknown kinds, or iOS stops delivering.

---

### PL7.9 · Background refresh from the silent push                            size: S
Place in the tree: outside › EX-3 notifications › silent refresh
Repo · branch: NPRdoinglaundry · `pl/PL7.9-silent-refresh`
Needs: PL5.1, PL5.3, PL7.8a, PL3.1b (brief), PL3.4 (episodes; brief-only until then), BE7.7      Unblocks: an up-to-date widget, T05d

Why: the widget shows today's brief, and the brief plays instantly, even if you haven't opened Retro yet today.

Spec:
- `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (INT7.2 bridge) → `Push.Refresh.handle(scope:)`:
  - refetch the scoped reads (`brief.latest`, episodes)
  - run `Store.InboxImporter` (PL7.4) and an outbox drain
  - rewrite the widget snapshot (PL7.8a)
  - prefetch the brief's audio only on Wi-Fi without Low Data Mode (`Media.Source`)
  - complete with `.newData`, `.noData` or `.failed` within 25 s (iOS allows about 30)
- A `BGAppRefreshTask` (`com.shauryanarang.Retrospect.outside.refresh`, added to `BGTaskSchedulerPermittedIdentifiers` by INT7.2) does the same at most every 4 hours. It's the fallback when pushes don't arrive.

Tests: `a refresh for the brief refetches it and rewrites the snapshot` · `audio prefetches only on unconstrained wifi` · `the handler always completes within 25 seconds, even offline` · `an unknown scope does nothing and completes no data`.

Watch out: never schedule anything visible from here (no local notifications). Background time is for data only.

---

### PL7.10 · Notification preferences and the lock-screen choice              size: S
Place in the tree: outside › EX-3 notifications › preferences
Repo · branch: NPRdoinglaundry · `pl/PL7.10-notification-preferences`
Needs: PL1.1, PL2.4 (cached reads), BE7.3      Unblocks: the settings screen (contract 06), PL7.6, PL7.8a

Why: what you choose in settings about notifications and the lock screen is exactly what happens.

Spec:
- `Push.Preferences`: `load()` (`CachedRead` `notifications.preferences`) and `set(_ partial:)`, sent through the outbox (operation `notifications.preferences`, last write wins, so a PUT of values is idempotent).
- `Outside.LockScreenDetail` is a device-local Bool in the app group `UserDefaults(suiteName:)`, key `outside.lockScreenDetail`, default `false`. Changing it rewrites the widget snapshot and republishes Now Playing.
- The system permission state (`UNUserNotificationCenter.notificationSettings`) is surfaced as `Push.Permission` (`notDetermined`, `denied`, `authorized`, `provisional`, `unknown`) for the settings screen. Asking is first run's job (PL5.1).

Tests: `defaults load with no network` (fixture cache) · `a change is queued and sent` · `turning lock-screen detail on rewrites the snapshot and now playing` · `the lock-screen choice is per device and never sent to the server`.

---

## Widgets (EX-4)

### PL7.8a · The widget snapshot writer                                       size: M
Place in the tree: outside › EX-4 widgets › data › `Outside.SnapshotWriter`
Repo · branch: NPRdoinglaundry · `pl/PL7.8a-widget-snapshot`
Needs: PL7.2, PL3.1b (`BriefSlot`), PL7.10, PL3.4 (episode fallback; brief-only until then)      Unblocks: PL7.8b, P37, PL7.9

Why: the widget always shows the same state as the brief card in the app, decided in one place.

Inputs: contract 07 §3; fixtures `widget.snapshot.*`; PL3.1b (`BriefSlot`: `.off`, `.making`, `.quiet`, `.ready`).

Spec:
- `Outside.SnapshotWriter` (an actor in `Platform/`) observes `LiveJournalData.brief`, the player's state for today's brief, `Session` sign-in, `LockScreenDetail`, and later the episodes.
- It maps to `WidgetSnapshot` with one pure function `snapshot(brief:playback:episode:signedIn:detail:offNoticeShown:now:)`:
  - `.off` → `off` (plus the episode, after the notice has been shown once)
  - `.making` → `making`; `.quiet` → `quiet`; `.ready` → `ready`
  - playing → `playing`; heard to the end → `played`
  - a load failure → `unavailable`
  - signed out → `signedIn: false` and no brief fields
- It writes atomically (PL7.2), **only when the encoded bytes differ** from the last write, then calls `WidgetCenter.shared.reloadTimelines(ofKind: "RetroBriefWidget")` and `ofKind: "RetroTalkWidget"`.
- `briefOffNoticeShown` becomes true after the first snapshot with `off` has been written for 24 hours (the widget showed it "once").
- At sign-out the snapshot is rewritten as signed out **before** the session clears, so a stale headline is never left on the home screen.

Tests (layer 5):
- one mapping test per snapshot fixture (`the ready brief maps to the ready snapshot fixture`, …)
- `an unchanged state writes nothing and reloads nothing`
- `sign-out rewrites the snapshot before credentials are cleared`
- `the brief-off notice shows for a day, then the episode`
- `playing and played follow the player`

---

### PL7.8b · Widget timeline, privacy and intents                             size: M
Place in the tree: outside › EX-4 widgets › data › timeline provider + intents
Repo · branch: NPRdoinglaundry · `pl/PL7.8b-widget-timeline`
Needs: PL7.8a, INT7.1 (deployment target 18.1, app group), PL7.6 / `Media.Player` (for the play intent)      Unblocks: P37 (with C40.1–C40.3)

Why: the widget is right without the app open, keeps your brief's words private when the phone is locked if you want, and plays the brief with one tap.

Inputs: contract 07 §3 (actions, timeline); Apple: `TimelineProvider`, `AudioPlaybackIntent`, `.privacySensitive()`, `widgetURL`, `containerBackground`.

Spec:
- Two widgets:
  - `RetroTalkWidget`: `.systemSmall`, kind `RetroTalkWidget`; it shows no personal content, so it has a static timeline (`.never`)
  - `RetroBriefWidget`: `.systemMedium`, kind `RetroBriefWidget`; it replaces the Xcode template in `RetrospectWidgets.swift`. The bundle keeps the control widget and the recording Live Activity
- `BriefProvider.timeline`:
  - reads the snapshot (PL7.2), one entry now, one at the next local midnight with the state rolled (contract 07 §3), policy `.atEnd`
  - a missing or unreadable file → the `unavailable` look
  - `placeholder` and `getSnapshot(in: context.isPreview)` use built-in invented content (never the person's)
- Privacy:
  - when `lockScreenDetail == false`, the headline and episode title views carry `.privacySensitive()`; the system redacts them on the lock screen and in StandBy while locked
  - the snapshot file's protection means a phone that hasn't been unlocked since boot can't read it, and that shows the `unavailable` look ("open retrospect…")
- `PlayBriefIntent: AudioPlaybackIntent` (`@Parameter briefId`) is compiled into the app and the widget. `perform()` runs in the app's process and calls `Media.Player.play(briefId:)` (cached audio first). `PauseIntent` likewise.
- The talk action is `Link(destination: URL(string: "retrospect://compose")!)` (contract 07 §7).
- Relevance: `TimelineEntryRelevance(score: 1)` when ready and unplayed, otherwise 0.2 (Smart Stack).

Tests (layer 5 for the provider and intents; layer 6 snapshots are C40's):
- `the provider shows the snapshot's state`
- `a missing snapshot shows unavailable`
- `the midnight entry rolls played back to making`
- `the preview never shows the person's content`
- `the play intent plays the brief by id through the player`
- `the play intent with no cached audio and no network fails quietly and leaves the widget unchanged`
- `privacy-sensitive is applied exactly when lock-screen detail is off`

Proof: device screenshots of the home screen (light, dark, tinted, clear), the lock screen in StandBy with detail off (redacted) and on, and a recording of play from the widget.

Watch out: interactive widget buttons need iOS 17+, which INT7.1's 18.1 target covers. Test on the oldest supported iOS (18.1) runtime.

---

## Retiring the old (Platform side)

The safe order for anything on the phone:
1. **Stop writing:** the new code path is the only writer.
2. **Stop reading:** the new store or door is the only reader.
3. **Quarantine:** move the old files aside for one app version.
4. **Delete** in a later version.

The rollback until step 4 is to move the files back (a debug action and a one-line code path in the quarantine PR). After step 4 there's no rollback, which is why it waits a version.

### X01 · The retirement ledger                                               size: S
Place in the tree: outside › retiring the old › the ledger
Repo · branch: NPRdoinglaundry · `pl/X01-retirement-ledger`
Needs: —      Unblocks: every X byte (each cites its rows)

Why: before deleting anything, we know exactly what's old, what replaced it, and what it waits for, so nothing is half-alive and nothing is deleted early.

Spec:
- `docs/team/retirement-ledger.md`, generated by `scripts/retirement-ledger.py`. One row per old Swift file (the ~140 files outside `DesignSystemV2/`, `Platform/`, `Features/`, `Outside/`), plus each old route group, old table, old local file and old UserDefaults or Keychain key (app-reference §5, §6, §11.3, §12). Each row has: the replacement, the gate, the X byte, and its state (`live | switched-off | quarantined | deleted`).
- The script also lists, per old Swift file, the type names it declares and the other old files that reference them (a symbol grep), so each X10 PR can show its files are unreferenced once its screens go.
- CI check: every Swift file outside the new folders has a ledger row, and every row's file exists unless its state is `deleted`.

Tests: `the ledger lists every old swift file` · `a deleted row's file is gone`.

Rollback: n/a (a document and a check).

---

### X05a–X05c · Remove the old services                                     size: S each
Place in the tree: outside › retiring the old › old services
Repo · branch: NPRdoinglaundry · `pl/X05<x>-<service>`
Needs (each): every caller gone (X01's symbol grep shows zero references outside the file), the gate named below

| Byte | Removes | Callers that go first | Gate | Then unblocks |
|---|---|---|---|---|
| X05a | `ClaudeService.swift`, `AIServiceManager.swift`, `OpenAIservice.swift` | journal and podcasts screens (X10a, X10c), the you screens (X10e) | G2, G3, G5 | X07a, X07b |
| X05b | `TTS.swift` fallbacks (keep the ElevenLabs proxy path; `ElevenlabsService`'s Keychain read moves to `Session.Store` in PL1.3) | old players (X10c) | G3 | X06d |
| X05c | `GoogleDocsService.swift`, `Models/GoogleDocsModel.swift`, `GoogleDocsIntegrationView.swift`, `GoogleDocsOnboardingScreen.swift` | old onboarding and settings (X10b, X10f) | G1, G6 | X09 (the google-api package) |

Tests: the app builds; the full suite passes; `no reference to <type> remains` (grep test per PR). Rollback: revert the PR (code only, no data).

---

### X06a · Quarantine the old entry files                                     size: S
Place in the tree: outside › retiring the old › old local data › entries
Repo · branch: NPRdoinglaundry · `pl/X06a-quarantine-entries`
Needs: PL2.6 (`LegacyImport.Report.confirmed == true` **on this phone**, checked at runtime), G2 shipped and X10a merged (the old writers of `Entries/*.json` are gone), the founder's answer on unsent old entries (plumbing question, PL2.6)      Unblocks: X06f

Why: there's one copy of your entries on the phone (the new store), and the old copy is kept aside, not deleted, until we're sure.

Spec:
- On launch, if confirmed and not yet done: move `Documents/RetrospectData/` (Entries, Audios, Images, `index.json`) to `Application Support/Platform/legacy-quarantine/RetrospectData/` with `FileManager.moveItem`, a rename on the same volume, so it's instant and atomic per folder.
- Re-point any `media_path` in the store that referenced `RetrospectData/Audios` (PL2.6 stores relative paths) by a prefix update **in the same transaction** as recording `quarantined_at` in `legacy_ledger`.
- Videos are excluded until X06e.
- If not confirmed, it does nothing and logs `quarantineSkipped(reason: notConfirmed)`.
- **Rollback:** the debug action `-RestoreLegacyQuarantine` (and a hidden support action) moves the folder back and reverses the prefix. Tested.

Tests (layer 5, fixture folders):
- `an unconfirmed import quarantines nothing`
- `a confirmed import moves the folder and repoints audio paths in one go`
- `voice notes still play after the move`
- `the restore action puts everything back byte for byte`
- `running twice does nothing the second time`

---

### X06b · `podcasts.json`: read once into the store, then aside              size: S
Needs: PL3.4 (episode cache), G3 shipped and X10c merged (the ten `TranscriptViewModel` writers are gone, app-reference §0.8)      Unblocks: X06f

Spec:
- One read of `Documents/podcasts.json` (`[TranscriptModel]` with a private mirror struct, never the old type). Any episode id not in the server's list is kept as a local-only row only if it has a local audio file; otherwise it's counted and dropped (the server is the truth for episodes).
- `tmp/podcast_<id>.mp3` files are not moved (they're purgeable; `Media.Source` re-downloads).
- Then the file moves to quarantine.
- **Rollback:** move it back.

Tests: `episodes already on the server aren't duplicated` · `a local-only episode with audio is kept` · `a local-only episode without audio is dropped and counted` · `an unreadable file is quarantined untouched and counted`.

### X06c · Old UserDefaults keys                                             size: S
Needs: each key's owner gone (X01 lists owners): `rich_goals` and `simple_goals` after PL3.5 reconciles (G4); `unifiedEntries` and `hasCompletedFileStorageMigration` (G2); `saved_podcasts` (G3); `onboarding*` (G1); `videoJournalEntries` (X06e).
Spec: remove only the listed keys, after copying each value's checksum to `legacy_ledger`. No rollback is needed for keys whose data lives in the store (confirmed by the checksum).
Tests: `only listed keys are removed` · `a key whose owner is still live is kept`.

### X06d · The old Keychain service `com.retrospect.api`                      size: S
Needs: PL1.3's migration live for two app versions, X05b (`ElevenlabsService` no longer reads it), X02a's floor above the last version that reads it.
Spec: delete accounts `jwt_token`, `user_id`, `apple_user_id` under the old service, once. Their content was migrated by PL1.3, and the old 30-day token is dead after X07e.
Rollback: none needed. A missing old item only matters to an old build, and the floor excludes those.
Tests: `the three old items are deleted once` · `the new session items are untouched`.

### X06e · Old video journal files                                            size: S (+ a one-screen sheet drawn in Paper first)
Needs: X03a (the video journal screens are gone), the founder's answer (README §8, "also asked elsewhere"; lean: offer "save your old videos to photos" once).
Spec:
- If `Documents/RetrospectData/Videos/*.mov` exist: show the one-time sheet. "save to photos" uses `PHPhotoLibrary` with add-only permission, so nothing is read from Photos. "not now" offers again at most twice. Either way, the folder moves to quarantine afterwards.
- The text of video entries was imported by PL2.6.

Tests: `videos saved to photos are each saved once` · `the offer shows at most three times` · `without videos there's no sheet`.

### X06f · Empty the quarantine                                               size: S
Needs: X06a/b/e quarantines at least 30 days old **and** made by an earlier app version than this one.
Spec: delete `legacy-quarantine/` and `inbox/unreadable/` items older than 30 days.
Rollback: none. That's why it waits a version and 30 days, and why the PR lists the founder's yes.
Tests: `a quarantine from this version is never deleted` · `one older than 30 days from an earlier version is deleted`.

---

### X09 · The final sweep                                                     size: M
Place in the tree: outside › retiring the old › final sweep
Repo · branch: NPRdoinglaundry · `pl/X09-final-sweep`
Needs: X03a–d, X04, X05a–c, X06a–f, X07a–h, X10a–g      Unblocks: the App Store build

Why: the app is only the new code, so it's faster to build, smaller to download and has nothing hidden in it.

Spec, one commit per kind:
- files the ledger marks deleted that still exist
- assets in `Assets.xcassets` that no code references (a script lists them)
- fonts no longer used (`UIAppFonts`: Libre Baskerville, Adamina, EB Garamond, Hedvig Letters Serif; Exposure stays)
- `google-api-objectivec-client` if X05c removed its last use
- the unused `Retrospect fina (SwiftUI).entitlements`
- the stray top-level `CFBundleURLSchemes` key
- `GoogleService-Info.plist` (no Firebase linked)
- the `FRAMEWORK_SEARCH_PATHS` absolute path (app-reference §12.3)

Integrator edits for `project.pbxproj` and `Info.plist` go in its own PR.

Tests: the app builds; the full suite passes; the binary size before and after is in the PR.

Rollback: revert.
