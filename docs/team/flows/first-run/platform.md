# First run · Platform cards

The app engineer's Platform cards for first run, plus the integrator's shared-file bytes (FR0.x) that the views and Platform cards need. Full [byte cards](../../byte-card.md). Read [README.md](./README.md) and [contract 01](../../contracts/01-first-run.md) first.

**Existing cards this area builds on (not rewritten here):** PL1.3 (`Session.Store`, `pendingInviteCode`, `hasSignedInBefore`), PL1.4 (Apple and Google sign-in), PL1.5 (refresh, sign-out), PL1.6 (version floor), PL1.7 (`Session.InviteCenter`; **PL1.7d below amends it**), PL2.2 (the outbox), PL2.4 (`CachedRead`, `Loadable`), PL5.2 (the router), T02a (launch options).

**Order.** Beta 1: FR0.1 → FR0.2 → PL1.7d → PL1.8. Phase 2: FR0.3 → PL1.9 → PL3.3a → PL3.3b → PL3.3c → PL3.3d → PL5.1 → PL5.3 → PL6.1 → PL6.2 → PL6.3 → FR0.4.

---

## Shared-file bytes (the integrator's)

### FR0.1 · Ticket and first-run foundations: tokens, haptics, shaped depth, mesh recipes    size: M
Place in the tree: first run › foundations › tokens and haptics (shared files)
Repo · branch: NPRdoinglaundry · `int/FR0.1-first-run-foundations` (the integrator; `design-system/tokens/tokens.json`, `Generated/Tokens.swift`, `RDepth.swift`, `RMotionExtras.swift`, `design-system/hifi/mesh.py`, `DesignV2Switches.swift`)
Needs: #42 (`RArtwork`), #55 (`RShape`)        Unblocks: C41.x, C42, PI2.x, C34.1, C22-p, PI1, PX

Why: the ticket's rumble, tear and rip, its cut-following shadow and its gift colours are part of the design system, so every screen that needs them gets the same ones, and nothing in a view writes a raw number.

Inputs: round 2 board `2HXA-0` ("haptic map" `2IUX-0`: printing rumble intensity ~0.25, sharpness ~0.1 with grain; light tick per hole throttled to one per 40ms; separation a rigid impact ~0.8; "you're in" `haptic.reveal`; "a continuous 'print rumble' haptic pattern for the haptics facade" `2IUZ-0`); ticket `2HXP-0` (gift mesh, drop-shadow stack); T1 `2I01-0` (the invite wallpaper); motion-system §2, §3, §5, §10; design-reference §F 11 (`size.miniPlayer`); app-reference §16 (`DesignV2Screen` has no invite or force-update case).

