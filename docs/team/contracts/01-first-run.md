# Contract 01 · First run

Onboarding from the first question to the first home: ON-3–9 (the questions), ON-5 (privacy), ON-6 (connect, the knows-you meter), ON-10 (getting your first episode ready), ON-11 (the tease), ON-12 (the paywall), ON-13 (the first home with the setup recap), plus push registration and the entitlement. Sign-in, access and invites are in contract 00. Status: **early draft, written ahead of phase 2 for the founder's review**. Every agent field was read from the agent's code on 21 Oct (`../reference/agent-api-reference.md` §6, §7, §9.2, §10.4); where the agent can't give what the screen needs, the byte that fixes it is named. Rules from [README.md](./README.md) apply (camelCase, ISO dates, closed enums with an `unknown` case, fixtures for everything).

## 1. Shared types

```ts
type Level = "little" | "better" | "well";                 // the knows-you meter's three words

type FirstRunStep = "reading" | "writing" | "voicing" | "ready" | "quiet";
// reading  = Retro is still reading what you connected and said (agent stage `reading`/`understanding`)
// writing  = the episode is being written  (job stage `writing`)
// voicing  = the episode is being recorded (job stage `voicing`)
// ready    = the first episode exists
// quiet    = not enough yet to say anything true (BEA.8 `quiet_week` / `nothing_safe_to_say`); the app shows the founder's quiet line, never an error

type Answer = {
  id: string;                         // raw_content id
  questionKey: string;                // the app's stable key for the question, e.g. "who.where"
  text: string;                       // the person's words ("" when skipped)
  given: "voice" | "typed" | "skipped";
  createdAt: string;
};
```

## 2. The questions (ON-3–9)

`POST /v2/onboarding/answers` — idempotent (`Idempotency-Key: <clientEntryId>`), bucket `write`, no model call (BE2.2)
```json
{ "questionKey": "who.where", "text": "sam, in london.", "given": "typed", "clientEntryId": "<uuid>", "createdAt": "2026-10-21T13:02:11.410Z" }
```
→ `201 { "answer": Answer }`; a repeat → `200` with the same answer. Answering the same question again creates a new answer (the latest wins in the recap; the brain sees both, like entries).

`GET /v2/onboarding/answers` → `{ "answers": Answer[], "count": 9 }` in the order given (latest per `questionKey`). Feeds ON-13's setup-recap card ("what you told retro while setting up · 9 answers").

`POST /v2/onboarding/goals` — bucket `expensive`, timeout 30 s, no retry (BE2.1; agent §6.2, saves nothing)
```json
{}
```
The door builds `answersText` from the person's stored answers (the app never sends them again) →
```json
{ "goals": [ { "title": "raise the seed", "description": "closing the round before the new year.", "because": "you said it's the thing you think about at night.", "quote": "i want to close the round before christmas" } ] }
```
At most 5. `reasoning` is renamed `because`; `cost` and `dropped` are never passed. Saying yes to one creates a goal through contract 04 (`POST /v2/goals { title, description, fromOnboarding: true }`); until contract 04 exists, BE2.1 adds that one door.

## 3. Connect and the knows-you meter (ON-6)

`GET /v2/knows-you` — bucket `read` (BE2.3)
```json
{ "level": "better", "connectedSources": 2, "answers": 7 }
```
`level` is computed by the door from connected sources and answers (thresholds: §7.2). Connecting a source uses the existing integration doors (outside this contract); the app re-reads this after each connect and after each answer.

## 4. Getting ready and the first episode (ON-10, ON-11, ON-13)

`POST /v2/episodes/jobs` — idempotent (`Idempotency-Key`), bucket `expensive` (BE2.5b)
```json
{ "kind": "first" }
```
→ `202 { "job": Job }`. While a job for this person is queued or running, a second call returns that job (one episode per onboarding, never two).

`GET /v2/episodes/jobs/:id` → `{ "job": Job }`, bucket `read`. The app polls every 3 s while ON-10 is on screen (backing off to 10 s after a minute), and stops when `step` is `ready` or `quiet`, or `failed` is set.

