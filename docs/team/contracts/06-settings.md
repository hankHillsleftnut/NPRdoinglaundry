# Contract 06 · Settings and account

Every page behind your picture on the You tab: ST-1 (settings), ST-2 (daily brief), notifications (P23a, not drawn yet), ST-3 and ST-4 (sources), ST-5 (privacy), ST-6 (how straight), ST-7 (voice), ST-8 (what i've learned), ST-9 (account), AC-2 (signing out) and PI3 (your invites). Built on contract 00. Status: **draft for the founder's review**, written 21 Oct by the settings planner. Every agent field below was read from the brain's code at `a886060` (`src/routes/settings.ts`, `src/ambient/switch.ts`, `src/appetite/appetite.ts`, `src/routes/integrations.ts`) and the backend's at `a679fec` (`src/routes/integrations.ts`, `src/integrations/integration-catalog.ts`). Where the brain can't give what a page needs yet, the byte that adds it is named (cards in `../flows/settings/backend.md`).

Nothing in this contract is in Beta 1 (`../first-ship.md`): settings stay on the current screens until phase 6. **The App Store needs three things from it before submission: account deletion in the app (§8), restore purchases (§7) and subscription management (§7).** Their minimum set is listed in §11 so they can ship ahead of the rest if the founder wants.

## 1. Shared rules for this contract

- Every setting **applies at once** (switch rule 1). Writes are set-to-value and safe to repeat, so they carry no `Idempotency-Key`; the app sends only the latest value when the person taps quickly (PL3.7a coalesces). The one exception is the export request (§5), which is a job and is idempotent by key.
- Settings never block on the brain: a write that the brain refuses comes back as an error and the app moves the control back (switch states: "error · snaps back").
- Times are the person's **local wall time** in the zone the app sends on every request (`X-Time-Zone`, contract 00 §1), stored on `users.time_zone` (BE0.4).
- Copy the app shows (titles, sublines, the "picked by retro" reason, what a source reads) is lowercase and plain. Where the server supplies a sentence, the contract says so and its fixture shows the shape with invented words.
- No door in this contract returns another person's anything. Every source, export and deletion is looked up by `(user from the token, id)`; a stranger's id is `not_found`.

## 2. Settings: one read, four writes

```ts
type BriefSettings = {
  enabled: boolean;                       // users.daily_brief_enabled; on by default for Beta 1 (founder 22 Oct, migration 026; supersedes D7's opt-in), off once the person switches it off
  time: string;                           // "HH:mm", local, 15-minute steps; default "08:00" (new column, BE6.1a)
  length: "short" | "standard" | "long" | "unknown";   // default "standard" (new column, BE6.1a; founder question Q1)
  nextAt: string | null;                  // ISO UTC instant of the next brief, null when off (the journal's "ready by 8:30")
};
type AmbientSettings = {
  enabled: boolean;                       // the person's own switch (users.ambient_enabled, default true)
  effective: boolean;                     // enabled && the founder's master switch is on
  pausedForEveryone: boolean;             // the founder's master switch is off (BE6.1d); never says why
};
type Straightness = {
  level: "justWhatHappened" | "gentleQuestions" | "honestObservations" | "dontHoldBack" | "unknown";  // appetite 0..3
  source: "yours" | "picked";             // stated → yours; inferred → picked (by Retro)
  why: string | null;                     // plain words, only when picked; built by the brain without a model (BE6.1b)
};
type VoiceSettings = {
  persona: "warm" | "steady" | "bright" | "unknown";  // users.voice_persona: thoughtful_friend | wise_mentor | energetic_host (names: Q3)
  speed: 0.8 | 1 | 1.25 | 1.5;            // playback speed for briefs and episodes, applied on the phone (new column, BE6.1a; Q4)
  personas: Array<{ id: "warm" | "steady" | "bright"; name: string }>;   // the choices, in order
};
type NotificationSettings = {             // which kinds Retro may send, and how they look (BE6.7)
  brief: boolean;                         // "today's brief": only sent while the brief itself is on
  episode: boolean;                       // "a new episode"
  questions: boolean;                     // "a question from retro"
  hideWordsOnLockScreen: boolean;         // default false: when true, the sender sends a private notification (contract 07)
};
```

**Founder, 21 Oct: every notification is written for the person and the moment, including the brief's; there is no generic copy.** The outside plan (contract 07) owns the writer and the delivery. This contract only stores the person's choices and the sender honours them (BE6.7 `notificationSettingsFor`). Whether iOS allows notifications at all is the phone's to know; the app shows it beside these switches.

**`GET /v2/settings`** → `{ "brief": BriefSettings, "ambient": AmbientSettings, "straightness": Straightness, "voice": VoiceSettings, "notifications": NotificationSettings }`. One request fills ST-1's values and the four pages behind them. Cheap (`read` bucket); the door calls the brain's four reads in parallel with a 5 s timeout each, and fails the whole read if any fails (no half-filled settings page).

**`PATCH /v2/settings/brief`** `{ "enabled"?: boolean, "time"?: "HH:mm", "length"?: "short" | "standard" | "long" }` (at least one field) → `{ "brief": BriefSettings }`.
- `time` must match `^([01]\d|2[0-3]):(00|15|30|45)$`; anything else is `invalid_request`.
- Contract 02's `PUT /v2/briefs/enabled` stays (the journal uses it); both write the same column through the same service, so they can't disagree.
- Turning the brief on doesn't make a brief now; the first one comes at the next `time` (`nextAt`).

**`PUT /v2/settings/ambient`** `{ "enabled": boolean }` → `{ "ambient": AmbientSettings }`. Off means Retro reads only what the person sends (`src/ambient/switch.ts` header). Turning it off never deletes anything already read (that's §4 and §8).

**`PUT /v2/settings/straightness`** `{ "level": "justWhatHappened" | "gentleQuestions" | "honestObservations" | "dontHoldBack" | null }` → `{ "straightness": Straightness }`. `null` is "let it decide": hands the choice back to Retro (the brain's `level: null`).

**`PATCH /v2/settings/voice`** `{ "persona"?: "warm" | "steady" | "bright", "speed"?: 0.8 | 1 | 1.25 | 1.5 }` → `{ "voice": VoiceSettings }`. A new persona applies to the next brief and episode; nothing already made is re-voiced.

**`PATCH /v2/settings/notifications`** `{ "brief"?: boolean, "episode"?: boolean, "questions"?: boolean, "hideWordsOnLockScreen"?: boolean }` (at least one) → `{ "notifications": NotificationSettings }`. A new person reads every kind on and `hideWordsOnLockScreen: false`.

**`GET /v2/settings/voice/samples/:persona`** → `{ "url": "…", "expiresAt": "…", "durationSeconds": 9 }`. A short fixed sample per voice, recorded once by the integrator and stored privately (no model spend per person; the same file for everyone). Signed for 1 hour.

## 3. What i've learned (ST-8)

**`GET /v2/settings/learned`** →
```ts
{ state: "learning" | "tooEarly" | "off" | "unknown";
  headline: string | null;     // one inky sentence, e.g. "you answer questions about work most, 8 of 10."
  why: string | null;          // the plain why, e.g. "you skip ones about family (1 of 5), so i ask those less."
  lastChangedAt: string | null }
```
- Built by the brain from `user_preferences.metadata.learning` (`GET /settings/:userId/learning`: arms `why`, `hypothesis:<framework>`, `answer:<domainId>` with asked/answered/rate) by **templates, never a model** (BE6.1c). Numbers come straight from the counts; area names come from the eight domain labels; framework ids are never shown.
- `tooEarly`: fewer than 5 questions asked in total, or no snapshot yet ("too early" state on ST-8). `off`: `ENABLE_LEARNING` isn't on, so Retro isn't adjusting (`inUse: false`); the page says it plainly instead of inventing a lesson.
- There is no write: nothing on ST-8 changes what Retro learned (the brain has no `PUT`).

## 4. Sources (ST-3, ST-4)

```ts
type Source = {
  id: string;                              // the provider id from the catalogue: "google_calendar", "healthkit", …
  name: string;                            // "calendar", "health" (lowercase display name)
  where: "onPhone" | "account" | "file" | "unknown";   // collectionMode native_ios | oauth_api | data_export
  status: "connected" | "syncing" | "needsYou" | "notConnected" | "comingSoon" | "unknown";
  purpose: string;                         // the row's subline when fine: "so your brief knows your day"
  problem: string | null;                  // the row's subline when status is needsYou: "stopped reading on monday"
  reads: string | null;                    // ST-4 "reads": "your events: when, how long, and who was there."
  helpsMeSee: string | null;               // ST-4 "helps me see"
  lastReadAt: string | null;               // integration_sync_states.last_success_at
  hasData: boolean;                        // anything read from it is still kept (shows "delete what it read…")
  sharedGrant: string | null;              // sources that share one permission ("google": calendar, docs, gmail, youtube); null if its own
};
```
- Status mapping (door, one tested function): connection `connected` + a job running → `syncing`; `connected` → `connected`; `action_required` or 3+ consecutive sync failures → `needsYou`; `disconnected` or no row → `notConnected`; catalogue `availability` other than `available` and no row → `comingSoon`. Copy (`purpose`, `reads`, `helpsMeSee`) lives in the backend catalogue next to the provider (BE6.5b), written with the founder. `problem` is built from `last_error`'s **kind** and the day, never the provider's message.
- With ambient off (§2), sources still show as connected; ST-3 says once at the top that nothing is being read in the background (P25 state `ambientOff`).

**`GET /v2/sources`** → `{ "sources": Source[] }`, connected first, then needs-you, then the rest in catalogue order. `comingSoon` sources are listed only on "add a source" (P25a), never on ST-3.

**`POST /v2/sources/:id/sync`** → `{ "source": Source }` (status `syncing`). Repeating while a sync runs returns the same state (the brain's job key). Bucket `write`, at most 6 per hour per source (`rate_limited`).

**`DELETE /v2/sources/:id`** (disconnect) → `{ "source": Source, "grant": "revoked" | "notNeeded" | "failed" | "unknown", "affected": string[] }`. `affected` lists every source id this disconnected: Google's one consent covers calendar, docs, gmail and youtube together, so disconnecting one disconnects all four, and the ST-4 dialog says so before you confirm (it lists every source with the same `sharedGrant`). Stops reading, keeps what it read (ST-4's subline), and for account sources **revokes the grant at the provider** (new brain route BE6.5a; today's backend disconnect only flips a status and leaves the provider's grant alive). `failed` still disconnects here and is logged as a count; the page says nothing extra. For on-phone sources, `notNeeded`: the app stops sending, and ST-4 offers the system Settings link (`App-prefs` is not allowed; `UIApplication.openSettingsURLString`) for anyone who wants iOS to stop sharing too.

**`DELETE /v2/sources/:id/data`** `{ "confirm": "delete" }` → `{ "source": Source }` (`hasData` false once the brain's `delete_connection_data` job finishes; until then the row reads "deleting"). Removes everything taken from that source, as the dialog says.

**`POST /v2/sources/:id/connect`** → `{ "mode": "browser", "authorizationUrl": "https://…" }` for account sources (PKCE state as today, 10 minutes), or `{ "mode": "onPhone" }` for on-phone sources (the app asks iOS, then calls `connected`). The OAuth callback returns to the app on `retrospect://integration-connected?provider=<id>&status=syncing|error` as today. **Shared with ON-6** (contract 01): one door for connecting in both places.

**`POST /v2/sources/:id/connected`** (on-phone sources, after iOS permission) → `{ "source": Source }`.

**`POST /v2/imports`** `{ "sourceId": "chatgpt", "filename": "export.zip", "contentType": "application/zip", "byteSize": 1048576 }` (Idempotency-Key: a client UUID) → `{ "import": { "id": "…", "uploadUrl": "…", "expiresAt": "…" } }`; `POST /v2/imports/:id/complete` `{ "sha256": "…" }` → `{ "import": { "id": "…", "state": "reading" } }`. Wraps today's `/integrations/:providerId/imports` and `/imports/:id/complete` (1 GB cap, signed upload). Only `file` sources accept imports.

## 5. Download my data (ST-5)

```ts
type DataExport = {
  id: string;
  state: "preparing" | "ready" | "failed" | "expired" | "unknown";
  requestedAt: string;
  readyAt: string | null;
  expiresAt: string | null;               // ready + 7 days; the file is deleted then
  sizeBytes: number | null;
  url: string | null;                     // signed, 24 hours, only while ready; refetch for a fresh one
};
```
**`POST /v2/account/export`** (Idempotency-Key: a client UUID) → `{ "export": DataExport }`. One export at a time: while one is `preparing`, asking again returns it. At most one new export per 24 hours (`rate_limited` with `retryAfterSeconds`). Bucket `expensive` (it reads everything, no model calls). The error's `message` is contract 00's, the same for every door; the page writes its own copy ("you can download your data once a day") and takes the timing from `retryAfterSeconds` (integrator, 22 Oct).
**`GET /v2/account/export/latest`** → `{ "export": DataExport | null }`.
- The file is a zip: one JSON file per kind of thing (entries, facts and their evidence, answers, goals, briefs, episodes with their scripts, guesses, sources and what they read, settings), plus the person's own audio (voice notes, episode and brief audio). No embeddings, no internal bookkeeping, no other person's data (BE6.3a).
- When it's ready, the outside plan's writer and sender notify the person (written for them, like every notification; contract 07), if notifications are allowed. The export kind is part of the account, not one of the switchable kinds.

## 6. Account summary (ST-9)

**`GET /v2/account`** →
```ts
{ signedInWith: "apple" | "google" | "unknown";
  plan: null | {
    active: boolean;
    period: "monthly" | "yearly" | "unknown";        // from the product id
    trial: boolean;                                  // period_type trial|intro
    renews: boolean;                                 // will_renew
    renewsOrEndsAt: string | null;                   // expires_at
    billingIssue: boolean;
    store: "appStore" | "other" | "unknown";
  };
  deletion: { needsAppleConfirmation: boolean } }
```
- `plan` comes from the entitlement mirror (BE2.8). **Prices never come from the server**: the app shows Apple's localized price from StoreKit/RevenueCat for the product (D6). `plan: null` = never subscribed (or a grandfathered account): ST-9 shows "become a member ›" to the paywall (P07).
- `deletion.needsAppleConfirmation` is true when the person signed in with Apple and the server holds no Apple refresh token for them (every account that signed in before BE0.5 shipped, or whose code exchange failed). The app then asks Apple for a fresh authorization code before deleting (§8, BE6.6a).

## 7. The subscription: manage and restore

No new doors. The app:
- **Manage subscription ↗** opens Apple's own manage-subscriptions sheet in the app (`AppStore.showManageSubscriptions(in:)`), falling back to `https://apps.apple.com/account/subscriptions` if the sheet can't show (Guideline 3.1.2: people can manage and cancel).
- **Restore purchases** calls RevenueCat `restorePurchases()`, then `GET /v2/entitlement` (BE2.8, which refreshes from RevenueCat) and `GET /v2/account`. Outcomes the page shows: restored, nothing to restore, failed (with a retry), offline (Guideline 3.1.1).
- Access always comes from a verified purchase on the server (fail closed). The app never grants anything from a client-side receipt.

## 8. Delete my data, delete my account

**`DELETE /v2/account/data`** `{ "confirm": "delete" }` → `{ "deleted": true, "access": { "state": "approved" } }`. Built in **BE0.8** (phase-0 card; not rewritten here). Removes everything Retro read and learned, keeps the account, sessions, subscription and invites, and sends the person back through onboarding (`approved`). This contract asks one change of BE0.8 (BE6.6c): keep the person's **choices** (brief on/off and time, ambient, a stated "how straight", voice and speed) and drop everything **learned** (inferred straightness, learning, directives).

**`DELETE /v2/account`** `{ "confirm": "delete", "appleAuthorizationCode"?: string }` → **202** `{ "deletion": { "id": "…", "state": "deleting" | "deleted" } }`. Built in **BE0.7** (with BE0.5's Apple revoke, BE0.6's brain sweep, BE2.8's RevenueCat delete). This contract asks two changes of BE0.7:
- **BE6.6a:** accept `appleAuthorizationCode` and, when no Apple refresh token is stored, exchange it and revoke the result (Apple TN3194). Without either, an Apple-signed account gets **409 `apple_confirmation_required`** and nothing is deleted. A Google-signed account never needs it.
- **BE6.6b:** answer **202** as soon as the account is locked (every session revoked, `access` set so no door answers, the deletion row written) and finish the steps in the background, resuming from the `deletions` log, which must not cascade away with the user row. A phone that's killed or goes offline mid-way can't leave a half-deleted account, and the person isn't held on a spinner for two minutes.
- After the 202, the person's tokens are dead; the app erases everything on the phone (PL3.7g) and shows the splash. A retry that meets `session_revoked` or `unauthenticated` after the app sent a delete is treated as done.
- **Before confirming**, the dialog says what's deleted ("your entries, episodes and everything retro knows. this can't be undone.") and, when `plan.active && plan.renews`, that **Apple keeps billing until the subscription is cancelled**, with "manage subscription ↗" beside it (README §9; Guideline 5.1.1(v)).

New error code (extends contract 00 §2):

| Code | When | The app shows |
|---|---|---|
| `apple_confirmation_required` (409) | delete account, Apple-signed, no stored token and no code | Apple's sign-in sheet for a fresh code, then sends the delete again |

## 9. Signing out and your invites

- **Sign out of this device:** contract 00 §3 `POST /v2/auth/signout`. Before it, the app counts what's waiting in the outbox (PL1.5 `hasUnsent`): AC-2 shows "send, then sign out" and waits for the outbox to empty, or plain "sign out" when nothing waits. Sign out everywhere is v2.
- **Your invites:** contract 00 §4 `GET /v2/invites/mine` (three single-use invites, `link` while unused). The share sheet carries the link and one line; the line **must say it works once** (founder copy, lean: "i saved you a place on retrospect. this link works once, so it's just for you."). Nothing new on the server.

## 10. What the brain must add (bytes in `../flows/settings/backend.md`)

| Need | Today | Byte |
|---|---|---|
| brief time and length per person | fixed 08:00 UTC cron; no length | BE6.1a (columns + routes), BE6.2b (per-minute local scheduler), BE6.2c (length in the writer) |
| playback speed; a voice route | `voice_persona` only, written by the old `/profile/persona` | BE6.1a |
| "picked by retro" in plain words | `reasons` are internal strings ("stays at 0: 1 engagement signal(s)…") | BE6.1b |
| what i've learned, in sentences | raw arm statistics | BE6.1c |
| the founder's master ambient switch without a redeploy | env `AMBIENT_MASTER=off` | BE6.1d (a product dial) + BE6.1i (dashboard toggle) |
| revoke one source's grant | only all grants at once (`/integrations/accounts/revoke`) | BE6.5a |
| export my data | nothing | BE6.3a, BE6.3b |
| deletion sweeps the export and brief audio | BE0.6 lists four buckets | BE6.3b |
| notification choices per kind, and hiding words on the lock screen | nothing | BE6.7 (backend; the outside plan's sender reads it) |

## 11. The App Store minimum (if submission comes before the rest of phase 6)

ST-9 with: your plan (from `GET /v2/account`), manage subscription ↗, restore purchases, sign out (AC-2), delete account (§8 with Apple revoke and the billing reminder). Doors: BE0.5–BE0.7, BE0.13, BE2.8, BE6.4, BE6.6a, BE6.6b. App: PL6.1, PL6.2, PL6.4, PL1.5, PL3.7d, PL3.7e, PL3.7g, PL3.7i, P31, P33, C48, C50. The founder can ship this slice alone (founder question Q11 in the flow README).

## 12. Decisions the founder makes for this contract

Listed with leans in `../flows/settings/README.md` §8 (Q1–Q17). The ones that change shapes here: brief length (Q1, §2), voice names (Q3, §2), speeds (Q4, §2), what the master switch shows (Q6, §2), Apple confirmation at deletion (Q8, §8), what "delete my data" keeps (Q10, §8), what a private notification shows (Q17, §2).

## 13. Fixtures

`fixtures/06/`: `settings.json`, `settings.minimal.json`, `settings.paused-for-everyone.json`, `brief.patch.request.json`, `brief.response.json`, `ambient.put.request.json`, `ambient.response.json`, `straightness.put.request.json`, `straightness.response.json`, `voice.patch.request.json`, `voice.response.json`, `notifications.patch.request.json`, `notifications.response.json`, `voice.sample.json`, `learned.json`, `learned.too-early.json`, `learned.off.json`, `sources.json`, `sources.minimal.json`, `source.sync.response.json`, `source.disconnect.response.json`, `source.delete-data.request.json`, `source.delete-data.response.json`, `source.connect.browser.json`, `source.connect.on-phone.json`, `import.create.request.json`, `import.create.response.json`, `import.complete.response.json`, `export.create.response.json`, `export.latest.ready.json`, `export.latest.none.json`, `account.json`, `account.minimal.json`, `account.delete.request.json`, `account.delete.response.json`, `account.delete-data.request.json`, `account.delete-data.response.json`, `error.apple_confirmation_required.json`, `error.rate_limited.json`, `error.not_found.json`, `error.invalid_request.json`, `error.upstream_timeout.json`. The errors every door shares (`unauthenticated`, `session_revoked`, `invite_required`, `suspended`, `update_required`) are contract 00's fixtures. Every fixture is invented: no real person, no real account, no real words.
