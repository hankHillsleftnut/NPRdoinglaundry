# App plumbing engineer · plan

You build everything inside the app that isn't a pixel: the typed client that talks to the backend's `/v2` doors, the session, the local store and its outbox, the deep-link router, push, payments, analytics, and the live data each screen reads. You never draw UI. Read [README.md](./README.md) and [context.md](./context.md) before your first byte; this file assumes both. Every byte is a card in [byte-card.md](./byte-card.md)'s shape: the near ones are written in full in [plumbing/](./plumbing/), the far ones are outlined in [plumbing/outline.md](./plumbing/outline.md) and filled in before their phase starts.

## 1. Your mission in one paragraph

Today the app talks to the backend through one untyped singleton (`RetrospectAPIClient`) that sends `[String: Any]` bodies, has no retries, signs you out on any 401, keeps entries in JSON files, drops failed uploads on the floor, and has no push, no StoreKit and no tests that run. You build the replacement as a separate, new layer beside it: typed, testable, offline-first, and safe to adopt one flow at a time. The old code keeps running the old screens until each flow's ship gate retires them (README §7). Nothing you build depends on old code, and old code never depends on yours, except at the explicit bridges in §7.

## 2. What you own, and what you never touch

| You own | You never touch |
|---|---|
| `Retrospect/Retrospect/Platform/**` (new; everything you write lives here) | `Retrospect/Retrospect/DesignSystemV2/**` and `Features/**` views (the UI engineer) |
| `Retrospect/RetrospectTests/Platform/**` and `Retrospect/Platform.xctestplan` | Any existing file under `Views/`, `Services/`, `Models/` except the bridges in §7, each in its own byte |
| The `Live…` implementation of each flow's data protocol | `Platform/Flows/<Flow>.swift` protocols (the integrator writes them from the contract) |
| `Retrospect.entitlements`, `Info.plist` keys and capabilities, when a byte says so | `backend/**`, the agent repo (the backend engineer) |
| `PrivacyInfo.xcprivacy`; packages added through Xcode with `Package.resolved` | `docs/team/**`, `.github/workflows/**`, `.swiftlint.yml`, `project.pbxproj` settings beyond what a byte names (ask the integrator); any contract (propose; the integrator decides) |

If a byte seems to need a file outside your column, stop and ask the integrator.

## 3. Ground truth (from the 21 Oct code map; trust this over older docs)

The full line-level reference (every anchor, verbatim excerpts, all 454 top-level type names) is [reference/app-reference.md](./reference/app-reference.md). Read its §1, §2, §4, §5 and §15 before PL0.1.


