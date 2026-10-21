# Contract 01 · First run

Everything between opening Retrospect for the first time and your first home: the invite ticket (PI1, M14 "you're in"), sign-in and the launch stage, the questions (ON-3–9), privacy (ON-5, no data), connect and the knows-you meter (ON-6), getting your first episode ready (ON-10), the tease (ON-11), the paywall and the entitlement (ON-12), the first home and its setup recap (ON-13), push registration, and the force-update floor. Built on [contract 00](./00-platform.md) (envelopes, errors, headers, sign-in, sessions, access, the waitlist and the redeem door). Rules from [README.md](./README.md) apply: camelCase, ISO dates with milliseconds, closed enums decoded with an `unknown` case, `Idempotency-Key` on marked writes, fixtures for everything.

**Status:** draft for the founder's review, finished 21 Oct from the early draft. Agent fields were read from the agent's code (`../reference/agent-api-reference.md` §6, §7, §9.2, §10.4) and the backend's routes (`../reference/backend-reference.md`, `backend/src/routes/integrations.ts`). Where the brain can't give what a screen needs, the byte that adds it is named (§12). **§2 is Beta 1** (the invite ticket); everything else is phase 2.

**What this contract adds to contract 00** (the integrator folds these into 00 §4 when this is approved; until then this file is the source):
- two invite doors, `GET /public/invites/:code` (preview) and `POST /v2/invites/check` (look without spending);
- redeem becomes idempotent for the person who already redeemed that code, and its response gains `invite` (§2.3);
- one access transition door, `POST /v2/onboarding/complete` (approved → member);
- one error code, `subscription_required` (402), only if the founder picks the paid gate in §13 Q4.

---

## 1. Shared types

```ts
type InviteKind = "member" | "founder" | "review" | "unknown";

// What the ticket prints. Never contains the code itself (the app already has it) or anything about the inviter but a first name.
type TicketFace = {
  from: string | null;          // the inviter's first name ("priya"); founder invites carry the founder's first name; review invites null
  kind: InviteKind;
  serial: number;               // "no. 0412": the invite's place in the order invites were made (founder Q2); the app pads to 4 digits
  issuedOn: string;             // YYYY-MM-DD, the day the invite was made, in the inviter's time zone
};

type Level = "little" | "better" | "well" | "unknown";   // the knows-you meter's three words

type FirstRunStep = "reading" | "writing" | "voicing" | "ready" | "quiet" | "unknown";
// reading = Retro is still reading what you connected and said (agent stage reading | understanding)
// writing = the episode is being written (job stage writing)
// voicing = the episode is being recorded (job stage voicing)
// ready   = the first episode exists
// quiet   = not enough yet to say anything true (BEA.8 quiet_week | nothing_safe_to_say); the app shows the quiet line (§13 Q3), never an error

type Given = "voice" | "typed" | "skipped" | "unknown";

type Answer = {
  id: string;                   // raw_content.id
  questionKey: QuestionKey;
  text: string;                 // the person's words ("" when skipped)
  given: Given;
  createdAt: string;
};

// The app owns the question copy (it ships in the app's strings, the founder's wording); the server only stores the key.
type QuestionKey =
  | "name.place"        // "what should i call you, and where are you based?"
  | "year.from.now"     // best possible self
  | "care.most"         // values
  | "on.your.mind"      // what's taking up your head
  | "working.on"        // what you're working on, and how it's going
  | "keep.meaning"      // the change you keep meaning to make
  | "high.low"          // a high point and a low point
  | "people"            // who you'd call
  | "how.straight"      // ON-9, with Retro's recommendation
  | "yesterday"         // fallback, only when no calendar or health source is connected
  | "reading.watching"  // fallback, only when no screen time or YouTube source is connected
  | "this.week"         // ON-10's one more warm question
  | "unknown";

type SourceState = "available" | "connecting" | "connected" | "problem" | "hidden" | "unknown";
type SourceKind = "onDevice" | "account" | "unknown";       // on this iPhone (calendar, health) · your other apps (google, notion…)

type Source = {
  id: string;                   // the integration catalogue id: "apple_calendar", "apple_health", "google", "notion", "spotify", "youtube" …
  name: string;                 // "calendar"
  purpose: string;              // one plain line: "so i know what your days hold" (the source row's subline: purpose, never the data)
  kind: SourceKind;
  state: SourceState;
  group: "onThisIphone" | "yourOtherApps" | "seeAll" | "unknown";
};

type Job = {
  id: string;
  kind: "first" | "unknown";
  step: FirstRunStep;
  stepIndex: 1 | 2 | 3;         // reading = 1, writing = 2, voicing = 3; ready and quiet keep 3
  episodeId?: string;           // only when step = ready
  startedAt: string;
  estimateSeconds?: number;     // the door's estimate of the time left; omitted when unknown (the app then says nothing about time)
  failed?: { code: "upstream_unavailable" | "spend_limited" | "internal" | "unknown"; retryable: boolean };
};

type Entitlement = {
  active: boolean;
  productId?: "retro.monthly" | "retro.yearly" | "unknown";
  inTrial?: boolean;            // the yearly plan's free first month
  expiresAt?: string;
  willRenew?: boolean;
  environment?: "production" | "sandbox" | "unknown";
};
```