```ts
type Job = {
  id: string;
  step: FirstRunStep;
  stepIndex: 1 | 2 | 3;               // ON-10's "2 of 3": reading=1, writing=2, voicing=3 (ready/quiet keep 3)
  episodeId?: string;                 // when step = ready
  startedAt: string;
  estimateSeconds?: number;           // "about two minutes": the door's estimate for the remaining time, omitted when unknown
  failed?: { code: "upstream_unavailable" | "spend_limited" | "internal"; retryable: boolean };
};
```

How the door gets there: while the agent's onboarding stage is `reading` (or `understanding`), the job is in `reading` and the door nudges `POST /onboarding/advance` without waiting (BEA.5 makes concurrent nudges safe); once the job runner starts, `step` follows the job's stage (BE2.5a). `readiness.facts` is never passed to the app.

`GET /v2/episodes/:id` → the episode (contract 03 defines it fully; for ON-11 and ON-13 the app needs): `{ id, title, subtitle: "the week you started", durationSeconds, audio: { url, expiresAt }, chapters: [{ title, startSeconds }], createdAt }`. The audio URL is signed and expires in an hour (BEA.7); the app asks again when it expires mid-listen.

*Open:* `POST /v2/onboarding/interpret` (the agent's "magic moments", §6.1) is the legacy Cook 0 path that nothing in the v2 brain reads. Unless ON-10/ON-11 need a "moment" line, the contract leaves it out (§7.1).

## 5. Push (permission screen and every later push)

`POST /v2/devices` — idempotent, bucket `write` (BE2.6)
```json
{ "token": "<apns hex>", "environment": "sandbox", "appVersion": "1.0 (42)" }
```
→ `204`. Registering a token that belonged to someone else moves it to this person. Called on every launch after permission is granted (it refreshes `lastSeenAt`).

`DELETE /v2/devices/:token` → `204` (on sign-out; idempotent, `404` never returned).

Push payloads carry no content (contract 07 will list them): `{ "aps": { "alert": { "title": "retro", "body": "your first episode is ready." }, "sound": "default" }, "kind": "episode_ready", "id": "<episodeId>", "path": "retro://episodes/<episodeId>" }`.

## 6. The paywall and entitlement (ON-12)

Purchases happen on the phone through RevenueCat (founder decision D6: $19.99 a month; $199.99 a year with the first month free; the app shows Apple's localized prices from the store, never typed-in ones). The server mirrors the result.

`GET /v2/entitlement` — bucket `read` (BE2.8); `?refresh=true` right after a purchase or restore asks RevenueCat directly (bucket `write`)
```json
{ "active": true, "productId": "retro.yearly", "inTrial": true, "expiresAt": "2026-11-21T13:02:11.410Z", "willRenew": true, "environment": "production" }
```
No entitlement → `{ "active": false }`. **Fail closed:** if RevenueCat can't be reached and the mirror says inactive, the answer is inactive. Sandbox purchases are reported with `environment: "sandbox"` and never count as active in a production build.

## 7. Founder decisions this contract needs

1. **The "magic moments" step.** Leave the legacy `interpret` call out of first run (lean), or show one "moment" line on ON-10/ON-11?
2. **Knows-you thresholds.** Lean: `little` until 1 source or 3 answers; `better` from there; `well` at 3+ sources and 7+ answers. The words are on the meter; the numbers are yours.
3. **Quiet first episode.** When there isn't enough to say anything true yet, ON-10 ends in the quiet state. The copy (lean: "i don't have enough to make it true yet. keep talking; it all goes in.") and whether ON-11 is skipped.
4. **The paid gate.** Which doors refuse a person with no active entitlement after onboarding (lean: none refuse reading; new episodes and briefs stop after the free period), and the new error code `subscription_required` (402) it would add to contract 00.
5. **Push timing.** Ask for push permission on ON-10 while waiting (lean, it's when "we'll tell you when it's ready" is true) or later.
6. **Goals in onboarding.** Show the up-to-5 goal candidates during first run (lean: on ON-13, as yes / not quite cards) or only later in Goals.

## 8. Fixtures

`fixtures/01/`: `answer.create.json`, `answers.list.json`, `answers.list.empty.json`, `goals.candidates.json`, `goals.candidates.empty.json`, `knows-you.little.json`, `knows-you.well.json`, `job.reading.json`, `job.writing.json`, `job.voicing.json`, `job.ready.json`, `job.quiet.json`, `job.failed.json`, `episode.first.json`, `entitlement.active-trial.json`, `entitlement.inactive.json`, and one per error code each door can return. Invented content only.
