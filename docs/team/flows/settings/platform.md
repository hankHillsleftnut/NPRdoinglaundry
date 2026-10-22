# Settings and account · Platform cards (client, live data, store, push, purchases, router)

The app engineer's Platform cards for area 06, plus the integrator's two (PL3.7.0 the protocol, W6 the wiring). The outline's **PL3.7 LiveSettingsData** (L) is split into ten PRs (PL3.7a–j). Three new bytes complete it: **PL6.4** (manage and restore, in `Billing`), **PL5.4** (the notification ask when the brief turns on) and **PL5.2s** (settings deep links). Contract: [../../contracts/06-settings.md](../../contracts/06-settings.md); errors and sessions: contract 00.

Architecture rules from `app-plumbing-engineer.md` §4 apply to every card: one namespace per area (`Flows.Settings`, `Billing`, `Session`, `Store`), actors for networking and storage, `@MainActor @Observable` for what views watch, `Sendable` values across boundaries, no singletons, closed `Backend.Failure`, every write either set-to-value (settings) or through the outbox with an idempotency key (exports and imports), and `Platform.Log.Event` with no `String` payloads.

Order: PL3.7.0 → PL3.7i → PL6.4 → PL3.7d → PL3.7e → PL3.7g (the App Store lane) → PL5.2s → PL3.7a → PL5.4 → PL3.7j → PL3.7b1 → PL3.7b2 → PL3.7c → PL3.7f → PL3.7h → W6.

---

### PL3.7.0 · `Platform/Flows/Settings.swift`: the settings protocol (integrator)   size: S
Place in the tree: settings › foundations › the data seam
Repo · branch: NPRdoinglaundry · `int/PL3.7.0-settings-protocol` (integrator)
Needs: contract 06 merged      Unblocks: UI6.0, every PL3.7 part, every settings page

Why: every settings screen can be built and tested on sample data before anything is live, and the live data drops in later without a single view changing.