---

## 2. The invite ticket (Beta 1: PI1, PI2/M14)

The founder's board ("tear it. it's yours.", round 2, 21 Oct) sets the order: **sign in first, then the ticket prints, then you tear it; the tear is the moment it becomes yours, and nothing is spent until the stub separates.** So the app needs to know what to print before anything is spent, and the redeem happens on the tear.

```
link opened ──▶ GET /public/invites/:code   (signed out: "priya kept a place for you.")
sign in      ──▶ POST /v2/auth/apple         (contract 00 §3; access.state = waitlisted)
print        ──▶ POST /v2/invites/check      (signed in, waitlisted: what the ticket says, or why it can't be used)
tear         ──▶ POST /v2/invites/redeem     (contract 00 §4: spends it; access.state = approved)
"begin"      ──▶ (Beta 1) the current onboarding · (phase 2) ON-3
```

### 2.1 Preview (public, before sign-in)

`GET /public/invites/:code` — public, no token, bucket `public` (per IP: 30 a minute), no model call (BE2.0a)

→ `200`
```json
{ "success": true, "data": { "live": true, "face": { "from": "priya", "kind": "member", "serial": 412, "issuedOn": "2026-10-19" } } }
```
or, for a code that is unknown, used, revoked or expired, **the same 200 with nothing in it**, so a preview never says which:
```json
{ "success": true, "data": { "live": false, "face": null } }
```
- The code is normalised as the redeem door does (case-insensitive, dashes and spaces ignored, Crockford `O→0`, `I/L→1`); a string that can't be 13 Crockford characters is `{ live: false }`, not `invalid_request`.
- The app shows the name only when `live` is true ("priya kept a place for you."); otherwise the neutral line ("a place, kept for you."). It never tells a signed-out person that a code is used.
- Same rule as the link page (`GET /i/:code`, BE0.12): the inviter's first name appears only for a live code. Errors: `rate_limited` only.

### 2.2 Check (signed in, before spending)