- **Project:** one Xcode project, file-system-synchronized groups: a new `.swift` file anywhere under `Retrospect/Retrospect/` joins the app target automatically. Swift 5 mode, **no strict concurrency** on the app target. Deployment target **iOS 18.1** for the app; extensions are 26.x. Every API you choose must work on 18.1.
- **Targets:** app, `RetrospectTests` (Swift Testing, 8 tests), `RetrospectUITests` (template), `RetrospectWidgetsExtension` (Control widget, recording Live Activity; the widget itself is still the Xcode template), `ScreenTimeReport`. No share extension, no notification service extension.
- **The shared scheme's TestAction has no testables**, so `xcodebuild test` runs nothing today. CI's `ios` job only builds.
- **Packages:** GoogleSignIn (≥ 8) and the Google REST client **pinned to `branch = main`, with no committed `Package.resolved`** (it's gitignored). Builds aren't reproducible.
- **Entitlements:** Sign in with Apple, HealthKit, app group `group.com.retrospect.shared`. No `aps-environment`, no associated domains. Background modes: audio, fetch, processing (no `remote-notification`).
- **Networking:** `Services/RetrospectAPIClient.swift`, `ObservableObject` singleton, not `@MainActor`. Base URL `https://retrospect-api.onrender.com`; DEBUG override via `-devAPIBaseURL`. Request timeout 480 s (sized for the synchronous podcast route). Generic `request<T>` with `[String: Any]` bodies, `JSONDecoder.apiDecoder` (snake_case, ISO 8601 with or without fractions), envelope `{success, data?, error?}`. **A 401 signs you out globally and clears the sign-in gate.** No retries, no reachability, no queue.
- **Bypasses:** `ElevenlabsService` calls `/speech/synthesize` with its own URLSession and **its own copy of the Keychain identifiers**; `GoogleDocsService` calls Google directly; `OpenAIservice` is dead code with an empty key.
- **Session:** private Keychain helpers in the client; service `com.retrospect.api`, accounts `jwt_token`, `user_id`, `apple_user_id`; no accessibility class set, **so the default `WhenUnlocked` applies and nothing can read the token while the phone is locked** (an outbox drain in the background would fail today); no access group. There's **no durable "signed in before" flag**: `signOut()` deletes `apple_user_id`, and `onboardingSignedIn` is cleared by sign-out, by the end of onboarding and by Replay Onboarding (`DarkSettingsView.swift:1353`, literal key strings). Sign in with Apple uses **no nonce**. `refreshToken()` signs out and throws. Sign-out means Keychain delete **plus** `OnboardingState.clearSignInGate()` (UserDefaults `onboardingSignedIn`).
- **Storage:** no Core Data, no SwiftData. Entries: `FileStorageManager` (JSON per entry plus media files, `index.json`) via `@MainActor EntryManager.shared`. Goals: UserDefaults `rich_goals` via `GoalsManager.shared` (not `@MainActor`). Episodes: `Documents/podcasts.json`, **written by about 10 separate `TranscriptViewModel` instances**.
- **Entry upload:** fire-and-forget `Task` POSTing `/content`, failures printed and lost. PR #35 removed the double voice upload and, deliberately, **sends no `Idempotency-Key`** (an explicit key would have re-identified older entries and duplicated them on resync); the backend dedups by text and day. A stale comment in `VoiceRecordingView.swift` still claims the upload is keyed by entry id.
- **Composition:** no dependency injection; every service is `static let shared`. The root view is an if/else ladder in `RetrospectApp.swift` keyed on onboarding, `apiClient.isAuthenticated`, Face ID. Deep links and notification taps travel as string-named `NotificationCenter` posts and UserDefaults flags.
- **Payments:** `SubscriptionManager` has no StoreKit; `isSubscribed` is always false except under the DEBUG `-MockProEntitlement` flag. Its header records the rule: **entitlement only from a backend-validated StoreKit transaction**. Existing product ids: `com.retrospect.premium.monthly` and `com.retrospect.premium.yearly` (keep them unless the founder says otherwise). Prices disagree three ways in code: `SubscriptionManager` $19.99 / $239.99, `PaywallView` $12.99 / $139.99 (its subscribe action is a TODO). **The founder's decision (21 Oct): $19.99 a month; $199.99 a year (17% off) with the first month free on yearly.** Every typed-in price is removed; the app always shows the store's localized price.
- **Push:** local notifications only (`PodcastNotificationService`). The Live Activities pass `pushType: nil`. `PlayPodcast` is posted (`RetrospectApp.swift:313`) but nothing observes it; observers added in `onAppear` are never removed; the recurring reminders scheduled at launch are usually dropped because the authorization check hasn't loaded yet (`PodcastNotificationService.swift:287`). Note these for PL5.x; don't fix old code outside a bridge byte.
- **Tests host the whole app:** Swift Testing with the app as host, so every test run boots `AppDelegate` (subscriptions configure, background tasks register).
- **Stores persist absolute file URLs** (entries and media under `Documents/RetrospectData/`; `index.json` rewritten by re-reading every entry on each save); downloaded episode audio goes to `tmp/podcast_<id>.mp3`, which iOS may purge.
- **Analytics / crash reporting:** none. `GoogleService-Info.plist` exists unused.
- **Type names already taken** in the module (one module, synchronized groups): `APIError`, `UserProfile`, `PodcastEpisode`, `BackendGoal`, `AnyCodable`, `SubscriptionPlan`, `GenerationType`, `Citation`, and more. Collisions are the most likely way your first PR breaks the build.

## 4. The architecture you're building

```
 Features/<Flow>/ (UI engineer)                         ← screens read only a protocol, via .environment
        │  JournalData (protocol + models, Platform/Flows/, integrator)
        ├── SampleJournalData   (UI engineer; the default in DEBUG, previews and T02)
        └── LiveJournalData     (you, PL3.1)
                 │
   Platform/Repositories/   Journal, CachedRead<T>, Loadable<T>       ← cache first, writes through the outbox
                 │                         │
   Platform/Backend/  Client (actor) ── Platform/Store/  LocalDatabase (GRDB) · Outbox (actor) · LegacyImport
                 │
   Platform/Session/  Store (Keychain) · Manager (refresh, sign-out) · AppleSignIn · GoogleSignIn · InviteCenter · LegacyMirror
   Platform/Routing/  Destination · Parser · Router          Platform/Push/  Registrar
   Platform/Billing/  Store (RevenueCat)                     Platform/Media/  Source (signed audio, offline copies)
   Platform/Analytics/ (later)                               Platform/Log.swift · Platform/Environment.swift · Platform/Bridges.swift
```

Rules that make it safe:
1. **One namespace per area, no bare global names.** Everything is nested in caseless enums declared in `Platform/Platform.swift`: `Platform`, `Backend`, `Session`, `Store`, `Repositories`, `Flows`, `Routing`, `Push`, `Billing` (not `Purchases`, which is RevenueCat's module name), `Analytics`, `Media`. This removes every collision with the module's 454 old type names (`APIError`, `Entry`, `UserProfile`…) at once. Never add a bare `Database`, `Row`, `Entry` or `Router`.
2. **Concurrency by construction**, in Swift 5 mode: networking, storage, session and outbox are `actor`s; anything a view observes is `@MainActor @Observable`; every value crossing a boundary is a `Sendable` struct or enum. No singletons in new code: one `Platform.Environment` is built at launch (PL0.3) and injected with `.environment(_:)`; tests and previews build their own (`preview()`).
3. **Contract-first models.** Each `/v2` response has a `Decodable` model written from `docs/team/contracts/`, and decoding tests run against the same fixtures the backend's zod schemas validate (testing.md layer 4). Unknown enum values decode to `.unknown`.
4. **Screens never see the network.** The UI engineer builds against the flow's protocol and its sample; your `Live…` type conforms to the same protocol; the integrator's wiring PR swaps one line.
5. **The old client is frozen**, not extended. New calls go only through `Backend.Client` to `/v2`. Old screens keep the old client, made safe by two bridges (its 401 refreshes first; its sign-out signs the new session out).
6. **Errors are values the UI can show.** `Backend.Failure` is a closed enum with one case per contract-00 code plus `offline`, `timedOut`, `decoding`, `transport` and `unknown(code:)`, each with a plain-words `message` and `isRetryable`, so every error state (C39) has something true to say.
7. **Nothing is lost, nothing is sent twice.** Every write is a local row and an outbox row in one transaction, sent with an `Idempotency-Key` that is the entity's own id. Reads show the cache first, then fresh data.
8. **No content leaves the phone except to our backend.** `Platform.Log.Event` is a closed enum with no `String` or `URL` payloads; analytics events are typed the same way; tests scan every sink.

## 5. The decomposition (README §3: big picture → flows → systems → modules → types → one PR each)

```
Retrospect, on real data
├── Foundations (phase 0)
│   ├── packages pinned ........................ PL0.4
│   ├── tests that run (T00) ................... PL0.1  Platform.xctestplan · test-host guard · StubProtocol · Fixtures · TestClock
│   ├── the folder, namespaces, the log ........ PL0.2  Platform.swift · Log.Event · LogSink
│   ├── the composition root ................... PL0.3  Platform.Environment · live() · preview()
│   └── any screen on live data (T02, data) .... T02a   Platform.LaunchOptions (-Data, -Environment, -Screen, -State, -Account)
├── Talking to the backend (phase 0–1)
│   ├── the client ............................. PL1.1a Backend.Environment/Configuration · Endpoint · Envelope · Failure · Coding
│   │                                            PL1.1b actor Backend.Client · headers · Endpoints.Meta
│   ├── resilience ............................. PL1.2  RetryPolicy · full-jitter backoff · Reachability (NWPathMonitor)
│   └── version floor .......................... PL1.6  AppVersion · Environment.updateRequired
├── Who you are (phase 0–1)
│   ├── the Keychain ........................... PL1.3  KeychainBackend · Credentials · actor Session.Store · install sentinel · hasSignedInBefore
│   ├── signing in ............................. PL1.4a Nonce · AppleSignIn
│   │                                            PL1.4b GoogleSignIn (nonce, basic scopes)
│   │                                            PL1.4c LegacyMirror · token upgrade · ElevenLabs keeps working
│   ├── staying signed in, signing out ......... PL1.5  actor Session.Manager · single-flight refresh · signOut(force:) · old-client bridges
│   └── getting in ............................. PL1.7a access + redeem · PL1.7b pending code, auto-apply · PL1.7c your three invites
├── Every way in (phase 1)
│   ├── links, widgets, shortcuts .............. PL5.2  Routing.Destination · Parser · Router · onOpenURL + universal-link bridges
│   ├── push registration ...................... PL5.1  Push.Registrar
│   └── notification taps ...................... PL5.3  categories → Router
├── On the phone first (phase 1)
│   ├── the engine ............................. PL2.0  GRDB, measured
│   ├── the schema ............................. PL2.1  Store.LocalDatabase · v1 (entries, outbox, cached_documents, meta)
│   ├── never lose a write ..................... PL2.2a Outbox queue + one transaction · PL2.2b drainer + triggers + BG task
│   ├── old screens use it too ................. PL2.3  EntryManager bridge
│   ├── show what you had ...................... PL2.4  Loadable · Repositories.CachedRead
│   ├── goals and you, cached .................. PL2.5
│   ├── what's already on the phone ............ PL2.6  Store.LegacyImport · v2 (legacy_ledger, legacy_goals)
│   └── one copy of everything ................. X06    retire the old files
├── Flows on real data (phases 1–6)
│   ├── journal ................................ PL3.1a send/today · b brief/audio (Media.Source) · c guesses · d entries/search/edit · e took/"not right"
│   ├── conversation (v2) ...................... PL3.2  deferred
│   ├── first run .............................. PL3.3
│   ├── podcasts ............................... PL3.4
│   ├── goals .................................. PL3.5
│   ├── you .................................... PL3.6
│   └── settings and account ................... PL3.7
├── Paying (phase 2)
│   ├── RevenueCat ............................. PL6.1  Billing.Store
│   ├── entitlement ............................ PL6.2
│   └── the old paywall ........................ PL6.3  SubscriptionManager bridge
├── Knowing what breaks (later; vendor is the founder's call)
│   ├── analytics facade ....................... PL4.1
│   └── crash reporting ........................ PL4.2
└── Shipping
    └── privacy manifest ....................... PL7.1
```

## 6. The queue

Take bytes in this order unless the integrator re-orders the board. One byte per branch and PR (`pl/<id>-<slug>`); a split byte is one PR per part. **Status:** `full` = card written, ready when its needs merge; `outline` = filled in before its phase.

| # | Byte | Card | Size | Needs | Status |
|---|---|---|---|---|---|
| 1 | PL0.4 Reproducible packages | [PL0.4](./plumbing/PL0.4.md) | S | — | full |
| 2 | PL0.1 Tests that run (T00) | [PL0.1](./plumbing/PL0.1.md) | M | PL0.4 | full |
| 3 | PL0.2 Folder, namespaces, log | [PL0.2](./plumbing/PL0.2.md) | S | PL0.1 | full |
| 4 | PL0.3 Platform.Environment | [PL0.3](./plumbing/PL0.3.md) | M | PL0.2 | full |
| 5 | PL1.1a/b Typed client | [PL1.1](./plumbing/PL1.1.md) | L | PL0.3, contract 00 | full |
| 6 | T02a Launch options (data half) | [T02a](./plumbing/T02a.md) | S | PL0.3, PL1.1 | full |
| 7 | PL1.2 Retries, reachability | [PL1.2](./plumbing/PL1.2.md) | M | PL1.1 | full |
| 8 | PL1.3 Session store | [PL1.3](./plumbing/PL1.3.md) | M | PL1.1 | full |
| 9 | PL1.6 Version floor | [PL1.6](./plumbing/PL1.6.md) | S | PL1.1, BE0.10 | full |
| 10 | PL1.4a/b/c Sign-in, legacy mirror | [PL1.4](./plumbing/PL1.4.md) | L | PL1.3, BE0.4, BE2.4 | full |
| 11 | PL1.5 Refresh, sign-out | [PL1.5](./plumbing/PL1.5.md) | M | PL1.4, BE0.4 | full |
| 12 | PL5.2 Typed router | [PL5.2](./plumbing/PL5.2.md) | M | PL0.3 | full |
| 13 | PL1.7a/b/c Invites | [PL1.7](./plumbing/PL1.7.md) | L | PL1.5, PL5.2, BE0.12, invite domain | full |
| 14 | PL2.0 GRDB, measured | [PL2.0](./plumbing/PL2.0.md) | M | PL0.3, PL0.4 | full |
| 15 | PL2.1 Schema v1 | [PL2.1](./plumbing/PL2.1.md) | M | PL2.0 | full |
| 16 | PL2.2a/b Outbox | [PL2.2](./plumbing/PL2.2.md) | L | PL2.1, PL1.2, PL1.5, BE1.1 | full |
| 17 | PL2.4 Cached reads | [PL2.4](./plumbing/PL2.4.md) | M | PL2.1, PL1.5 | full |
| 18 | PL2.3 EntryManager bridge | [PL2.3](./plumbing/PL2.3.md) | S | PL2.2, BE1.1 | full |
| 19 | PL2.6 Legacy import | [PL2.6](./plumbing/PL2.6.md) | M | PL2.1, PL2.3 | full |
| 20 | PL3.1a–e LiveJournalData | [PL3.1](./plumbing/PL3.1.md) | L | PL2.2, PL2.4, Flows/Journal.swift, BE1.x | full |
| 21 | PL5.1 Push registration | [outline](./plumbing/outline.md) | M | PL1.5, BE2.6 | outline |
| 22 | PL5.3 Notification taps | [outline](./plumbing/outline.md) | M | PL5.1, PL5.2, contract 07 | outline |
| 23 | PL6.1 RevenueCat | [outline](./plumbing/outline.md) | M | PL1.5, founder keys | outline |
| 24 | PL6.2 Entitlement | [outline](./plumbing/outline.md) | S | PL6.1, BE2.8 | outline |
| 25 | PL6.3 SubscriptionManager bridge | [outline](./plumbing/outline.md) | S | PL6.2 | outline |
| 26 | PL3.3 LiveFirstRunData | [outline](./plumbing/outline.md) | L | contract 01, BE2.x | outline |
| 27 | PL2.5 Cached goals and you | [PL2.5](./plumbing/PL2.5.md) | S | PL2.4, contracts 04, 05 | full |
| 28 | PL3.4 LivePodcastsData | [outline](./plumbing/outline.md) | L | contract 03, BE3.x | outline |
| 29 | PL3.5 LiveGoalsData | [outline](./plumbing/outline.md) | M | contract 04, PL2.5 | outline |
| 30 | PL3.6 LiveYouData | [outline](./plumbing/outline.md) | M | contract 05, PL2.5 | outline |
| 31 | PL3.7 LiveSettingsData | [outline](./plumbing/outline.md) | L | contract 06, PL6.2 | outline |
| 32 | X06 Retire the old local data | [outline](./plumbing/outline.md) | M | PL2.6 confirmed, ship gates, founder | outline |
| 33 | PL7.1 Privacy manifest | [outline](./plumbing/outline.md) | S | PL2.0, PL6.1 | outline |
| 34 | PL4.1 Analytics facade | [outline](./plumbing/outline.md) | S | PL0.2 | outline (analytics later) |
| 35 | PL4.2 Crash reporting | [outline](./plumbing/outline.md) | M | PL4.1, vendor | outline |
| — | PL3.2 Streamed conversation | [outline](./plumbing/outline.md) | L | contract 02 v2 | deferred to v2 |

Bytes that only wait on the backend or the founder don't block the queue: take the next one whose needs are merged and tell the integrator.

## 7. The bridges to old code (the only places you edit existing files, each in the byte named)

| Bridge | Where | Why | Byte |
|---|---|---|---|
| Test-host guard | `RetrospectApp.swift:15-23` (AppDelegate), `:147` (root) | tests stop booting the whole app | PL0.1 |
| Build and inject `Platform.Environment` | `RetrospectApp.swift:69-74`, `:242` | new code needs it | PL0.3 |
| Launch options for live data | the T02 hook in the app root | any screen on live data | T02a |
| Old Keychain items mirrored and the old token upgraded | `RetrospectAPIClient.swift:580-615` items, read by `ElevenlabsService.swift:81-101` | old screens and speech stay signed in | PL1.4c |
| Google callback forwarded | `RetrospectApp.swift:373-415` | Google sign-in completes | PL1.4b / PL5.2 |
| The old client's 401 refreshes and retries once before signing out | `RetrospectAPIClient.swift:559-568` | old screens stop logging people out every 15 minutes | PL1.5 |
| The old `signOut()` signs the new session out too | `RetrospectAPIClient.swift:118-128` | one sign-out | PL1.5 |
| `OnboardingState.clearSignInGate()` called by sign-out | `OnboardingState.swift:204-206` | sign-out has two halves | PL1.5 |
| Refresh and drain on becoming active | `RetrospectApp.swift:353-372` | stay signed in; unsent entries go | PL1.5, PL2.2b |
| BG task id for the outbox | `Info.plist` `BGTaskSchedulerPermittedIdentifiers`, AppDelegate `:15-23` | unsent entries go while the app sleeps | PL2.2b |
| `EntryManager.syncEntryToBackend` hands entries to the outbox | `EntryManager.swift:126-147`; stale comment `VoiceRecordingView.swift:357-358` | no more lost entries | PL2.3 |
| Router first in `.onOpenURL`, plus universal links | `RetrospectApp.swift:373-415` | one list of ways in | PL5.2 |
| Associated domains | `Retrospect.entitlements` | invite links open the app | PL1.7 |
| Push registration and taps | AppDelegate `:15-47`, entitlements, background modes | push | PL5.1, PL5.3 |
| `SubscriptionManager` over `Billing.Store` | `Services/SubscriptionManager.swift` | one source of entitlement | PL6.3 |

## 8. How you work

- **Worktree:** your own, off fresh `origin/main` of NPRdoinglaundry. Branch `pl/<byte-id>-<slug>`. One byte per branch and PR. Never stack on another open PR.
- **Drip in bit by bit (README §4):** each PR is the smallest complete thing: types with their tests, never types now and tests later. No compromise on tests, code quality, behaviour, completion or edge cases: a byte isn't done until every acceptance line is a yes.
- **Simulator:** you compile and run unit tests; you don't need to look at UI. Use the simulator the integrator assigns (README §6), derived data in your own folder, `df -h /` before every build, stop under 5 GB. Never create, clone or delete simulators or runtimes.
- **Before you push:** the app builds; `xcodebuild test -scheme Retrospect -testPlan Platform` passes; SwiftLint and SwiftFormat are clean on `Platform/`. Read every result.
- **No real backend in tests.** `URLProtocol` stubs, the shared fixtures, in-memory GRDB, a fake Keychain, an injected clock and random source. Real calls happen only on local staging with test accounts, through the integrator.
- **No personal content anywhere:** not in logs, analytics, crash reports or fixtures (fixtures are invented). Counts and types only. No secrets in source.
- **Report** after each PR, in the format in README §8.

## 9. Definition of done for every byte

Testing follows [testing.md](./testing.md): layers 4–5 are yours, plus T00 (PL0.1) and the data half of T02 (T02a).

1. Every acceptance line on the card is a yes; nothing outside the byte changed.
2. New code lives under `Platform/` in its namespace; no new global type names.
3. A test for every behaviour and every failure the code handles, named as a sentence; an offline test for anything that talks to the network; a retry test for anything idempotent; a no-content test for anything that logs.
4. The app builds; your tests pass; lint and format are clean; you read each result.
5. Old behaviour unchanged unless the byte is a bridge, and then the PR lists exactly what changed for old screens.
6. The PR body: what and why, the contract section, tests, proof, what's not done, and anything the founder or integrator must do.
7. You reviewed your own diff as a reviewer before pushing.

## 10. Things that will bite you

- **Name collisions** in the single module: namespace everything (§4 rule 1).
- **iOS 18.1:** check availability of every API you use (Observation, StoreKit, `BGTaskScheduler`, GRDB's minimums).
- **The old 401 behaviour** signs people out globally until PL1.5's bridge lands. Never route a new call through the old client.
- **Two halves of sign-out:** Keychain and `onboardingSignedIn`. Miss one and the app shows the wrong root screen.
- **ElevenlabsService's copied Keychain constants:** move the token and speech breaks unless you bridge it in the same byte.
- **`podcasts.json` has ten writers.** Don't touch it until the migration byte, and only as the integrator sequences it.
- **Keychain items outlive the app:** the install sentinel (PL1.3) must run before anything reads the session, and must tell an update from a reinstall by the old defaults keys.
- **Old entries have no keys:** never put an `Idempotency-Key` on an entry the old app sent (PR #35); only `origin = new` rows enter the outbox.
- **No `Package.resolved`:** a dependency can change under you. PL0.4 fixes it; until then, a sudden package build failure isn't your code.

## 11. Questions waiting on the founder

| Question | Blocks | My lean |
|---|---|---|
| The invite link's web domain | PL1.7 (entitlement), PL5.2 (parser host) | a short subdomain of the marketing site |
| Is the local database included in the phone's backup? | PL2.1 | yes (it's your journal; restores keep it), file-protected until first unlock |
| Add `POST /v2/auth/upgrade` (old 30-day token → v2 session) to contract 00, or does `/v2` accept old tokens until they expire? | PL1.4c | add the upgrade door: old tokens never reach `/v2` |
| Google sign-in client id (basic scopes) | PL1.4b | — |
| TestFlight builds: production only until Render staging exists? | T02a, PL1.1 | yes; local staging only from Xcode |
| The acknowledgement lines after you send something | PL3.1a | a set of five, lowercase, never claiming to have understood |
| Old entries that never reached the server (failed old uploads): send them once, or leave them on the phone? | PL2.6, X06 | send once, after the import is confirmed, relying on the backend's text-and-day dedup |