Inputs: contract 06 §2–§9; ui-engineer.md §4 (how the journal's protocol is shaped); `Platform/Flows/Journal.swift` (the pattern).

Spec (what the views call; the models are plain `Sendable` structs decoded from contract 06 by `Flows.Settings.Wire` types, with `unknown` cases):
```swift
extension Flows {
    @MainActor protocol SettingsData: AnyObject, Observable {
        var settings: Loadable<Settings.Snapshot> { get }          // brief, ambient, straightness, voice, notifications
        var systemNotifications: Settings.SystemNotifications { get }   // .allowed, .denied, .notDetermined (from iOS)
        var learned: Loadable<Settings.Learned> { get }
        var sources: Loadable<[Settings.Source]> { get }
        var account: Loadable<Settings.Account> { get }            // signedInWith, plan (with Apple's localized price), deletion
        var latestExport: Loadable<Settings.Export?> { get }
        var invites: Loadable<[Session.Invite]> { get }
        var unsentCount: Int { get }                               // the outbox, for AC-2
        var isOnline: Bool { get }

        func refresh() async
        func setBrief(enabled: Bool?, time: Settings.LocalTime?, length: Settings.BriefLength?) async -> Settings.WriteOutcome
        func setAmbient(_ on: Bool) async -> Settings.WriteOutcome
        func setStraightness(_ level: Settings.Straightness.Level?) async -> Settings.WriteOutcome   // nil = let it decide
        func setVoice(persona: Settings.Persona?, speed: Settings.Speed?) async -> Settings.WriteOutcome
        func voiceSample(_ persona: Settings.Persona) async -> Result<URL, Backend.Failure>
        func setNotifications(brief: Bool?, episode: Bool?, questions: Bool?, hideWordsOnLockScreen: Bool?) async -> Settings.WriteOutcome
        func openSystemNotificationSettings()

        func sync(_ source: Settings.Source.ID) async -> Settings.WriteOutcome
        func disconnect(_ source: Settings.Source.ID) async -> Settings.DisconnectOutcome
        func deleteData(of source: Settings.Source.ID) async -> Settings.WriteOutcome
        func connect(_ source: Settings.Source.ID) async -> Settings.ConnectOutcome    // .connected, .cancelled, .failed(Backend.Failure)
        func importFile(_ url: URL, into source: Settings.Source.ID) async -> Settings.ImportOutcome

        func requestExport() async -> Settings.WriteOutcome
        func exportFile() async -> Result<URL, Backend.Failure>     // the downloaded zip, for the share sheet

        func manageSubscription() async                             // Apple's sheet, or the fallback link
        func restorePurchases() async -> Billing.RestoreOutcome      // .restored, .nothingToRestore, .failed(…), .offline

        func signOut(force: Bool) async -> Session.SignOutResult    // PL1.5's .hasUnsent(count) when !force
        func sendThenSignOut() async -> Settings.SignOutProgress    // drains the outbox, then signs out
        func deleteMyData() async -> Settings.WriteOutcome
        func deleteAccount() async -> Settings.DeletionOutcome       // .deleted, .cancelledAtApple, .failed(…), .offline
    }
}
```
- `Settings.WriteOutcome`: `.saved`, `.failed(Backend.Failure)` (the view snaps the control back and shows `failure.message` in the subline), `.offline`.
- `Settings.LocalTime`: hour and minute on the quarter hour (an initializer that rounds and is tested), formatted by the view with the person's locale.
- `Settings.Speed`: `.x0_8, .x1, .x1_25, .x1_5` (Q4); `Settings.Persona`: `.warm, .steady, .bright, .unknown` (Q3).

Steps: models + wire types → protocol → fixture decoding tests → ledger section for UI6.0.

Acceptance: every `fixtures/06/*.json` response decodes into these models; an unknown enum value decodes as `.unknown`.

Tests (layer 4): one decoding test per fixture; "unknown status, persona, length and level decode as unknown"; "a LocalTime of 08:10 rounds to 08:15 and 23:55 to 23:45".

Proof in the PR: test output.

Watch out: the protocol is the only thing views see. If a page needs something missing, the engineer stops and asks; it's never added in a view.

---

### PL3.7i · `Platform.LocalReset`: one erase routine                         size: S
Place in the tree: settings › foundations › erase (App Store lane)
Repo · branch: NPRdoinglaundry · `pl/PL3.7i-local-reset`
Needs: PL2.1 (`LocalDatabase.erase()`), PL1.3 (Keychain), PL0.3      Unblocks: PL3.7e, PL3.7f, PL3.7g

Why: when you sign out, start again, or delete your account, nothing of yours is left on the phone, and the next person who signs in sees none of it.

Inputs: app-reference §0.4 (Keychain service `com.retrospect.api`, accounts), §0.8 (`Documents/RetrospectData/`, `Documents/podcasts.json`, `tmp/podcast_<id>.mp3`), §11.3 (the UserDefaults inventory); PL2.1 (erase), PL1.3 (`hasSignedInBefore`), PL1.5 (sign-out steps).

Spec:
- `Platform/Session/LocalReset.swift`: `actor LocalReset` with one entry point `func run(_ depth: Depth) async -> Report`, where `Depth` is:
  - `.signOut`: credentials (keep `hasSignedInBefore`), the store's database erase (PL2.1: the next owner mustn't see it), cached audio (`Caches/Platform/audio`), RevenueCat `logOut()` (PL6.1, when present), push unregister (PL5.1, when present). Old app files stay (the old screens still own them until X06) but the old client is signed out through the PL1.5 bridge.
  - `.dataDeleted`: everything in `.signOut` except credentials and RevenueCat; plus the old app's local entries and podcast files (`Documents/RetrospectData/**`, `Documents/podcasts.json`, `tmp/podcast_*`), old onboarding flags (`OnboardingState.clearPersistedStep()` on the main actor) so onboarding runs again.
  - `.accountDeleted`: everything above, **and** `hasSignedInBefore` (so the next launch shows the splash, not "welcome back"), the pending invite code, every UserDefaults key in the inventory that belongs to the app (a listed allow-list, not `removePersistentDomain`, so system and test keys aren't touched), and the old Keychain service `com.retrospect.api`.
- Each step is independent: a failure is recorded in `Report` (step + `OSStatus`/error kind, no paths with names) and the next step still runs. `run` is idempotent.
- A marker `Session.Store.pendingReset(Depth)` is written before the first step and cleared after the last; launch (PL0.3's `live()`) finishes a pending reset before anything else is shown.

Steps: depth table → steps → marker and resume → tests.

Acceptance: after each depth, a test enumerates the app container and Keychain and finds only what that depth keeps.

Tests (layer 5, a temp container and a fake Keychain): "sign-out keeps hasSignedInBefore and the old files"; "data deleted removes the old journal files and keeps the session"; "account deleted leaves no app file, key or Keychain item but the install sentinel"; "a reset killed halfway finishes on the next launch"; "one failing step doesn't stop the rest"; "the report carries no file names".

Proof in the PR: test output; a simulator run of each depth with the container listing before and after (counts).

Watch out: never `FileManager.removeItem` on `Documents/` itself (the share extension's app group lives elsewhere, but be explicit: remove named children only).

---

### PL6.4 · Manage subscription and restore purchases                         size: M
Place in the tree: settings › account › billing (App Store lane)
Repo · branch: NPRdoinglaundry · `pl/PL6.4-manage-restore`
Needs: PL6.1 (`Billing.Store`), PL6.2 (entitlement), backend BE2.8 (`GET /v2/entitlement`)      Unblocks: PL3.7d, P31

Why: you can see your plan at Apple's price in your currency, manage or cancel it with Apple's own sheet, and get a purchase back on a new phone, as App Review requires (Guidelines 3.1.1, 3.1.2).

Inputs: plumbing/outline.md PL6.1, PL6.2; app-reference §8 (the old `SubscriptionManager`, typed-in prices to remove); contract 06 §6, §7.

Spec:
- `Billing.Store` gains:
  - `func restore() async -> Billing.RestoreOutcome`: RevenueCat `restorePurchases()`; then `GET /v2/entitlement` (refresh) so the server is the gate; `.restored` when the entitlement is active afterwards, `.nothingToRestore` when RevenueCat returns no active entitlement, `.failed(Backend.Failure)` or `.offline`. Single-flight (a second tap awaits the first).
  - `@MainActor func manageSubscriptions(in scene: UIWindowScene?) async`: `AppStore.showManageSubscriptions(in:)`; on a thrown error or a nil scene, open `https://apps.apple.com/account/subscriptions` with `openURL`. Tested through an injected `Billing.SubscriptionManagement` protocol.
  - `func localizedPrice(for productID: String) async -> String?` and `func planName(for productID: String) -> Billing.Period` (monthly, yearly), from the offering (never a literal).
- A SwiftLint rule in `Platform/` and `Features/` refuses a `$` followed by a digit in a string literal (with the message "prices come from StoreKit; see PL6.4"), the strongest layer for D6.

Steps: restore → manage → price lookup → lint rule → tests.

Acceptance: a sandbox restore on a second simulator account restores; "manage subscription" opens Apple's sheet in sandbox; no price literal exists in the new folders.

Tests (layer 5, fake RevenueCat): "restore with an active entitlement returns restored and refreshes the server"; "restore with nothing returns nothingToRestore"; "two restores at once make one request"; "restore offline returns offline"; "manage falls back to the link when the sheet throws"; "the price comes from the offering, in the product's currency"; the lint rule's own test (a fixture file that must fail).

Proof in the PR: test output; a sandbox recording (integrator's phone) of restore and the manage sheet.

Watch out: never decide access on the phone; the server's entitlement is the gate (fail closed). Founder keys (RevenueCat public key, entitlement id, offering id) come from build configuration, never the repo.

---

### PL3.7d · Account and plan on real data                                    size: S
Place in the tree: settings › account › live data (App Store lane)
Repo · branch: NPRdoinglaundry · `pl/PL3.7d-account`
Needs: PL3.7.0, PL6.4, backend BE6.4      Unblocks: P31 live, PL3.7g

Why: ST-9 shows your real plan ("yearly · renews on 20 nov · $199.99"), how you signed in, and the right next step if something's wrong with billing.

Inputs: contract 06 §6; fixtures `account.json`, `account.minimal.json`.

Spec: `LiveSettingsData.account` from `GET /v2/account` (`CachedRead` key `account`, 5 minutes), joined with `Billing.Store.localizedPrice(for:)` for the plan's product. `Settings.Account.Plan` carries `period`, `trial`, `renews`, `renewsOrEndsAt`, `billingIssue`, and `price: String?` (nil until StoreKit answers; the row shows the plan without a price rather than a guess). Refreshed after restore, after a purchase (PL6.2's stream) and on `.active`. `manageSubscription()` and `restorePurchases()` call PL6.4 and then `refresh()` the account.

Acceptance: each fixture maps to the right ST-9 state (member, trial, cancelled, billing issue, not a member).

Tests (layer 4–5): fixtures decode; "a plan without a StoreKit price shows no price"; "restore refreshes the account"; "offline shows the cached plan and isOnline false".

Proof: test output.

Watch out: dates in the plan are shown in the person's locale and calendar by the view; the model keeps `Date`.

---

### PL3.7e · Sign out, with nothing lost                                      size: S
Place in the tree: settings › account › AC-2 › live data (App Store lane)
Repo · branch: NPRdoinglaundry · `pl/PL3.7e-sign-out`
Needs: PL1.5 (`signOut(force:)`), PL2.2 (outbox, `unsentCount()`), PL3.7i      Unblocks: P33 live

Why: signing out never throws away something you wrote: anything waiting is sent first, and you're told if it can't be.

Inputs: contract 06 §9; PL1.5's `SignOutResult`; PL2.2's drainer; Paper AC-2 copy (C48).

Spec:
- `unsentCount` mirrors the outbox (observed).
- `signOut(force:)` passes through to PL1.5 and then runs `LocalReset.run(.signOut)`.
- `sendThenSignOut()` returns an `AsyncStream<Settings.SignOutProgress>`-backed state: `.sending(remaining: Int)` → (outbox empty) → `.signingOut` → `.done`; if the drainer reports offline or a dead letter, `.stuck(remaining:, reason: .offline | .failed)`, and the sheet offers "sign out anyway" (which calls `signOut(force: true)` after the person confirms that those entries will be lost on this phone). Timeout 30 s of no progress → `.stuck(.failed)`.

Acceptance: with two unsent entries online, sign-out sends them, then signs out; offline, it stops and asks.

Tests (layer 5, stub server, in-memory store): "two unsent entries are sent, then the session ends"; "offline stops at stuck with the count"; "sign out anyway after stuck erases and signs out"; "nothing unsent signs out at once"; "the outbox is empty and the database erased after sign-out".

Proof: test output; a recording on staging (integrator) with one queued entry.

Watch out: never call `signOut(force: true)` without the person's explicit tap; the sheet owns that confirmation.

---

### PL3.7g · Delete my account                                               size: M
Place in the tree: settings › account › delete account › live data (App Store lane)
Repo · branch: NPRdoinglaundry · `pl/PL3.7g-delete-account`
Needs: PL3.7i, PL3.7d, PL1.4a (Apple sign-in, for a fresh code), backend BE0.7, BE6.6a, BE6.6b      Unblocks: P31 delete, C50.2 live, T06's deletion test

Why: one deliberate tap deletes your account and everything in it, on the server and on this phone, and it can't end up half-done (Guideline 5.1.1(v)).

Inputs: contract 06 §6, §8; fixtures `account.delete.request.json`, `account.delete.response.json`, `error.apple_confirmation_required.json`; PL1.4a (`AppleSignIn`, nonce).

Spec: `deleteAccount()`:
1. Offline → `.offline` (nothing starts).
2. If `account.deletion.needsAppleConfirmation`, ask Apple for a fresh authorization (`ASAuthorizationAppleIDProvider` request with the stored nonce flow from PL1.4a; scopes none). Cancelled → `.cancelledAtApple` (nothing deleted).
3. Write `LocalReset` marker `.accountDeleted` **and** a `pendingDeletion` flag (Keychain, no content) before sending.
4. `DELETE /v2/account { confirm, appleAuthorizationCode? }`, timeout 30 s, no automatic retry.
   - 202 → step 5.
   - `apple_confirmation_required` (the server knew better) → step 2 once, then send again.
   - `invalid_credentials` (a stale code) → step 2 once more; then `.failed`.
   - `session_revoked` / `unauthenticated` **while `pendingDeletion` is set** → treat as done (the server already locked the account) → step 5.
   - network failure after sending → keep the flag; the next launch calls `GET /v2/access`: 401 → step 5; 200 → clear the flag and the marker and show nothing (the account still exists; the person can try again).
5. `LocalReset.run(.accountDeleted)`, then `Session.Manager` state `.signedOut` → the router shows the splash (P01), never AC-1.
- RevenueCat: `Purchases.logOut()` happens inside the reset; the server deletes the subscriber (BE0.7). The App Store subscription isn't cancelled by deletion: the dialog said so before (C50.1).

Acceptance: deletion against staging leaves no account (a sign-in creates a new, waitlisted user) and an empty app container; killing the app between steps 4 and 5 finishes on relaunch.

Tests (layer 5, stubs): "a stored token deletes without asking Apple"; "no token asks Apple, then deletes"; "cancelling Apple deletes nothing"; "a 409 from the server asks Apple and retries once"; "session_revoked after sending counts as deleted"; "killed after sending, the next launch finishes the erase"; "after deletion the splash shows, not welcome back"; "no log line carries the authorization code".

Proof in the PR: test output; a staging recording (integrator, a disposable sandbox Apple id).

Watch out: Apple's authorization code expires in about five minutes and works once: request it immediately before step 4, never earlier, and never store it.

---

### PL5.2s · Settings deep links                                             size: S
Place in the tree: settings › foundations › routing
Repo · branch: NPRdoinglaundry · `pl/PL5.2s-settings-links`
Needs: PL5.2 (`Routing.Destination`, `Parser`, `Router`)      Unblocks: the export-ready push, the OAuth return, PI3 links

Why: a notification, a link or the return from connecting a source opens exactly the settings page it's about.

Inputs: plumbing PL5.2; contract 06 §4 (OAuth return `retrospect://integration-connected?provider=&status=`), §5 (export push `path`).

Spec: `Routing.Destination.settings(Settings.Route)` with `Settings.Route`: `.root`, `.brief`, `.sources`, `.source(id:)`, `.privacy`, `.straightness`, `.voice`, `.learned`, `.account`, `.invites`. Parser: `retrospect://settings[/<route>[/<id>]]` and the push `path` form `/settings/<route>`; `integration-connected?provider=<id>&status=syncing|error` → `.source(id:)` plus a one-shot `connectResult` the ST-4 page reads (connected, or "that didn't work" for `error`). Unknown routes → `.root`. Provider ids validated against `^[a-z_]{2,40}$`.

Tests (layer 5): one per route; "an unknown settings path opens settings"; "the OAuth return opens that source with its result"; "a provider id with odd characters is refused".

Proof: test output.

Watch out: the existing `.onOpenURL` handler in `RetrospectApp.swift:373-415` routes `integration-connected` for the old screens; the PL5.2 bridge decides by the design switch (F10) which one handles it, never both.

---

### PL3.7a · Settings on real data: reads and writes                         size: M
Place in the tree: settings › foundations › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7a-settings-read-write`
Needs: PL3.7.0, PL2.4 (`CachedRead`, `Loadable`), PL1.5; backend BE6.1e, BE6.1f, BE6.1g, BE6.1h, BE6.2a      Unblocks: P23, P24, P28, P29, P30 live; PL5.4

Why: every setting shows its real value straight away (even offline, from the last time), and every change saves the moment you make it, or tells you it didn't.

Inputs: contract 06 §2, §3; fixtures `settings*.json`, `brief.*`, `ambient.*`, `straightness.*`, `voice.*`, `learned*.json`.

Spec:
- `Platform/Flows/LiveSettingsData.swift`: `@MainActor @Observable final class LiveSettingsData: Flows.SettingsData`, built by `Platform.Environment` from `Repositories.Settings` (an actor).
- Reads: `settings` from `GET /v2/settings` (`CachedRead` key `settings`, shown at once from cache, refreshed on appear and on `.active`); `learned` from `GET /v2/settings/learned` (key `settings.learned`, 1 hour).
- Writes are **optimistic and coalesced**: the snapshot changes at once; a per-setting debouncer (300 ms on the injected clock) sends only the last value; the response replaces the snapshot; a failure restores the previous value and returns `.failed(failure)` (the view's snap-back and subline). Writes aren't queued in the outbox: offline returns `.offline` and changes nothing (settings rows disable offline), **except speed**, which applies to `Playback` at once (local) and is sent on the next `.active` when online (a `pendingSpeed` in the store's `meta`).
- `setVoice(speed:)` also sets `Flows.Playback.rate` for the brief and episode players.
- `voiceSample(_:)` → `GET /v2/settings/voice/samples/:persona` → URL (not cached; it expires in an hour).
- After `setBrief(enabled: true)`, the journal's brief slot (PL3.1b) is invalidated so JR-1 shows "ready by 8:30" (`nextAt`).

Acceptance: every settings fixture reaches its page state through `-Data live -Environment local` (T02a).

Tests (layer 4–5): fixtures decode; "five quick taps send one request with the last value"; "a refused write puts the old value back and reports why"; "offline writes return offline and change nothing"; "speed changes playback at once offline and syncs later"; "turning the brief on refreshes the journal's brief slot"; "no log line carries a setting's value" (enum cases only).

Proof in the PR: test output; a local-staging recording of ST-2 and ST-6 (integrator).

Watch out: the snapshot is one object; a write to one part must never overwrite another part with a stale value (merge by part, a test covers it).

---

### PL5.4 · Asking for notifications when the brief turns on                size: S
Place in the tree: settings › brief › push permission
Repo · branch: NPRdoinglaundry · `pl/PL5.4-brief-permission`
Needs: PL5.1 (`Push.Registrar`), PL3.7a      Unblocks: the brief's notification (written and sent by the outside plan) reaching anyone

Why: you're asked about notifications at the moment it makes sense (you just asked for a daily brief), never at launch.

Inputs: plumbing outline PL5.1 (permission asked when the design asks; token registration); contract 07 (the outside plan writes and sends every notification, each written for the person and the moment: founder, 21 Oct).

Spec: `setBrief(enabled: true)` → if `UNUserNotificationCenter` status is `.notDetermined`, request `[.alert, .sound]` (no badge: the tab bar never badges); on grant, `Push.Registrar.register()`. Denied → the brief still turns on; ST-2's subline reads "you'll find it in your journal" (no nagging). Status `.denied` later shows a quiet "notifications are off for retrospect" row with ↗ to the app's iOS settings (`UIApplication.openSettingsURLString`), only on ST-2.

Tests (layer 5, a fake notification centre): "turning the brief on asks once when undetermined"; "denied still turns the brief on"; "already decided never asks again"; "granted registers the device".

Proof: test output.

Watch out: never ask from a background task or at launch; App Review flags unprompted asks.

---

### PL3.7b1 · Sources on real data: list and actions                         size: M
Place in the tree: settings › sources › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7b1-sources`
Needs: PL3.7a, backend BE6.5b, BE6.5c      Unblocks: P25, P26 live

Why: ST-3 shows every source's real state, and from ST-4 you can read it now, stop it, or remove what it gave Retro, and see each of those finish.

Inputs: contract 06 §4; fixtures `sources*.json`, `source.sync.response.json`, `source.disconnect.response.json`, `source.delete-data.*`.

Spec:
- `sources` from `GET /v2/sources` (`CachedRead` key `sources`, 1 minute); while any source is `syncing` or a deletion is running, refetch every 5 s while a sources page is visible (the view's `.task` drives it), stopping when settled.
- `sync`, `disconnect`, `deleteData` call their doors; optimistic status (`syncing`, `notConnected`, "deleting"), replaced by the response; `.failed` restores and reports.
- On-phone sources: `disconnect` also stops the on-phone collector for that source (the existing HealthKit / Screen Time collectors read a per-source flag; one bridge edit through `Platform.Bridges.sourceDisconnected?(id)`, listed in the PR).
- `Settings.DisconnectOutcome`: `.disconnected(grant: .revoked | .notNeeded | .failed, affected: [ID])`.

Acceptance: through T02a on staging, each status in the fixture appears; a disconnect of calendar turns docs, gmail and youtube to not connected too.

Tests (layer 4–5): fixtures decode; "syncing refetches until connected and then stops"; "disconnect reports every affected source"; "a refused delete restores hasData"; "an on-phone disconnect stops the collector"; "not found removes the row on refresh".

Proof: test output.

Watch out: polling only while visible; a background timer would wake the radio for nothing.

---

### PL3.7b2 · Connecting, reconnecting, importing a file                      size: M
Place in the tree: settings › sources › add a source, reconnect, import › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7b2-connect-import`
Needs: PL3.7b1, PL5.2s, backend BE6.5d      Unblocks: P25a live, P26 reconnect, ON-6 (first run can reuse it)

Why: adding or reconnecting a source takes one tap and Apple's or the provider's own permission screen, and bringing in an export file works even when it's big.

Inputs: contract 06 §4; fixtures `source.connect.*`, `import.*`; app-reference §2.4 (today's connect and import calls, the asset upload pattern).

Spec:
- `connect(_:)`: `POST /v2/sources/:id/connect` → `.browser(url)`: `ASWebAuthenticationSession` with callback scheme `retrospect`, `prefersEphemeralWebBrowserSession = false` (the person's provider login is reused); the session's callback or PL5.2s's `connectResult` completes the call → `.connected` (then refresh sources) / `.cancelled` / `.failed`. `.onPhone`: ask iOS through the existing collector's permission call (HealthKit's `requestAuthorization`, via `Platform.Bridges.requestOnPhonePermission?(id)`), then `POST …/connected`.
- `importFile(_:into:)`: from a `fileImporter` URL (security-scoped), checks size ≤ 1 GB and type locally, computes SHA-256 streaming (never loads the file), `POST /v2/imports` (Idempotency-Key = a UUID stored with the pending import in the store's `meta`), uploads with a background `URLSession` upload task to `uploadUrl`, then `complete`. Interrupted → resumes from the stored key on the next `.active` (re-request a fresh upload URL if expired).

Acceptance: connecting a test Google account on staging returns to ST-4 syncing; a 300 MB import survives backgrounding.

Tests (layer 5): "a browser connect completes from the callback"; "cancelling the browser changes nothing"; "an on-phone connect asks iOS, then the server"; "an import over 1 GB is refused before any request"; "the hash is streamed" (memory bound); "an interrupted upload resumes with the same key"; "the import's file name is never logged".

Proof: test output; a staging recording (integrator).

Watch out: `ASWebAuthenticationSession` needs a presentation anchor from the active scene; tests inject a fake session.

---

### PL3.7c · Download my data                                                 size: S
Place in the tree: settings › privacy › download my data › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7c-export`
Needs: PL3.7a, backend BE6.3c      Unblocks: P27 live, C47 live

Why: you ask once, carry on, and when your data is ready you save it as a file from the app.

Inputs: contract 06 §5; fixtures `export.*`, `error.rate_limited.json`.

Spec: `latestExport` from `GET /v2/account/export/latest` (refetched on appear and on the export push). `requestExport()` → `POST /v2/account/export` with an Idempotency-Key stored until the export leaves `preparing` (so a retry never makes two). `exportFile()` downloads the signed URL into `tmp/` with a background-capable download task, names it `retrospect-data-<yyyy-MM-dd>.zip`, and returns the file URL for the share sheet; the temp file is removed when the share sheet closes. A fresh URL is fetched if the one in hand is older than 23 hours.

Tests (layer 4–5): fixtures decode; "asking twice sends one export"; "rate limited returns the wait"; "the file is named by date and removed after sharing"; "an expired export asks to start again"; "the URL is never logged".

Proof: test output.

Watch out: the zip can be hundreds of MB: never load it into memory; check free disk before downloading (fail with a plain "not enough space on this iPhone").

---

### PL3.7f · Delete my data (keep my account)                                 size: S
Place in the tree: settings › privacy › delete my data › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7f-delete-data`
Needs: PL3.7i, backend BE0.8 (and BE6.6c if Q10 = keep)      Unblocks: P27 delete, T06

Why: you can wipe what Retro knows and start fresh without losing your account or your subscription.

Inputs: contract 06 §8; fixtures `account.delete-data.*`.

Spec: `deleteMyData()`: offline → `.offline`; the outbox is drained first (or the person is told what's still waiting, as AC-2 does, and it's deleted with the rest); `DELETE /v2/account/data { confirm: "delete" }` → on success `LocalReset.run(.dataDeleted)`, `Session.InviteCenter.refreshAccess()` (now `approved`), and the router goes to onboarding (contract 01's first question). Failure → `.failed` and nothing local is touched.

Tests (layer 5): "success erases local data, keeps the session and opens onboarding"; "a failure leaves everything in place"; "unsent entries are sent before deleting, or reported".

Proof: test output; a staging recording (integrator).

Watch out: never run the local erase before the server says yes.

---

### PL3.7h · Your invites on real data                                        size: S
Place in the tree: settings › invites › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7h-invites`
Needs: PL1.7c (`InviteCenter.myInvites()`), PL3.7.0      Unblocks: PI3 live

Why: your three invite links are always one tap from a friend, and you can see which have been used.

Inputs: contract 00 §4 (`GET /v2/invites/mine`), contract 06 §9 (the share line), PL1.7c.

Spec: `invites` from `InviteCenter.myInvites()` (cached under `invites.mine`, refreshed on appear); `Settings.ShareItem` for an unused invite = the link plus the founder's line (one constant in `Features/Settings/InviteCopy.swift`, view-owned copy, lean: "i saved you a place on retrospect. this link works once, so it's just for you."). Sharing works offline from the cached link. "2 left" for ST-1's row = the count of `unused`.

Tests (layer 4–5): "invites decode from contract 00's fixture"; "the count of unused feeds ST-1"; "an unused invite shares its link and the line"; "a used invite has nothing to share"; "no log carries a link".

Proof: test output.

Watch out: the link is a secret that works once; it's never in analytics, never in a log, and never prefilled anywhere but the share sheet the person opens.

---

### W6 · Settings wiring (integrator)                                         size: S
Place in the tree: settings › foundations › wiring
Repo · branch: NPRdoinglaundry · `int/W6-settings-wiring`
Needs: every P2x/P3x page, PI3, every PL3.7 part      Unblocks: T06 on live data, ship gate G6

Why: the new settings run on real data, and the old settings screen stops being reachable.

Spec: swap `SampleSettingsData` for `LiveSettingsData` in `Platform.Environment.live()` (one line); route the You tab's picture and the drawer foot to ST-1 behind the design switch `design.v2.settings` (F10); delete the settings rows from the sample-data ledger; the old `DarkSettingsView` stays reachable only with the switch off until the ship gate, then X-bytes delete it.

Acceptance: every T02 state on the settings list renders on `-Data live -Environment local` with the same look as on sample; the ledger has no settings rows.

Tests: T06 on local staging (layer 9).

Proof: the end-to-end recording for the founder's sign-off.

Watch out: any difference on screen between sample and live is a seam bug: findings log, not a quick fix in a view.

---

### PL3.7j · Notification settings on real data                             size: S
Place in the tree: settings › notifications › live data
Repo · branch: NPRdoinglaundry · `pl/PL3.7j-notification-settings`
Needs: PL3.7a, PL5.1, backend BE6.7      Unblocks: P23a live

Why: you choose which kinds of notification Retro sends, and whether their words show on your lock screen, and the page tells you plainly if iOS has notifications turned off for Retrospect.

Inputs: contract 06 §2 (`NotificationSettings`, `PATCH /v2/settings/notifications`); fixtures `notifications.*`, `settings*.json`; contract 07 (the outside plan's writer and sender honour these).

Spec:
- `settings.notifications` arrives with `GET /v2/settings`; `setNotifications(…)` writes optimistically and coalesced, as PL3.7a's other writes (one request with the latest values; snap-back on failure).
- `systemNotifications` from `UNUserNotificationCenter.notificationSettings()` (read on appear and on `.active`, since the person may change it in iOS): `.allowed`, `.denied`, `.notDetermined`. `.denied` → the page shows the iOS row; `openSystemNotificationSettings()` opens `UIApplication.openNotificationSettingsURLString` (iOS 16+; falls back to `openSettingsURLString`). `.notDetermined` → turning any kind on asks iOS first (the PL5.4 path), never at launch.
- `hideWordsOnLockScreen` is a server choice the sender honours (the words never leave our server in that case); the app also registers its notification categories with `.hiddenPreviewsShowTitle` and a neutral `hiddenPreviewsBodyPlaceholder`, so a person whose iOS "show previews" is "when unlocked" gets the same behaviour from iOS too.

Tests (layer 4–5): fixtures decode; "a refused write puts the switch back"; "denied in iOS shows the iOS row and the switches stay as chosen"; "turning a kind on when undetermined asks iOS once"; "the categories hide previews with a neutral placeholder".

Proof: test output.

Watch out: never decide what a notification says on the phone; the writer is the outside plan's.