Spec:
- **tokens.json** (then `to-swift.mjs` regenerates `Tokens.swift`):
  - `haptic.printRumble` `{ kind: continuous, intensity: 0.25, sharpness: 0.1, grain: 0.04, decay: 0.15 }`; `haptic.tearTick` = selection with `minInterval: 40ms`; `haptic.rip` `{ impact: rigid, intensity: 0.8 }`.
  - `motion.curve.print` (0.3, 0.1, 0.25, 1: steady, then a soft ease at the end; "linear-ish" per the board, never linear) and `motion.duration.print` 1800.
  - `motion.tear.threshold` 0.62, `motion.tear.flickVelocity` 800, `motion.tear.droop` 11 (degrees), `motion.tear.holdDuration` 600 (Reduce Motion's press-and-hold), `motion.tear.sealTimeout` 8000.
  - `size.ticket.notch` 10, `size.ticket.mesh` 132 (`104` compact), `size.printerSlot` 8, `size.printerMouth` 24, `size.printerBend` 56.
  - `depth.stack.ticket` (outer stroke 0.5, contact `0 1 1`, cast `0 10 14`), `depth.stack.handle` (inner top, outer 0.5, contact `0 1 1.5`, cast `0 4 10 −4`), `depth.stack.handleHeld` (contact `0 1 2`, cast `0 8 18 −8`).
  - `size.miniPlayer` 42 → 64 (§F 11; check no merged view uses 42).
- **`RHaptic` additions** (`RMotionExtras.swift`, the hand-written half): `RHaptic.Rumble` (`@MainActor final class`, one `CHHapticEngine`, `start()` plays a `CHHapticEvent(eventType: .hapticContinuous)` at the token's intensity and sharpness with a `CHHapticParameterCurve` adding ±grain at 30Hz, `stop()` ramps down over `decay`; checks `CHHapticEngine.capabilitiesForHardware().supportsHaptics` and does nothing otherwise; restarts the engine after `stoppedHandler`/`resetHandler`); `RHaptic.tick(_ clock:)` (a selection generator gated to `minInterval`); `RHaptic.rip` (`.impact(flexibility: .rigid, intensity: 0.8)` as `SensoryFeedback`); `RHaptic.TypeOn` (the prepared soft generator at 0.35, max 10/s, for C34.1). A DEBUG haptic recorder (`RHaptic.Recorder`) that tests read.
- **`RDepth`:** `rRaised(in shape: some Shape, stack: RDepth.Stack = .card)`, so a shadow follows any shape (the ticket's cut); stacks `.card`, `.ticket`, `.handle`, `.handleHeld`.
- **`RArtwork` recipes:** `gift` (Paper `2HXR-0`'s three blobs as a 3 × 3 `MeshGradient`, dark twins) and the `invite` wallpaper (`2I01-0`'s three washes), both in `mesh.py` and Swift.
- **`DesignV2Screen`:** add `invite = "PI1"`, `youreIn = "PI2"`, `forceUpdate = "PX"`.

Steps: tokens → generate → `RHaptic` player and recorder → `RDepth` shape stacks → recipes → switches → lab page `ticket` showing every new token.

Acceptance: `token-check.mjs` passes; the lab plays the rumble, tick and rip on a device; the ticket shape's shadow follows the cut in the lab.

Tests: (unit) the tick gate allows one tick per 40ms (injected clock) · (unit) `Rumble.start` without haptic hardware does nothing and throws nothing · (unit) the recorder logs every haptic in order · (snapshot) `rRaised(in:)` on a cut shape in light and dark

Proof in the PR: the lab recording on the integrator's phone; token diff.

Watch out: continuous haptics stop when the app backgrounds: `Rumble` must handle `stoppedHandler` without crashing and without restarting a rumble the view already stopped.

---

### FR0.2 · The invite flow protocol                                                    size: S
Place in the tree: first run › the invite › data seam › protocol
Repo · branch: NPRdoinglaundry · `int/FR0.2-invite-protocol` (`Platform/Flows/Invite.swift`)
Needs: contract 01 §2, contract 00 §3–§4, PL1.7        Unblocks: UI4.0, PI1, PI2, PL1.7d, PL1.8

Why: the invite screens and the live invite data agree on one shape, so the views can be built on sample data and swapped to live data in one line.

Inputs: contract 01 §2–§3; PI1 and PI2 state lists (views.md); ui-engineer.md §4 (the seam rules).

Spec:
```swift
enum InviteStage: Sendable, Equatable {
    case promise(face: TicketFace?)                 // signed out, a code waiting (T1)
    case typed(face: TicketFace?, filled: Int)      // signed in, waitlisted, no code (T-alt)
    case printing(face: TicketFace)                 // signed in, check usable (T2a)
    case ready(face: TicketFace)                    // the tear is available (T2)
    case refused(face: TicketFace?, reason: Refusal) // used | expired | invalid
    case sealing                                    // redeem in flight
    case youreIn(invitedBy: String?, firstName: String?, serial: Int, redeemedOn: String, animate: Bool)
    case waitlisted
    case suspended
    enum Refusal: Sendable, Equatable { case used, expired, invalid }
}
struct TicketFace: Sendable, Equatable { let from: String?; let kind: InviteKind; let serial: Int; let issuedOn: String }
enum InviteKind: String, Sendable, Codable { case member, founder, review, unknown }
enum TearOutcome: Sendable, Equatable { case yours, offline, used, failed, rateLimited(retryAfter: Duration?) }
enum TypedOutcome: Sendable, Equatable { case usable(TicketFace), invalid, used, expired, rateLimited(retryAfter: Duration?), offline }

@MainActor protocol InviteData: AnyObject, Observable {
    var stage: InviteStage { get }
    var isOnline: Bool { get }
    var signInState: SignInState { get }            // .idle, .pending(Provider), .failed
    func prepareApple(_ request: ASAuthorizationAppleIDRequest)
    func completeApple(_ result: Result<ASAuthorization, Error>) async
    func signInWithGoogle() async
    func type(code: String) async -> TypedOutcome
    func beginTear()                                // makes the idempotency key on touch-down
    func tear() async -> TearOutcome                // redeem; called once at the threshold
    func joinWaitlist(reason: String?) async -> Bool
    func begin()                                    // records "you're in" seen; the root moves on
}
```

Steps: types → protocol → doc comments naming the contract section per member.

Acceptance: compiles with no implementation; reviewed against PI1/PI2's state lists (every page state reachable from a stage).

Tests: (unit) every fixture in `fixtures/01/invite.*.json` maps to a stage through the mapping functions PL1.7d will use (the mapping is a pure function in this file).

Proof in the PR: the protocol diff.

Watch out: the views never see the code itself (only `filled` counts and the face); the code stays in `Session`.

---

### FR0.3 · The first-run flow protocol                                                 size: S
Place in the tree: first run › data seam › protocol (phase 2)
Repo · branch: NPRdoinglaundry · `int/FR0.3-first-run-protocol` (`Platform/Flows/FirstRun.swift`)
Needs: contract 01 §3–§8, PL2.4 (`Loadable`)        Unblocks: UI4.8, PL3.3a–d, PL1.9

Why: every phase 2 first-run screen reads one shape, built on sample data first and live data later with nothing changing on screen.

Spec:
```swift
enum FirstRunStage: Sendable, Equatable { case splash, welcomeBack, invite, questions(QuestionKey), privacy, connect, fallbacks, briefTime, howStraight, gettingReady, tease, paywall, home, paused, updateRequired }
struct Question: Sendable, Identifiable { let key: QuestionKey; let quickAnswers: [String] }   // copy is the app's, by key
@MainActor protocol FirstRunData: AnyObject, Observable {
    var stage: FirstRunStage { get }
    var questions: [Question] { get }               // in order, fallbacks included only when needed
    var answers: [QuestionKey: AnswerState] { get } // .waiting, .sending, .sent, .failed (outbox)
    func answer(_ key: QuestionKey, text: String, given: Given) async
    var sources: Loadable<[Source]> { get }
    var knowsYou: Loadable<KnowsYou> { get }        // level, connectedSources, answers
    func connect(_ source: Source) async -> ConnectOutcome   // .connected, .denied, .failed, .cancelled, .offline
    var job: Loadable<FirstEpisodeJob> { get }
    var episode: Loadable<FirstEpisode> { get }
    var pushAsked: Bool { get }
    func askForPush() async -> Bool
    var offering: Loadable<Offering> { get }        // localized prices from the store
    var entitlement: Entitlement { get }
    func purchase(_ plan: Plan) async -> PurchaseOutcome   // .subscribed, .pending, .cancelled, .failed, .offline
    func restore() async -> RestoreOutcome
    func notNow()
    var recap: Loadable<[Answer]> { get }
    func complete() async                            // approved → member, once
    var isOnline: Bool { get }
}
```

Steps: types → protocol → mapping helpers from contract types.

Acceptance: compiles; every page state in views.md §B–§F is reachable from these values.

Tests: (unit) fixture-to-model mapping for answers, sources, knows-you, jobs, entitlement.

Proof in the PR: the protocol diff.

Watch out: prices only ever arrive in `Offering`; no `Decimal` price is constructed in app code.

---

### FR0.4 · First-run wiring: sample → live                                         size: S
Place in the tree: first run › wiring (phase 2)
Repo · branch: NPRdoinglaundry · `int/FR0.4-first-run-wiring`
Needs: every §B–§F view card, PL1.9, PL3.3a–d, PL5.1, PL6.1, PL6.2; backend BE2.1–BE2.10 on local staging        Unblocks: T03b's staging half, G1

Why: the new first run runs on the real backend, and the old onboarding stops being the way in.

Spec: `Platform.Environment.live` builds `LiveFirstRunData` for `.live`; the root (`RetrospectApp.swift`) routes through PL1.9's resolver when `DesignV2.isOn(.splashSignIn)`; the old `DarkOnboardingFlow` stays reachable only when the switch is off; the sample-data ledger rows for first run are deleted.

Acceptance: with the switch on, a fresh staging account goes from link to ON-13 on live data; with it off, the old onboarding still works.

Tests: T03b's staging run; (unit) the switch selects the right root.

Proof in the PR: the staging recording; the ledger diff.

Watch out: never remove the old onboarding in this PR (X bytes retire it after G1).

---

## Beta 1 · the invite

### PL1.7d · The ticket: preview, check, and redeem at the tear                      size: M
Place in the tree: product › first run › the invite › Session.InviteCenter (amends PL1.7)
Repo · branch: NPRdoinglaundry · `pl/PL1.7d-ticket-check`
Needs: PL1.7a, PL1.7b, FR0.2, contract 01 §2; backend BE2.0a, BE2.0b        Unblocks: PL1.8, PI1/PI2 live, T03a's staging half

Why: the ticket prints only what's true (who it's from, whether it can be used), and the code is spent at the tear, not the moment you sign in: "nothing is spent until separation" (the founder's board).

Inputs: contract 01 §2.1–§2.3 and `fixtures/01/invite.*.json`; PL1.7 (`InviteCenter`); round 2 board edge cases (`2IUX-0`).

Spec:
- **This changes PL1.7b.** PL1.7b's "after sign-in, redeem the pending code automatically" becomes "after sign-in, **check** the pending code" (`POST /v2/invites/check`), and redeem moves to `tear()`. If PL1.7b has already merged, this PR edits it; if not, PL1.7b is built to this card (the integrator updates PL1.7's card; README "shared changes").
- `Session.InviteCenter` gains:
  - `preview(code:) async -> TicketFace?` → `GET /public/invites/:code` (no token; the client's public request path), called when a code arrives while signed out; `nil` on `live: false`, errors or offline.
  - `afterSignIn()` → if `access == .waitlisted` and a pending code exists: `check` → `.printing(face)` (usable), `.refused(face, .used/.expired/.invalid)` (clears the pending code), `.youreIn(…, animate: false)` on `reason: yours` (a relaunch after the tear), nothing on `alreadyIn`; offline/rate limited keep the code and retry on `.active` and on reachability.
  - `type(code:)` → normalise (PL1.7's normaliser) → `check`; usable stores it as the pending code.
  - `beginTear()` → makes and keeps one `Idempotency-Key` (UUID) for this tear.
  - `tear()` → `POST /v2/invites/redeem { code }` with that key; success → clear the pending code, `access = .approved`, publish `.youreIn(invitedBy:, firstName:, serial:, redeemedOn:, animate: true)`; `offline` → `.offline` (nothing changes); `invite_used` → `.used` and clear; others → `.failed` (code kept); a second call while one is in flight returns the first call's result (single flight).
- `LiveInviteData` (`Platform/Flows/LiveInviteData.swift`, `@MainActor @Observable`, implements `InviteData`) composes `InviteCenter`, `Session.AppleSignIn`, `Session.GoogleSignIn` (Beta 1: Apple only), and `Backend.Reachability`. "You're in seen" is a `UserDefaults` flag per user id (`invite.welcomed.<userId>`, no personal data); `begin()` sets it.
- Never log the code, the face's name or the link; counts only (`invite.check.<outcome>`, `invite.tear.<outcome>`).

Steps: preview → check after sign-in → typed check → tear with single flight → `LiveInviteData` → tests.

Acceptance: on local staging, a fresh account opening a founder link sees the inviter's name before sign-in, the ticket prints after sign-in, and the invite is unused until the tear; a second account with the same link sees "already used".

Tests (layer 5; fixtures decode, layer 4):
- "a live preview shows the inviter; a dead one shows nothing" (both fixtures)
- "signing in checks the pending code and never redeems it"
- "a used code clears the pending code and refuses"
- "a relaunch after the tear shows you're in without animating" (`invite.check.yours.json`)
- "tearing redeems once with the key made at touch-down, even when called twice"
- "an offline tear changes nothing and keeps the code"
- "a lost redeem response retried with the same key returns success"
- "no log line or analytics event contains the code or the inviter's name" (sink scan)
- "typing a code checks it and stores it only when usable"

Proof in the PR: test output; the staging run log (counts only).

Watch out: the public preview must go out without the `Authorization` header (the client's public path); never put the code in a URL the app builds other than this path segment, and never log that URL.

---

### PL1.8 · The invite gate in the app root (Beta 1)                                 size: M
Place in the tree: product › first run › the invite › root routing (Beta 1 bridge)
Repo · branch: NPRdoinglaundry · `pl/PL1.8-invite-gate-root` (the `RetrospectApp.swift` hunk is reviewed by the integrator, who owns the file)
Needs: PL1.7d, PL1.4a, PL1.4c, PL5.2, PI1, PI2.1–PI2.4        Unblocks: T03a, Beta 1

Why: in Beta 1, anyone who signs in without an invite meets the gate instead of the app, and an invite link turns into the ticket, while existing members never see any of it.

Inputs: app-reference §1.4 (the root ladder, `RetrospectApp.swift:145-235`), §4 (`OnboardingState`, `onboardingSignedIn`), contract 01 §3 (the launch table); first-ship.md (Beta 1: the current onboarding after "begin").

Spec:
- `Platform/Routing/AccessGate.swift`: a pure function `AccessGate.screen(session:access:pendingCode:welcomed:) -> GateScreen?` (`.promise`, `.typed`, `.ticket`, `.youreIn`, `.waitlisted`, `.suspended`, or `nil` = carry on to the app), from contract 01 §3's table (Beta 1 rows only: no splash, no AC-1).
- Root bridge (one inserted branch, above `!hasCompletedOnboarding` at `RetrospectApp.swift:198`): `if let gate = platform.accessGate { InviteScreens(gate) }`. Everything below it is unchanged.
- **After "begin" in Beta 1:** the current onboarding continues, but its own sign-in step must not ask again: the bridge sets `OnboardingState`'s `onboardingSignedIn` and its step to the first step after sign-in (through `OnboardingState.markSignedIn()`, which is the old code's own writer; called on the main actor), so the old flow resumes after sign-in.
- **Members and grandfathered users:** `access` `member`/`staff` → `nil`, always; a pending code is dropped with the "you're already in." toast (PI1).
- **Sign-out** (PL1.5): the gate returns `nil` until the next sign-in; `invite.welcomed.<userId>` is kept.
- Unknown `access` (`unknown`) → treated as `waitlisted` for the gate (fail closed) and logged once.

Steps: the pure resolver with a table test → the root branch → the old-onboarding bridge → staging run.

Acceptance: a new tester without a link sees T-alt after signing in; with a link, T1 then the ticket; an existing member updating the app sees nothing new; after "begin" the current onboarding continues without a second sign-in.

Tests (layer 5): a table test over every row of contract 01 §3's Beta 1 rows; "a member with a pending code gets no gate and the code is dropped"; "unknown access fails closed"; "begin marks the old onboarding signed in"; (UI, sample) "the gate sits above the old onboarding".

Proof in the PR: test output; the root diff (for the integrator); a staging recording of both paths.

Watch out: the old onboarding's sign-in page still exists behind the gate for people signing in without a link in Beta 1; it now uses v2 sign-in (PL1.4c) and the gate appears right after it.

---

## Phase 2

### PL1.9 · The launch resolver: which first-run screen                             size: M
Place in the tree: product › first run › launch › FirstRun.Resolver
Repo · branch: NPRdoinglaundry · `pl/PL1.9-first-run-resolver`
Needs: PL1.8, PL1.6, FR0.3, contract 01 §3, backend BE2.2b (`onboarding/complete`, answers list), BE2.5b (`jobs/first`)        Unblocks: P01, P32, PX, FR0.4

Why: whatever state you left in (a link, a sign-out, half the questions answered, an episode being made), the app opens exactly where you should be.

Spec:
- `Platform/FirstRun/Resolver.swift`: `FirstRun.Resolver.stage(...) -> FirstRunStage`, pure, from: session, `hasSignedInBefore`, pending code, `access`, "you're in" seen, the answers list (first unanswered key), connected sources (for fallbacks), the first job (`GET /v2/episodes/jobs/first`), entitlement, a paywall decision flag (`firstRun.paywallSeen.<userId>`), `updateRequired`. Rows: contract 01 §3 plus the phase 2 order (questions → privacy → connect → fallbacks → brief time → how straight → getting ready → tease → paywall → home).
- `updateRequired` wins over everything (PX).
- Restoring (AC-1): after sign-in, reads `access`, answers and the job once (`CachedRead`), then resolves; failures → `restoreFailed`.
- `complete()` is called by ON-13 once (`POST /v2/onboarding/complete`), and `access == member` sends future launches home.

Steps: inputs struct → table of rows → restore → tests.

Acceptance: every row in a table test; a relaunch at each stage resumes there (sample and staging).

Tests (layer 5): a table test of every row; "update required wins"; "a member always goes home"; "answers resume at the first unanswered key"; "fallbacks are skipped when their source is connected"; "a ready first job with no paywall decision goes to the tease"; "restore failure shows the retry state".

Proof in the PR: test output.

Watch out: never call the network from the resolver; it reads what PL3.3 has cached and loaded.

---

### PL3.3 · LiveFirstRunData                              4 bytes: PL3.3a M, PL3.3b M, PL3.3c M, PL3.3d S
Place in the tree: product › first run › live data › LiveFirstRunData
Repo · branches: NPRdoinglaundry · `pl/PL3.3a-first-run-answers`, `pl/PL3.3b-first-run-connect`, `pl/PL3.3c-first-episode-job`, `pl/PL3.3d-first-run-recap`
Needs: FR0.3, PL2.2, PL2.4, PL1.5; backend BE2.2b (a, d), BE2.3b + BE2.10 (b), BE2.5b (c)        Unblocks: FR0.4, T03b

Why: your answers are saved exactly once, connecting a source really connects it, your first episode is followed until it's ready, and the recap shows what you said.

Inputs: contract 01 §4–§6 and fixtures; PL2.2 (outbox), PL2.4 (`CachedRead`); app-reference §1.8 (`integration-connected` callback), PL5.2 (its parsed destination).

Spec:
- **(a) Answers through the outbox:** a new outbox operation `onboarding.answer` (PL2.2's operation table gains it: the body is contract 01 §4's, the key is `clientEntryId`); `answer(_:text:given:)` enqueues and sets `answers[key] = .waiting`, updated from the outbox's states; the next question never waits for the network. `GET /v2/onboarding/answers` (`CachedRead` `onboarding.answers`) on launch for resume. `brief.time` (ON-8) is queued as an outbox operation too, held (`blockedUntil: .contract06`) until contract 06's door exists; the switch itself uses contract 02's `PUT /v2/briefs/enabled`.
- **(b) Connect and knows-you:** `sources` from `GET /v2/sources?for=onboarding` (`CachedRead`, 1 minute); `connect(_:)`:
  - `onDevice`: request the iOS permission through the existing services (`EKEventStore.requestFullAccessToEvents`, `HKHealthStore.requestAuthorization` with the current app's read types; bridges to `IntegrationsSyncService` so the device-batch upload keeps working), then `POST /v2/sources/:id/connect { granted: true }`; denied → `.denied`.
  - `account`: `POST /v2/sources/:id/connect` → `authUrl` → `ASWebAuthenticationSession` (callback scheme `retrospect`, `prefersEphemeralWebBrowserSession = true`); the callback (`retrospect://integration-connected?provider=…&status=…`, parsed by PL5.2) resolves the pending connect; cancel → `.cancelled`.
  - After each connect and each sent answer: refetch `GET /v2/knows-you`.
- **(c) The first episode:** on entering ON-10: `POST /v2/episodes/jobs { kind: "first" }` (idempotent key stored per user, so re-entering reuses it); poll `GET /v2/episodes/jobs/:id` every 3 s while the screen is visible (10 s after a minute; stop on `ready`, `quiet`, `failed`, or leaving; resume on return); `ready` → `GET /v2/episodes/:id` and hand the audio to `Media.Source` (PL3.1b) with the signed URL refreshed before expiry; `failed.retryable` → `retry()` re-posts with a new key.
- **(d) Recap and completion:** `recap` from the answers list; `complete()` → `POST /v2/onboarding/complete` once (a flag per user); `LiveFirstRunData` assembled from (a)–(c) and PL6.x's `offering`, `entitlement`, `purchase`, `restore`.

Steps: per byte: endpoints → repository → live object → fixture tests → behaviour tests.

Acceptance: with `-Data live -Environment local`, every first-run page state that live data can produce is reachable; answers sent offline arrive once.

Tests (layer 5):
- (a) "an answer is saved once even when sent offline and retried"; "the next question never waits for the network"; "resume starts at the first unanswered key"; "brief time waits in the outbox until its door exists"
- (b) "connecting calendar asks iOS once and then tells the server"; "a denied permission reports denied and sends nothing"; "an account connect completes from the callback"; "a cancelled web sheet reports cancelled"; "knows-you is refetched after a connect"
- (c) "the first job is created once even when ON-10 is entered twice"; "polling stops at ready and when the screen leaves"; "quiet and failed map from their fixtures"; "an expiring audio link is refreshed before playing"
- (d) "complete is sent once"; "recap shows the latest answer per key"
- "no log line contains an answer's text" (sink scan)

Proof in the PR: test output; a staging recording per byte.

Watch out: the job polling must stop when the app backgrounds (push covers it: PL5.1); `ASWebAuthenticationSession` needs a presentation anchor from the view: take it through the protocol's `connect`, never by reaching into UIKit from Platform.

---

### PL5.1 · Push registration                                                         size: M
Place in the tree: product › platform › push › Push.Registrar
Repo · branch: NPRdoinglaundry · `pl/PL5.1-push-registration`
Needs: PL1.5; backend BE2.6; founder: the APNs key and the Push Notifications capability        Unblocks: P05's push ask, PL5.3, BE2.7b's end-to-end check

Why: Retro can tell you when your first episode (and later your brief) is ready, on the phone you're using, and only after you said yes.

Inputs: contract 01 §7; app-reference §1.1 (`AppDelegate` has no `didRegisterForRemoteNotificationsWithDeviceToken`), §9 (`PodcastNotificationService.requestAuthorization`), §12.2 (entitlements).

Spec:
- `Platform/Push/Registrar.swift` (`@MainActor final class Push.Registrar`): `status` (`.notDetermined`, `.denied`, `.authorized`, `.provisional`); `ask() async -> Bool` (`UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])`, only from a person's tap); `registerIfAllowed()` on launch (`registerForRemoteNotifications()` when authorized); `didRegister(token: Data)` (hex) → `POST /v2/devices { token, environment, appVersion }` (environment from the `aps-environment` entitlement compiled per configuration); token changes re-post; `unregister()` on sign-out (`DELETE /v2/devices/:token`, best effort; PL1.5 calls it).
- Bridges: `AppDelegate` gains `didRegisterForRemoteNotificationsWithDeviceToken` / `didFailToRegister…` forwarding to the registrar (two one-line methods; the integrator reviews); `aps-environment` entitlement and the `remote-notification` background mode added (listed in the PR).
- `PodcastNotificationService.requestAuthorization` callers stay (old screens); its authorization and ours are the same system state.

Steps: registrar → bridges → entitlement → tests.

Acceptance: on a device (TestFlight), granting on ON-10 registers a token on staging (counts only); denying never asks again.

Tests (layer 5): "the token is sent as hex with its environment"; "a changed token is re-sent"; "denied never re-asks"; "sign-out unregisters"; "no request is made before a tap"

Proof in the PR: test output; the device run log.

Watch out: simulators don't get real APNs tokens: test the network half with a stubbed token, the real half on the founder's phone.

---

### PL5.3 · Notification taps                                                         size: M
Place in the tree: product › platform › push › taps → routing
Repo · branch: NPRdoinglaundry · `pl/PL5.3-notification-taps`
Needs: PL5.1, PL5.2, contract 01 §7 (contract 07 extends it)        Unblocks: "your first episode is ready" opening the right place

Why: tapping the note about your first episode (written for you by the outside plan's writer) opens that episode, wherever you were.

Spec (the extension that writes each notification's words is the outside plan's, contract 07; this card only routes taps): `AppDelegate`'s `didReceive response` (`RetrospectApp.swift:32-47`) passes `userInfo["path"]` to PL5.2's parser (never trusting `kind` alone); `episode_ready` → `.episode(id:)`; when first run isn't finished, the router keeps it pending until ON-10/ON-13 can take it (if the person is on ON-10, the job poll sees `ready` first anyway); the old `ShowPodcastFromNotification` path stays for old payloads; categories registered: `episode_ready`, `brief_ready`.

Tests (layer 5): "an episode-ready tap routes to that episode"; "a tap before onboarding finishes waits in pending"; "an unknown kind does nothing"; "old payloads still post the old notification".

Proof in the PR: test output; a device run tapping a staging push.

Watch out: payloads carry no content; never display anything from them in the app, and never add a fixed notification string here (founder, 21 Oct: every note is written for the person).

---

### PL6.1 · RevenueCat in the app                                                     size: M
Place in the tree: product › platform › billing › Billing.Store
Repo · branch: NPRdoinglaundry · `pl/PL6.1-revenuecat`
Needs: PL1.5, PL0.4; founder: RevenueCat public iOS key, entitlement id, offering id, the two products        Unblocks: PL6.2, P07 live, FR0.4

Why: you can subscribe and see the real price in your currency, with the first month free on the yearly plan (D6).

Inputs: contract 01 §8; app-reference §8 (the old stubs and their typed-in prices); the ios-monetization-paywall skill (StoreKit 2, `appAccountToken`).

Spec:
- Add `RevenueCat` (`purchases-ios`) pinned to an exact version (PL0.4's rule); key from build configuration (`REVENUECAT_PUBLIC_KEY` in the xcconfig, never committed in plain text beyond the public key).
- `Platform/Billing/Store.swift` (`actor Billing.Store`): `configure(userID:)` → `Purchases.configure(withAPIKey:appUserID:)` with **our user id** (so the webhook's `app_user_id` is ours, BE2.8a); `logIn`/`logOut` on sign-in/out; `offering() async -> Offering` (`monthly`, `yearly` with `displayPrice`, `period`, `introductoryOffer` free month); `purchase(_:)` → `.subscribed` / `.pending` (Ask to Buy) / `.cancelled` / `.failed`; `restore()`; `customerInfo` as an `AsyncStream`; a protocol (`Billing.Purchasing`) with a fake for every state.
- After a purchase or restore: `GET /v2/entitlement?refresh=true` (PL6.2).
- StoreKit configuration file (`Retrospect.storekit`) for tests and simulator runs, with the two products at the D6 prices and the yearly intro offer.

Tests (layer 5): "the offering maps localized prices and the free month"; each purchase outcome from the fake; "restore with nothing reports nothing"; "sign-out logs out of RevenueCat"; "no price literal exists in Platform" (source scan, outside the `.storekit` file).

Proof in the PR: test output; a simulator purchase with the StoreKit file.

Watch out: never grant anything from `CustomerInfo` for server work: the server is the gate (PL6.2).

---

### PL6.2 · One source of entitlement                                                 size: S
Place in the tree: product › platform › billing › entitlement
Repo · branch: NPRdoinglaundry · `pl/PL6.2-entitlement`
Needs: PL6.1, backend BE2.8b        Unblocks: PL6.3, P07 subscribed state, settings ST-9

Why: you get what you paid for on every screen, and never anything you didn't.

Spec: `Billing.Entitlement` (a value: `active`, `productId`, `inTrial`, `expiresAt`, `willRenew`) from `GET /v2/entitlement` (`CachedRead`, 10 minutes; `refresh=true` after purchase/restore); the app shows RevenueCat's `CustomerInfo` immediately after a purchase for the paywall's success, and the server's answer for everything after; fail closed (unknown → inactive); sandbox entitlements count only when the backend's environment is not production.

Tests (layer 5): "inactive when the server says so even if CustomerInfo says active"; "refresh after purchase"; "unknown fields fail closed"

Proof in the PR: test output.

Watch out: never cache `active: true` past `expiresAt`.

---

### PL6.3 · Bridge the old SubscriptionManager                                        size: S
Place in the tree: product › platform › billing › bridges
Repo · branch: NPRdoinglaundry · `pl/PL6.3-subscription-bridge`
Needs: PL6.2        Unblocks: retiring the old paywall (X bytes)

Why: the old paywall keeps working with true prices until the new one replaces it.

Spec: `SubscriptionManager` (`Services/SubscriptionManager.swift:19-52`) becomes a thin adapter over `Billing.Store`/`Billing.Entitlement`: `isSubscribed` from the entitlement, `monthlyPriceString`/`yearlyPriceString` from the offering's `displayPrice` (removing `$19.99/m` and `$239.99/y`), `purchase`/`restore` call through; `PaywallView`'s typed `$12.99`/`$139.99` read the same strings. The DEBUG `-MockProEntitlement` stays.

Tests (layer 5): "the old manager shows the store's prices"; "the old manager's purchase goes through Billing.Store"; "no price literal remains in the old files" (scan).

Proof in the PR: test output; a screenshot of the old paywall with store prices.

Watch out: this edits frozen old code only through the adapter; no layout changes to old screens.