`POST /v2/invites/check` — open to `waitlisted` users (the gate lets it through, like redeem), bucket `inviteCheck` (per user: 20 per 10 minutes; per IP: 60 per 10 minutes), no model call, **spends nothing** (BE2.0b)
```json
{ "code": "7KQ2-M9XD-4RTA-B" }
```
→ `200` when the code can be redeemed by this person now:
```json
{ "success": true, "data": { "usable": true, "face": { "from": "priya", "kind": "member", "serial": 412, "issuedOn": "2026-10-19" } } }
```
→ `200` when this person already redeemed it (a relaunch between the tear and "begin"):
```json
{ "success": true, "data": { "usable": false, "reason": "yours", "face": { "from": "priya", "kind": "member", "serial": 412, "issuedOn": "2026-10-19" } } }
```
Errors: `invite_invalid` (400: not a code, or no such code), `invite_used` (400: someone else used it; the ticket prints with "already used" and no tear handle), `invite_expired` (400), `rate_limited` (429), `invalid_request` (400: missing `code`). A `member`, `staff` or `approved` person gets `200 { usable: false, reason: "alreadyIn", face: null }` and the app shows nothing (they're already in).

`reason`: `"yours" | "alreadyIn" | "unknown"`.

### 2.3 Redeem (the tear) — contract 00 §4, amended

`POST /v2/invites/redeem` — `Idempotency-Key: <a UUID made when the tear starts>`, BE0.12's limit (5 per 10 minutes per user and per IP; an idempotent replay doesn't count), no model call
```json
{ "code": "7KQ2M9XD4RTAB" }
```
→ `200`
```json
{ "success": true, "data": { "access": { "state": "approved" }, "invitedBy": "priya", "invite": { "serial": 412, "redeemedOn": "2026-10-21" } } }
```
Amendments to contract 00 §4 (BE2.0b):
1. **Idempotent for the redeemer.** The same person redeeming the same code again (a retried tear, a lost response) gets the same `200`, not `invite_used`. Another person gets `invite_used`. The idempotency key covers a retry with a lost response even before the code lookup.
2. **`invite.redeemedOn`** (YYYY-MM-DD in the redeemer's time zone) is the date printed on the kept stub ("21 oct 2026"), and `invite.serial` repeats the face's number.
3. Errors unchanged: `invite_invalid`, `invite_used`, `invite_expired`, `rate_limited`; plus `upstream_unavailable` never (no agent call).

### 2.4 What the app keeps

Nothing from these doors is logged or sent to analytics (counts only: `invite.preview`, `invite.check.<outcome>`, `invite.redeem.<outcome>`). The code lives only in `Session.Store`'s pending-code slot until the tear succeeds, then is cleared. `face.from` is shown, never stored beyond the screen's lifetime, except `invitedBy` kept in memory for "you're in".

---

## 3. Launch: which screen first

The app decides the first screen from what it already has (PL1.9); one door helps after a reinstall.

| Session | `hasSignedInBefore` (Keychain) | Pending invite code | access.state | Screen |
|---|---|---|---|---|
| none | no | no | — | ON-1/2 splash (phase 2; Beta 1: the current onboarding) |
| none | no | yes | — | PI1 · T1 (the ticket's promise, with sign-in) |
| none | yes | any | — | AC-1 welcome back |
| signed in | — | yes | waitlisted | PI2 · the print |
| signed in | — | no | waitlisted | PI1 · T-alt (type a code, or join the waitlist) |
| signed in | — | — | approved, "you're in" not yet seen on this phone | PI2 · "you're in" (static, no print) |
| signed in | — | — | approved | ON-3 onward (Beta 1: the current onboarding), resumed at the first unanswered question |
| signed in | — | — | member, staff | home |
| signed in | — | — | suspended | "your account is paused." |
| any | — | — | — | PX force update, whenever `update_required` (426) or `GET /v2/meta` says so |

`POST /v2/onboarding/complete` — idempotent, bucket `write`, no model call (BE2.2b)
```json
{}
```
→ `200 { "success": true, "data": { "access": { "state": "member" } } }`. Called when ON-13 first appears (after the paywall, whatever was chosen). `approved` → `member`; `member`/`staff` unchanged (same 200); `waitlisted` → `invite_required` (the gate's normal answer).

---

## 4. The questions (ON-3–9, ON-10's warm question)

`POST /v2/onboarding/answers` — `Idempotency-Key: <clientEntryId>`, bucket `write`, no model call (BE2.2b). Goes through the outbox (PL3.3a): every answer is a write, and none may be lost.
```json
{ "questionKey": "name.place", "text": "sam, in london.", "given": "voice", "clientEntryId": "b1f0c6a2-4c1e-4a57-9d34-0f8f6f2e1a01", "createdAt": "2026-10-21T13:02:11.410Z" }
```
→ `201 { "answer": Answer }`; a repeat with the same key → `200` with the same answer; the same key with a different body → `409 idempotency_mismatch`.
- Validation: `questionKey` one of §1's list (not `unknown`; an unknown key is `invalid_request`); `text` 0–8,000 characters after trimming (`""` only with `given: "skipped"`); `createdAt` not more than 5 minutes ahead, not older than 30 days.
- Answering the same question again makes a new answer; the recap shows the latest per key; the brain reads both (like entries).
- Stored as one `raw_content` row per answer (`content_type 'onboarding_answer'`, `trust_class own_words`); handed to ingest like an entry (BE2.2a, BE2.2b).

`GET /v2/onboarding/answers` → `200 { "answers": Answer[], "count": 9 }`: the latest answer per `questionKey`, in the order given; skipped ones are left out of `answers` and `count`. Feeds ON-13's setup recap ("what you told retro while setting up · 9 answers") and resuming onboarding after a relaunch (the first key with no answer).

`POST /v2/onboarding/goals` — bucket `expensive`, timeout 30 s, no retry, counted against the spend cap (BE2.1; agent §6.2, saves nothing)
```json
{}
```
The door builds `answersText` from the person's stored answers (the app never sends them again) →
```json
{ "goals": [ { "title": "raise the seed", "description": "closing the round before the new year.", "because": "you said it's what you think about at night.", "quote": "i want to close the round before christmas" } ] }
```
At most 5; `reasoning` is renamed `because`; `cost` and `dropped` are never passed. Saying yes to one creates a goal through contract 04 (`POST /v2/goals { title, description, fromOnboarding: true }`). Whether first run shows them at all is §13 Q6 (lean: not in first run; Goals shows them later).

**ON-8, your daily brief** (D7: off until you opt in, at a time you choose) doesn't add a door here: the switch is contract 02 §3's `PUT /v2/briefs/enabled`, and the time is contract 06's (BE6.2's per-user brief time). Until that door exists the app keeps the chosen time in the outbox (`brief.time`, held) and sends it once it does (PL3.3a).

*Left out:* `POST /onboarding/interpret` (the legacy Cook 0 "magic moments", §6.1). Nothing in the v2 brain reads its output. §13 Q1.

---

## 5. Connect and the knows-you meter (ON-6)

`GET /v2/sources?for=onboarding` — bucket `read` (BE2.10)
```json
{ "success": true, "data": { "sources": [
  { "id": "apple_calendar", "name": "calendar", "purpose": "so i know what your days hold", "kind": "onDevice", "state": "connected", "group": "onThisIphone" },
  { "id": "apple_health", "name": "health", "purpose": "how you sleep and move", "kind": "onDevice", "state": "available", "group": "onThisIphone" },
  { "id": "google", "name": "google", "purpose": "mail and docs you choose", "kind": "account", "state": "available", "group": "yourOtherApps" }
] } }
```
- The door reads the integration catalogue and the person's `integration_connections`; sources without a working connector are `hidden` and left out (GitHub today; Notion until D9 is built).
- `purpose` comes from the catalogue (one plain line, never the data it reads).

`POST /v2/sources/:id/connect` — `Idempotency-Key`, bucket `write` (BE2.10)
- `account` sources → `200 { "authUrl": "https://accounts.google.com/o/oauth2/v2/auth?…" }`. The app opens it in `ASWebAuthenticationSession`; the provider returns to the existing callback, which redirects to `retrospect://integration-connected?provider=google&status=connected` (unchanged, PL5.2 parses it). The door wraps `POST /integrations/:providerId/connect/start`.
- `onDevice` sources → body `{ "granted": true }` after iOS permission is granted → `200 { "source": Source }` (`state: "connected"`). Wraps `POST /integrations/:providerId/native-connected`. Reading the data itself keeps using the device-batch path the current app already runs (bridged, PL3.3b).
- Errors: `not_found` (no such source, or hidden), `upstream_unavailable` (the provider's start failed), `invalid_request`.

`GET /v2/knows-you` — bucket `read`, no model call (BE2.3)
```json
{ "success": true, "data": { "level": "better", "connectedSources": 2, "answers": 7 } }
```
`level` is computed by the door from active connections and the person's answered questions (thresholds in one exported constant, §13 Q2: lean `little` below 1 source and 3 answers; `better` from there; `well` at 3+ sources and 7+ answers). The app re-reads it after each connect and each answer.

---

## 6. Getting ready and the first episode (ON-10, ON-11, ON-13)

`POST /v2/episodes/jobs` — `Idempotency-Key`, bucket `expensive`, counted against the spend cap (BE2.5b)
```json
{ "kind": "first" }
```
→ `202 { "job": Job }`. While a `first` job for this person is queued or running, another call returns that job (one first episode per person, never two). After a `ready` first job, a new call returns the ready job (`200`).

`GET /v2/episodes/jobs/first` → `200 { "job": Job | null }`: the person's first-episode job, for the launch resolver and relaunches (bucket `read`).

`GET /v2/episodes/jobs/:id` → `200 { "job": Job }`, bucket `read`. The app polls every 3 s while ON-10 is on screen (10 s after a minute; stops at `ready`, `quiet` or `failed`), and stops when the screen leaves; the "episode ready" push covers the rest (§7).

How the door gets there: while the agent's onboarding stage is `reading` or `understanding`, the job's step is `reading`, and the door nudges `POST /onboarding/advance` without waiting (fire and forget, behind BEA.5's lock). Once the runner starts, `step` follows the job's stage (BE2.5a). `readiness.facts` is never passed to the app.

`GET /v2/episodes/:id` → the episode (contract 03 defines it fully). ON-11 and ON-13 need:
```json
{ "success": true, "data": { "episode": {
  "id": "5f0e1d2c-3b4a-4596-8778-695a4b3c2d1e", "kind": "first", "title": "the week you started", "durationSeconds": 124,
  "audio": { "url": "https://<storage>/podcast-audio/…?token=…", "expiresAt": "2026-10-21T14:05:00.000Z" },
  "chapters": [ { "title": "where you are", "startSeconds": 0 }, { "title": "the first thing i noticed", "startSeconds": 31 } ],
  "transcript": [ { "text": "you started this week from london.", "startSeconds": 0 } ],
  "createdAt": "2026-10-21T13:05:00.000Z" } } }
```
`audio.url` is signed and expires in an hour (BEA.7); `chapters` may be `[]` until BE3.0; `transcript` lines carry `startSeconds` when measured (BE3.0), else they're omitted and the player reads without following.

---

## 7. Push (asked on ON-10; every later push)

`POST /v2/devices` — idempotent, bucket `write` (BE2.6)
```json
{ "token": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08", "environment": "sandbox", "appVersion": "1.0 (42)" }
```
→ `204`. A token registered to someone else moves to this person. Called on every launch once permission is granted (it refreshes `lastSeenAt`). Validation: hex, 64–200 characters; `environment` `sandbox | production`.

`DELETE /v2/devices/:token` → `204` (on sign-out; idempotent, never `404`).

**Founder decision (21 Oct): every notification is custom-written for the person and the moment; no generic copy, including the first-run "episode ready" push.** The outside-the-app plan (contract 07) owns the writer and the delivery through a Notification Service Extension. First run only decides *when* its push is sent and *what it's about*; the words come from that writer. What passes through Apple stays content-free: the payload carries `mutable-content: 1`, a neutral fallback alert that is never shown when the extension succeeds, and a reference the extension uses to fetch the written text over HTTPS (contract 07 defines that door and the fallback rule).
```json
{ "aps": { "alert": { "title": "retrospect", "body": "something's ready for you." }, "mutable-content": 1, "sound": "default" }, "kind": "episode_ready", "id": "5f0e1d2c-3b4a-4596-8778-695a4b3c2d1e", "noteId": "6a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "path": "retrospect://episode/5f0e1d2c-3b4a-4596-8778-695a4b3c2d1e" }
```
`kind`: `"episode_ready" | "brief_ready" | "unknown"` (closed list owned by contract 07); `noteId` is the written note the extension fetches. The fallback body is contract 07's to word; first run never adds a fixed string of its own.

---

## 8. The paywall and the entitlement (ON-12)

Purchases happen on the phone through RevenueCat (founder decision D6: **$19.99 a month; $199.99 a year with the first month free**). The app shows Apple's localized prices from the store, never typed-in ones. The server mirrors the result from RevenueCat's webhook.

`GET /v2/entitlement` — bucket `read` (BE2.8b); `?refresh=true` right after a purchase or restore asks RevenueCat directly (bucket `write`)
```json
{ "success": true, "data": { "active": true, "productId": "retro.yearly", "inTrial": true, "expiresAt": "2026-11-21T13:02:11.410Z", "willRenew": true, "environment": "production" } }
```
No entitlement → `{ "active": false }`. **Fail closed:** if RevenueCat can't be reached and the mirror says inactive, the answer is inactive. Sandbox purchases report `environment: "sandbox"` and never count as active against a production backend (TestFlight purchases are sandbox: the beta backend accepts sandbox, production refuses it; BE2.8a).

`POST /public/revenuecat/webhook` is server-to-server only (RevenueCat → backend; not called by the app).

Product ids (`retro.monthly`, `retro.yearly`) are the founder's App Store Connect ids; the app reads the current offering and never hard-codes a price.

---

## 9. Errors per door

| Door | Codes it can return (contract 00 §2 plus this file) |
|---|---|
| `GET /public/invites/:code` | `rate_limited` |
| `POST /v2/invites/check` | `invite_invalid`, `invite_used`, `invite_expired`, `rate_limited`, `invalid_request`, `unauthenticated`, `suspended` |
| `POST /v2/invites/redeem` | as check, plus `idempotency_mismatch` |
| `POST /v2/onboarding/complete` | `invite_required`, `unauthenticated` |
| `POST /v2/onboarding/answers` | `invalid_request`, `idempotency_mismatch`, `invite_required`, `rate_limited` |
| `GET /v2/onboarding/answers` | `invite_required` |
| `POST /v2/onboarding/goals` | `spend_limited`, `upstream_timeout`, `upstream_unavailable`, `rate_limited` |
| `GET /v2/sources`, `POST /v2/sources/:id/connect` | `not_found`, `upstream_unavailable`, `invalid_request`, `idempotency_mismatch` |
| `GET /v2/knows-you` | `upstream_unavailable` |
| `POST /v2/episodes/jobs` | `spend_limited`, `upstream_unavailable`, `rate_limited`, `idempotency_mismatch` |
| `GET /v2/episodes/jobs/first`, `/:id` | `not_found` (another person's job), `upstream_unavailable` |
| `GET /v2/episodes/:id` | `not_found`, `upstream_unavailable` |
| `POST /v2/devices`, `DELETE /v2/devices/:token` | `invalid_request` |
| `GET /v2/entitlement` | none of its own: with `refresh=true` and RevenueCat down, it answers from the mirror (fail closed) and logs `entitlement.refresh.failed` |
| every door | `unauthenticated`, `session_revoked`, `update_required`, `internal` |

---

## 10. Limits and idempotency (one table)

| Door | Bucket | Idempotent | Spend cap | Agent call |
|---|---|---|---|---|
| preview | public 30/min/IP | read | no | no |
| check | inviteCheck 20/10 min/user, 60/10 min/IP | read | no | no |
| redeem | BE0.12: 5/10 min/user and IP | `Idempotency-Key` + per-redeemer | no | no |
| onboarding/complete | write | by state | no | no |
| answers (POST) | write | `clientEntryId` | no | no (ingest handed off) |
| answers (GET), knows-you, sources (GET), jobs (GET), episode (GET), entitlement (GET) | read | read | no | readiness / summary only |
| goals | expensive | no (saves nothing) | yes | yes (one model call) |
| sources connect | write | key | no | no |
| episodes/jobs (POST) | expensive | one queued or running per person | yes | yes (the whole episode) |
| devices | write | by `(token, environment)` | no | no |

---

## 11. Enums: closed lists, decoded with `unknown`

`InviteKind`, `Level`, `FirstRunStep`, `Given`, `QuestionKey`, `SourceState`, `SourceKind`, `Source.group`, `Job.kind`, `Job.failed.code`, `check.reason`, `Entitlement.productId`, `Entitlement.environment`, push `kind`. The door logs any value outside a list (`contract.unknownEnum` with the enum's name, never the value when it could be content).

---

## 12. What the brain and backend must add (bytes)

| Need | Byte | Repo |
|---|---|---|
| Ticket preview and check, invite serial, idempotent redeem for the redeemer | BE2.0a, BE2.0b | backend |
| Google sign-in | BE2.4 | backend |
| `onboarding_answer` in the "sent by the person" set | BE2.2a | agent |
| Answers doors and `onboarding/complete` | BE2.2b | backend |
| `GET /understanding/:userId/summary` | BE2.3a | agent |
| Knows-you door | BE2.3b | backend |
| Sources doors over the existing integration routes | BE2.10 | backend |
| Onboarding goals door | BE2.1 | backend |
| `podcast_jobs` table, runner and first-kind wiring | BE2.5a1, BE2.5a2 | agent |
| Episode job and episode doors | BE2.5b | backend |
| Devices; the APNs sender; the "first episode ready" push | BE2.6, BE2.7a, BE2.7b | backend |
| Entitlement mirror and door | BE2.8a, BE2.8b | backend |
| Notion (only if D9 says so) | BE2.9a–d | agent + backend |
| Already planned elsewhere and needed here: spend counted (BEA.4), one first pass at a time (BEA.5), signed audio (BEA.7), quiet weeks aren't errors (BEA.8), refresh tokens (BE0.4), invites (BE0.12), version floor (BE0.10) | — | — |

---

## 13. Founder decisions this contract needs (work goes ahead on the lean)

1. **The "magic moments" step.** Lean: leave the legacy `interpret` call out of first run. If you want one "moment" line on ON-10 or ON-11, BE2.1 adds the door and the getting-ready card gains one line.
2. **Knows-you thresholds.** Lean: `little` until 1 source or 3 answers; `better` from there; `well` at 3+ sources and 7+ answers. The words are on the meter; the numbers are yours.
3. **A quiet first episode.** When there isn't enough to say anything true yet, ON-10 ends in `quiet`. Lean copy: "i don't have enough to make it true yet. keep talking; it all goes in." and ON-11 is skipped (straight to the paywall without the paused player, or to ON-13: lean ON-13, no paywall until there's something to hear).
4. **The paid gate.** Lean: no door refuses reading; new episodes and briefs stop when the free period ends, with a new `subscription_required` (402) on `POST /v2/episodes/jobs` (kind weekly, later) and brief generation. First run itself is never gated.
5. **Push timing.** Lean: ask on ON-10 while waiting, with Apple's prompt only after the person taps "tell me"; the ask promises what the founder decided (every note is written for you, never a generic ping). The notes themselves are contract 07's.
6. **Goals in onboarding.** Lean: not in first run; the candidates appear later as Goals' question cards (contract 04).
7. **Which questions** (the v2 set in `docs/second-brain/brief-onboarding-questions.md`, 8 core + 2 fallbacks) and **one model-written follow-up per answer** (lean: no follow-ups in the first build; they add a model call and a wait to every answer).
8. **Inviter's name before sign-in** (§2.1). Lean: yes, only for a live code, exactly like the link page.
9. **The ticket's number** (`serial`). Lean: the invite's place in the order invites were made, printed "no. 0412". Alternatives: your member number (only known after the tear), or no number.
10. **Who a founder invite is "from".** Lean: your first name, since you send it personally. Review invites (App Review) print "an invitation" with no name.

## 14. Fixtures

`fixtures/01/` (invented, obviously fake content; responses are full envelopes, requests are bodies):
- invite: `invite.preview.live.json`, `invite.preview.notlive.json`, `invite.check.request.json`, `invite.check.usable.json`, `invite.check.yours.json`, `invite.check.alreadyin.json`, `invite.redeem.request.json`, `invite.redeem.response.json`
- launch: `onboarding.complete.response.json`
- answers: `answer.create.request.json`, `answer.create.request.skipped.json`, `answer.create.response.json`, `answers.list.json`, `answers.list.empty.json`
- goals: `goals.candidates.json`, `goals.candidates.empty.json`
- sources: `sources.list.json`, `sources.list.minimal.json`, `source.connect.account.json`, `source.connect.ondevice.request.json`, `source.connect.ondevice.response.json`
- knows-you: `knows-you.little.json`, `knows-you.better.json`, `knows-you.well.json`
- jobs: `job.create.request.json`, `job.reading.json`, `job.writing.json`, `job.voicing.json`, `job.ready.json`, `job.quiet.json`, `job.failed.json`, `job.first.none.json`, `episode.first.json`, `episode.first.minimal.json`
- push: `device.register.request.json`, `push.episode-ready.json`
- entitlement: `entitlement.active-trial.json`, `entitlement.active-monthly.json`, `entitlement.inactive.json`
- errors (01's doors): `error.invite_invalid.json`, `error.invite_used.json`, `error.invite_expired.json`, `error.invite_required.json`, `error.rate_limited.json`, `error.spend_limited.json`, `error.upstream_unavailable.json`, `error.upstream_timeout.json`, `error.not_found.json`, `error.invalid_request.json`, `error.idempotency_mismatch.json`, `error.unauthenticated.json`, `error.update_required.json`, `error.internal.json`
