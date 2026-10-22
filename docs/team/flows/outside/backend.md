# Outside the app · backend cards

Contract: [07-outside.md](../../contracts/07-outside.md). Every door is built with the kit (BE0.1), passes the door suite (BE0.2) and the invite gate (BE0.12). Every agent route gets a two-user PGlite test that runs as `service_role` (testing.md layer 2). The backend validates every `fixtures/07/*.json` door and push file against its zod schemas (layer 4).

**The tree on this side:**
- **share** › reading a link (BE7.1a agent, BE7.1b door) · saving it (BE7.2a agent, BE7.2b door)
- **notifications** › preferences (BE7.3) · the writer (BE7.8a agent, BE7.8b deny list and checks) · the text door and notify token (BE7.9a, BE7.9b) · when to send (BE7.4) · the brief's push (BE7.5) · one question (BE7.6) · silent refresh (BE7.7)
- **retiring the old** › version floor (X02a) · route tombstones (X07.0) · old route groups (X07a–X07g) · private episode audio (X07h) · legacy brain tables (X08a–X08c)

**Order:**
1. BE7.3 → BE7.2a → BE7.2b → BE7.1a → BE7.1b, which lets the share extension save and read.
2. BE7.8b → BE7.8a → BE7.9b → BE7.4 → BE7.9a → BE7.7 → BE7.5 → BE7.6. BE7.4 onwards needs BE2.6, BE2.7 and BE6.2 merged first. Founder decision 21 Oct: every notification is written custom (contract 07 §5.1).
3. Retirement runs on its own clock: X02a any time after BE0.10; X07.0 before any X07 group; X08 only after X07b.

At most two in review at once.

Numbers in migration file names (`0NN`, agent `1NN`) are claimed at merge time. Other phases are claiming 152+ in the agent and 009–011 in the backend.

---

## Share

### BE7.1a · Agent: read one link without saving it                    size: M
Place in the tree: outside › EX-1 share › reading a link › agent `POST /reference/:userId/preview`
Repo · branch: Retrospect-agent · `agent/BE7.1a-reference-preview`
Needs: BEA.2 (ownership on agent routes), BEA.4 (every model call counted)      Unblocks: BE7.1b

Why: when you share a link, Retro tells you in one line what it is and which of your goals it might go with, before you decide to save it.

Inputs:
- Contract 07 §2.1.
- Code anchors:
  - `src/reference/enrich.ts`: `checkUrl` (the locked-down fetch: http/https only, standard ports, private addresses refused and re-checked on every redirect, 8 s, 1.5 MB, text only), `tweetOembedUrl`, `MAX_TEXT`, `TOPICS`, the summary prompt
  - `src/reference/youtube-transcript.ts`: `youtubeVideoUrl`, `fetchTranscript`
  - `src/reference/relevance.ts`: `RELEVANCE_SYSTEM`, `relevancePrompt`, `vetRelevance`
  - `src/pipelines/spend-guard.ts`: `checkDailySpend`
- Reference: agent-api-reference §10.8 (`reference_items` columns).

Spec:
- Route `POST /reference/:userId/preview` with body `{ url: string, text?: string }`, behind the shared secret like every agent route. Ownership: the user exists, and goals are read for that user only.
- Steps inside:
  1. Run `checkUrl(url)`. On any refusal, return `{ reading: 'unreadable', thing: { url, kind, site } }`; this is never an error.
  2. Fetch the page with the same reader `enrich.ts` uses. **Factor that reader out as `readPage(url)`**, shared with `enrichPending`, so there's one fetch path and one set of limits.
  3. For a YouTube video, the transcript; for a post, oEmbed.
  4. Compute `length`: words / 230, or the transcript's last cue, rounded up.
  5. One model call for the one-line read, with a new prompt `PREVIEW_SYSTEM`: "say in one plain lowercase sentence what this page is about; never address the reader; under 140 characters". The read must be about the page, never "you".
  6. One relevance call through `relevancePrompt` with this single item and the person's active goals only (no canonical questions). `vetRelevance` keeps real goal ids; take the first.
- **No writes**: not to `reference_items`, not to `raw_content`. A test proves the table counts are unchanged.
- Spend: both calls go through the counted Anthropic wrapper (BEA.4) with run kind `reference_preview`. If `checkDailySpend` says no, return 429 with `spentUsd` (the door maps it to `spend_limited`) **before** fetching.
- Response: `{ thing: { url, kind, title?, site, length? }, read: string | null, goalId: string | null, reading: 'ready' | 'unreadable' }`. The door adds the goal's title.
- Timeouts: fetch 8 s (existing), each model call 6 s; the agent's whole budget is under 12 s.
- Logs: route, userId, `reading`, the host only (never the path or query), ms, token counts. Never the page text, the read or the person's text.

Steps: factor `readPage` out of `enrichPending` (no behaviour change; its tests stay green) → preview prompt and pure post-check → route → spend → tests.

Acceptance:
- A readable page returns a title, a site, a length and a one-line read.
- A YouTube link's length comes from its transcript.
- A private-address URL returns `unreadable` without a fetch.
- Nothing is written.
- Over the spend cap, it's refused before fetching.

Tests (layer 1–2):
- `a readable page gets a one-line read about the page, never about the reader`
- `a read starting with "you" or containing "your" is dropped to null` (pure)
- `a link to a private address is unreadable and never fetched`
- `a redirect to a private address is unreadable`
- `a video link's length comes from the transcript's last cue`
- `a goal suggestion is only ever one of the person's own active goals` (two users: user B's goals are never offered to A)
- `over the daily spend cap the preview is refused before any fetch`
- `the preview writes nothing to reference_items or raw_content`
- `enrichPending behaves exactly as before after readPage is factored out` (existing tests)

Proof: test output; a local-staging run of three invented links (page, video, unreadable), with counts and `reading` only.

Watch out:
- DNS rebinding is a known gap in `checkUrl` (enrich.ts header). The preview fetches on demand, so it's more exposed than the background enrich. **Pin the checked address for the fetch** (connect to the resolved IP with the Host header) in this byte, or record why not in the findings log.
- Never use the person's `text` as instructions to the model: it goes in a quoted block labelled as theirs.

---

### BE7.1b · Door: `POST /v2/shares/preview`                                size: S
Place in the tree: outside › EX-1 share › reading a link › door
Repo · branch: backend · `be/BE7.1b-shares-preview`
Needs: BE0.1, BE0.2, BE0.12, BE7.1a      Unblocks: PL7.5a

Why: the share sheet can show "retro's read" and a goal it might go with, safely and cheaply.

Inputs: contract 07 §2.1, §8, §9; fixtures `share.preview.*.json`, `error.preview.spend_limited.json`.

Spec:
- zod:
  - `url` is a string ≤ 2,048, parsed by `new URL`, protocol `http:`/`https:`, no username or password, port empty, 80 or 443 (→ `invalid_request`)
  - `text` is optional, trimmed, ≤ 2,000
- Cache: an in-process LRU (200 entries) keyed by `sha256(userId + canonical url)` with a 10-minute TTL. It's per instance (one Render instance today). The key holds no URL in clear, and the cache stores only the mapped response.
- Agent call: `agent.post('/reference/:userId/preview', …, { timeoutMs: 12_000, retry: 'none' })`.
- Map: `goalId` → `goesWith: { goalId, title }`, reading the goal title through the existing goals read with an ownership check. A missing goal gives `goesWith: null`.
- **Server-side honesty check:** drop `read` to `null` if it matches `/^you\b|\byour\b/i` or is over 140 characters. It's logged as the count `previewReadDropped`.
- Bucket `expensive` with a door-specific limit of 20 an hour (contract 07 §9). Agent 429 with `spentUsd` → `spend_limited`; agent timeout → `upstream_timeout`.
- Log: door, userId, status, `reading`, cache hit or miss, ms. Never the URL, the text or the read.

Acceptance: every `share.preview.*` fixture is reproduced from a faked agent; the 21st call in an hour is `rate_limited`; a cached second call doesn't reach the agent.

Tests (door suite, plus):
- `a second preview of the same link within ten minutes doesn't call the agent`
- `another user's preview of the same link isn't served from the first user's cache`
- `a read that addresses the reader is dropped to null`
- `an unreadable page is a 200 with reading unreadable, not an error`
- `ftp, credentials or port 8080 are invalid_request`
- `the 21st preview in an hour is rate_limited`
- `no log line contains the url, the text or the read`

Proof: test output.

Watch out: the extension waits at most 8 s (PL7.5a). Don't add server retries that push past that.

---

### BE7.2a · Agent: a saved link keeps the goal the person chose           size: S
Place in the tree: outside › EX-1 share › saving › agent
Repo · branch: Retrospect-agent · `agent/BE7.2a-reference-goal-source`
Needs: BEA.2      Unblocks: BE7.2b

Why: when you say a link goes with a goal, Retro keeps your choice instead of second-guessing it later.

Inputs:
- Contract 07 §2.2.
- Code anchors:
  - `src/reference/capture.ts`: `extractLinks`, `captureReferences` (upsert on `raw_content_id,url`)
  - `src/reference/relevance.ts`: `relatePending` (updates `goal_ids`, `related_at` for rows with `related_at` null)
  - `src/jobs/material-arrivals.ts:20-23`
  - `planner/daily.ts:22` (`SENT_TYPES` includes `shared_link`)

Spec:
- Migration `1NN_reference_goal_source.sql`: `reference_items.goal_source text not null default 'model' check (goal_source in ('model','person'))`.
- `captureReferences`:
  - select `metadata` with `content`
  - when `content_type = 'shared_link'` and `metadata.goal_id` is a UUID owned by the user (checked against `goals`) with `goal_choice` `kept` or `changed`, insert with `goal_ids = [goal_id]`, `goal_source = 'person'`, and `related_at = now()` (so `relatePending` skips it)
  - with `goal_choice = 'none'`, `goal_ids = []`, `goal_source = 'person'`, `related_at = now()` (the person said "none"; the model doesn't add one)
- `relatePending` keeps filtering `related_at is null`, and additionally filters `goal_source = 'model'` (belt and braces).
- Verify that a `shared_link` insert raises a material arrival (the arrival trigger on `raw_content`). If it doesn't, add `shared_link` to whatever the trigger keys on, in the same migration.

Acceptance: a shared link with a kept goal is captured with that goal and is never re-related; one with "none" gets no goal from the model.

Tests:
- `a shared link with a kept goal is captured with that goal and marked as the person's`
- `relatePending never changes a person-sourced row`
- `a goal id that belongs to another user is ignored and the row is left for the model` (two users)
- `goal choice none is kept as no goal`
- `a shared_link insert raises a material arrival`

Proof: test output.

Watch out: `extractLinks` uses the message's words as the reason (`intent`). The door puts the note first (BE7.2b) so the person's "why" becomes the intent.

---

### BE7.2b · Door: `POST /v2/shares`                                         size: M
Place in the tree: outside › EX-1 share › saving › door
Repo · branch: backend · `be/BE7.2b-shares-create`
Needs: BE0.0, BE0.1, BE0.2, BE0.12, BE1.1 (its `Entry` mapper), BE7.2a      Unblocks: PL7.4, PL7.5b

Why: anything you save from another app lands in your bank exactly once, even when you saved it on a plane.

Inputs:
- Contract 07 §2.2, §8; contract 02 §5 (`Entry`); fixtures `share.create.*.json`, `error.share.*.json`.
- Reference: backend-reference §10 (`insertRawContent`, dedup, the `onboarding_profile` key bug fixed in BE0.0).
- Code anchors: `src/services/content-insert.ts:65-109`, `src/services/agent-handoff.ts`.

Spec:
- zod:
  - `clientEntryId` UUID equal to the `Idempotency-Key` header
  - `url` per BE7.1b's rule, optional
  - `text` ≤ 20,000, optional
  - `note` ≤ 2,000, optional
  - at least one of `url` and `text`
  - `goalChoice` in `kept | changed | none`; `goalId` UUID required iff `goalChoice` isn't `none`
  - `sharedAt` with BE1.1's skew rules (≤ 5 minutes ahead, ≤ 30 days old)
- **Goal ownership before writing:** a `goalId` not owned → `not_found`, and nothing is written.
- Content: `[note, text, url].filter(Boolean).join('\n\n')`. The note comes first because the person's words are the link's reason (BE7.2a).
- Write: `insertRawContent` with:
  - `content_type 'shared_link'`, `content_date = sharedAt`, `processing_status 'pending'`
  - `metadata = { client_entry_id, goal_id?, goal_choice, app_version, request_hash }`
  - `idempotencyKey = clientEntryId`, the user's time zone
- New → 201 `{ entry, thing }`, where `thing` comes from BE7.1b's cache if present, else `null` (no fetch here). Replay → 200 with the stored row; a different `request_hash` → 409 `idempotency_mismatch`.
- No synchronous ingest call: the material-arrivals job picks it up within a minute (BE7.2a). If the arrival trigger doesn't cover it, the door hands off with `handOffToAgent(runAgentIngest, …)` like BE1.1. Decide in the PR from BE7.2a's finding and note it.
- `Entry` mapping: BE1.1's mapper. `kind` is `imported` until contract 02 adds `shared` (contract 07 §11.1), then `shared`.
- Bucket `write`; never spend-checked.
- Log: door, userId, status, has-url/has-text/has-note booleans, `goalChoice`, ms. Never the content.

Acceptance: one save = one row; ten retries = one row; the person's note leads the stored content; a foreign goal writes nothing.

Tests (door suite, plus):
- `a share creates one entry`
- `retrying a share returns the same entry and writes nothing new`
- `a reused key with a different note is idempotency_mismatch`
- `a goal id from another user is not_found and nothing is stored` (two users)
- `a text-only share is saved without a url`
- `neither url nor text is invalid_request`
- `a share dated 31 days ago is refused`
- `the note comes first in the stored content`
- `the stored type is shared_link and the entry kind maps per contract 02`
- `no log line contains the url, text or note`
- fixtures: `share.create.*`, `error.share.*`

Proof: test output; a local-staging save from the share extension (PL7.5b's proof) seen in `GET /v2/entries` (counts).

Watch out: don't route through the old `POST /content` (no `shared_link` in its `ContentTypeSchema`, and its response shape is the old app's).

---

## Notifications

### BE7.3 · Notification preferences                                         size: S
Place in the tree: outside › EX-3 notifications › preferences
Repo · branch: backend · `be/BE7.3-notification-preferences`
Needs: BE0.1, BE0.2      Unblocks: BE7.4, PL7.10, the settings screen (contract 06)

Why: you choose which kinds of notification Retro may send, and it never sends one you turned off.

Inputs: contract 07 §5.4; fixtures `notifications.preferences*.json`.

Spec:
- Migration `0NN_notification_preferences.sql`: `notification_preferences (user_id uuid PK references users on delete cascade, brief_ready bool not null default true, episode_ready bool not null default true, questions bool not null default true, check_ins bool not null default true, updated_at timestamptz not null default now())`. There's no row until the first PUT, and the defaults are read in code from one constant.
- `GET /v2/notifications/preferences` → the four booleans plus `quietHours` (constant `21:00`–`08:00` in v1).
- `PUT` with a strict zod partial of the four booleans (unknown keys → `invalid_request`), upserted, returning the full object.
- Buckets `read` / `write`. Logs: door, userId, which keys changed (names only), ms.

Acceptance: defaults with no row; a PUT changes only what it names; another user's preferences are unreachable (no id in the path).

Tests: `defaults are all on with no row` · `a put of one key leaves the others alone` · `a string "true" is invalid_request` · `quiet hours are read-only` · `two users' preferences never mix` · fixtures.

Proof: test output.

Watch out: the settings screen is contract 06's. This door is only the data, so don't add a quiet-hours setter.

---

### BE7.4 · Deciding when to send: one a day, never at night               size: M
Place in the tree: outside › EX-3 notifications › when to send
Repo · branch: backend · `be/BE7.4-push-schedule`
Needs: BE2.6 (devices), BE2.7 (the sender), BE7.3, BE7.8a (the writer)      Unblocks: BE7.9a, BE7.5, BE7.6, BE7.7, BE3.3 and BE4.3 (they call it instead of the sender)

Why: Retro never buzzes you twice in a day or in the middle of the night, whatever it has to say.

Inputs: contract 07 §5.1–§5.3, §5.5, push fixtures; later-phases BE2.7 (sender, collapse ids).

Spec:
- Migration `0NN_notification_log.sql`: `notification_log (id uuid pk, user_id uuid references users on delete cascade, kind text check (kind in ('briefReady','episodeReady','question','checkIn','exportReady','refresh')), ref_id uuid null, local_day date not null, status text check (status in ('held','sent','dropped','failed')), reason text null, due_at timestamptz, sent_at timestamptz null, title text null, body text null, fallback_title text null, fallback_body text null, writer text null check (writer in ('model','no_model')), created_at timestamptz default now())`. The four text columns are the person's own data: they cascade with the user and are nulled by a daily job after 7 days, when the content door stops serving them with:
  - unique `(user_id, local_day)` where `kind in ('briefReady','episodeReady','question','checkIn') and status = 'sent'`, so the one-a-day rule is enforced by the database
  - unique `(user_id, kind, ref_id)`, so the same thing is never announced twice
- `src/push/schedule.ts`: `schedule({ userId, kind, refId, dueAt })`, which:
  1. reads the preferences (BE7.3) and drops with reason `off` when the kind is off, or when `briefReady` and `daily_brief_enabled` is false
  2. computes the local day and time from `users.time_zone`; inside 21:00–08:00 it inserts `held` with `due_at` = the next 08:00 local
  3. otherwise tries `sent` inside a transaction: on a unique violation of the one-a-day rule, it compares priority (episode › brief › question › check-in). A lower or equal priority is `dropped` (`reason: 'daily'`). A **higher** priority that arrives after a lower one was already sent is also dropped: nothing is ever recalled
  4. **at the moment of sending** (also for held rows, so the words fit when they arrive), calls the writer (BE7.8a) with `{ kind, refId, localTime }`. It stores the full text and the fallback on the row, then calls the BE2.7 sender with the §5.2 payload built by `buildPayload(row)`. That's one pure function: `aps.alert` = the fallback, `mutable-content: 1`, `r.v: 2`, `r.id` = the row id. It's tested against every push fixture. If the writer fails or times out (8 s), the no-model fallback (BE7.8b) fills both texts and the push still goes
- A minute cron (`ENABLE_PUSH_SCHEDULE`) sends `held` rows whose `due_at` has passed. A held `briefReady` or `question` from an earlier local day is `dropped` (`stale`).
- `refresh` (silent) skips the daily rule, with at most 4 a day per user (a count query).
- `exportReady` skips the daily rule.
- **Ordering rule:** a new `kind` is sent only after an app version whose service extension and router know it is the version floor (X02a). Older apps would still show its fallback, but couldn't route the tap. A test lists the kinds and the minimum version for each.
- Logs: userId, kind, status, reason, writer (`model` or `no_model`), ms. Never a payload body or any notification text.

Acceptance: two alerts on one local day → one sent; an alert at 23:00 local → sent at 08:00; turned-off kinds are never sent; a refresh never counts against the one a day.

Tests:
- `a second alert on the same local day is dropped`
- `the day is the person's day, not UTC` (UTC−8 at 23:30)
- `an alert due at 23:00 local is held and sent at 08:00`
- `a held brief from yesterday is dropped as stale`
- `a turned-off kind is dropped with reason off`
- `the brief alert is never sent when the daily brief is off`
- `an episode beats a brief when both are due` and `a higher one after a lower one was sent is dropped, not recalled`
- `the same brief is never announced twice` (retry)
- `silent refreshes stop at four a day and never count as the daily one`
- `every payload matches its fixture`
- `the payload's alert is the stored fallback and carries mutable-content`
- `a payload never contains the full text` (the full text is only on the row and served by BE7.9a)
- `a held push is written when it is sent, not when it was held`
- `when the writer fails the push still goes with the no-model fallback`
- `notification text is nulled after seven days`
- `two users' daily counts never mix`

Proof: test output; local staging with a sandbox device token (integrator; counts only).

Watch out: APNs collapse ids stop stacking on the phone but don't stop the send, and the log is the rule. Keep the sender (BE2.7) dumb: it sends what `schedule` decided.

---

### BE7.5 · The brief's notification                                       size: S
Place in the tree: outside › EX-3 notifications › brief ready
Repo · branch: backend (+ agent hook) · `be/BE7.5-brief-ready-push`
Needs: BE7.4, BE6.2 (per-user brief time), BE1.3b (audio, for the minutes)      Unblocks: PL5.3's brief tap, T05d

Why: on mornings you've asked for a brief, your phone tells you once it's ready, in a line written about your day that's safe for anyone to glance at.

Inputs: contract 07 §5.2 `briefReady`; agent-api-reference §2 (briefs); later-phases BE6.2.

Spec:
- How the backend learns a brief is made: BE6.2's per-minute scheduler already runs in the backend and calls the agent's generate. On success with `kind = 'brief'`, it calls `schedule({ kind: 'briefReady', refId: brief.id, dueAt: now })`. The writer reads the brief itself (BE7.8a's inputs: weekday, minutes from `audio.durationSeconds`, part count, the parts' text for its own use). A brief with no audio is written as "ready to read". On a quiet brief, no alert, only `refresh` (BE7.7).
- When the door later refetches, the brief id in the link is the contract-02 id (UUID).

Tests: `a made brief schedules one brief push` · `a quiet brief sends no alert` · `a brief with no audio is written as ready to read` · `a regenerated brief for the same day is not announced again`.

Proof: test output.

Watch out: production makes no briefs until D10. Test on staging only.

---

### BE7.6 · "one question for you"                                        size: S
Place in the tree: outside › EX-3 notifications › one question
Repo · branch: backend · `be/BE7.6-question-push`
Needs: BE7.4, BE1.4 (guesses door), D11 (the `speak` dial on), the you area's YO-4 (where the tap lands)      Unblocks: T05d

Why: when Retro has a question worth your minute, it asks at most once a week, and it never puts the question itself on your lock screen.

Spec:
- A daily job (`ENABLE_QUESTION_PUSH`) at the person's 18:00 local (EX-3 `1H3E-0` draws the question at 6:10 pm and the brief at 8:30; inside the allowed hours) picks at most one `offered` guess older than 24 hours that hasn't been announced (unique `(user_id, kind, ref_id)`). It only runs if the user's last `question` push was ≥ 7 days ago, `speak` is on and `questions` is on. It calls `schedule({ kind: 'question', refId: guess.id })`.
- No model call. Nothing is generated: it's only a pointer to an existing guess.

Tests: `at most one question a week` · `no question when speaking is off` · `an answered guess is never announced` · `never another user's guess`.

Watch out: the old `POST /notifications/generate` (agent) reads legacy tables and has no safety rules. It is **not** used here; BE7.8a is the writer. The question's text is about a guess, so the writer is given only `{ kind: 'guess' }` and the guess's topic word when it passes the deny list. It never gets the guess sentence, so it can't assert it.

---

### BE7.7 · The silent refresh                                             size: S
Place in the tree: outside › EX-3 notifications › silent refresh
Repo · branch: backend · `be/BE7.7-refresh-push`
Needs: BE7.4      Unblocks: PL7.9, an up-to-date widget (P37)

Why: your widget shows today's brief even if you haven't opened the app since it was made.

Spec: on every made brief (quiet or not) and every made episode, call `schedule({ kind: 'refresh', scope: [...] })`. That sends `apns-push-type: background`, `apns-priority: 5`, no alert, with the `push.refresh.json` shape. It's capped at 4 a day (BE7.4).

Tests: `a made brief sends one refresh with scope brief` · `refreshes are background pushes with priority 5 and no alert` · `the fifth refresh in a day is dropped`.

Watch out: iOS may never deliver a background push (low power, a force-quit app). Nothing on the phone may depend on it (PL7.9).

### BE7.8a · Agent: the notification writer                                size: M
Place in the tree: outside › EX-3 notifications › the writer › agent `POST /notifications/:userId/write`
Repo · branch: Retrospect-agent · `agent/BE7.8a-notification-writer`
Needs: BEA.2, BEA.4 (counted model calls), BE7.8b (the checks it must pass)      Unblocks: BE7.4, and through it every push

Why: founder, 21 Oct: "every notification needs to be written custom, even the notification for showing briefs." Every notification reads like Retro talking to you about your day, never a generic line, and never something you'd mind a stranger seeing.

Inputs:
- Contract 07 §5.1, §5.2, §5.5.
- agent-api-reference §2 (briefs), §3 (hypotheses), §7 (episodes), §8.4 (the old `POST /notifications/generate`: model `ANTHROPIC_COOK_B_MODEL`, legacy tables; replaced, not reused).

Spec:
- Route `POST /notifications/:userId/write { kind, refId, localTime, timeZone }` → `{ title, body, fallback: { title, body }, checks, usage }` (fixture `notification.write.agent.json`).
- **Inputs it gathers** (a closed list per kind, each a short fact; `facts[]` is what the invented-fact check compares against):
  - `briefReady`: weekday, minutes, part count, and each part's first sentence (for its own understanding)
  - `episodeReady`: the episode title, the first chapter's title, minutes
  - `question`: "a question is waiting", and the guess's **topic word** only if it passes the deny list; never the guess text (rule: never asserts a guess)
  - `checkIn`: the goal's title, the days since it was last mentioned
  - `exportReady`: the expiry date
- One model call (the cheap writing model, as in the old route, through the counted wrapper with run kind `notification_write`) writes both texts with the house-voice prompt `NOTIFY_SYSTEM`:
  - lowercase, at most 40 / 110 characters
  - a tease, not a disclosure
  - no health, body, relationships, money, places or other people's names
  - a guess only as a question that's waiting
  - only the facts given
- Every reply goes through BE7.8b's `checkNotification(reply, facts)`. On failure it retries once with the failures named. If that fails too: if only the full text failed, the full text becomes the fallback; if the fallback failed, the no-model fallback (BE7.8b) fills it.
- Spend: `checkDailySpend` first. Over the cap, there's no model call, only the no-model fallback for both texts (`checks.usedNoModelFallback: true`).
- Timeout 6 s per call; the whole route stays under 8 s (BE7.4's wait).
- Logs: route, userId, kind, check counts, retried, usedNoModelFallback, tokens, ms. **Never the text.**

Acceptance:
- Every kind gets a title and body within the limits, and a fallback with zero deny-list hits.
- Over the spend cap, it still returns custom text without a model call.

Tests (layer 1–2):
- `each kind returns a title, body and fallback within the length limits`
- `the fallback never contains a deny-list term` (property test across invented inputs that contain health, relationship and money words)
- `a reply naming a fact not in the inputs is retried, then replaced`
- `the question's text never contains the guess's sentence`
- `a reply with a capital letter, emoji or exclamation mark fails the house-voice check`
- `over the daily spend cap no model is called and the no-model fallback is returned`
- `the call is counted against the spend cap as notification_write`
- `another user's brief can never be an input` (two users)
- `no log line contains a title or body`

Proof: test output; twenty written examples over invented test users in the PR body. They're invented accounts, so showing them is allowed.

Watch out:
- The writer reads the brief's real words to write well. Those words never leave the agent except through the checked texts.
- The model is told the lock screen is public. The deny list is the guarantee, not the prompt.

---

### BE7.8b · Agent: the deny list, the checks and the no-model fallback    size: S
Place in the tree: outside › EX-3 notifications › the writer › checks
Repo · branch: Retrospect-agent · `agent/BE7.8b-notification-checks`
Needs: —      Unblocks: BE7.8a

Why: whatever the writer produces, a notification on your lock screen never says something sensitive or untrue.

Spec:
- `src/notifications/deny-list.ts`: a reviewed term list across health and body, mental health, sex and relationships, money and debt, legal, religion and politics, places and addresses, plus the names of people in the user's graph (passed in). Matching is whole-word and stemmed, case-insensitive.
- **The founder reviews the list in the PR.** The list is data: changing it is a PR with a test case.
- `checkNotification(reply, facts)` is pure and returns the failures:
  - length
  - house voice
  - deny-list hits (full text and fallback, counted separately)
  - **invented terms:** numbers and capitalised or rare words not in `facts`
- An optional classifier call for replies the list can't decide (ambiguous words), counted and capped at one per push.
- `noModelFallback(kind, facts)` is pure, built from non-sensitive facts only: weekday, minutes, part count, kind. For example: "tuesday, in four minutes" / "three things from your day worth hearing." Each kind has a few shapes, chosen by a hash of `(userId, day)` so it varies. Its output is itself run through `checkNotification` in tests.

Tests:
- `every deny-list category catches its test words`
- `a person's own name in the graph is caught`
- `an invented number is flagged`
- `the no-model fallback passes every check for every kind`
- `the no-model fallback differs across days`

Watch out: a deny list over-blocks (a goal titled "run" is fine; "therapy" isn't). False positives fall back safely, so tune toward blocking.

---

### BE7.9a · Door: `GET /v2/notifications/:id/content`                   size: S
Place in the tree: outside › EX-3 notifications › the text door
Repo · branch: backend · `be/BE7.9a-notification-content`
Needs: BE0.1, BE0.2, BE7.9b, BE7.4 (its `notification_log` holds the text)      Unblocks: PL7.11. Until it ships, pushes still go out showing their custom fallback

Why: the custom words reach your phone directly from Retro, not through Apple.

Spec:
- Auth: **only** the notify token (BE7.9b); a normal access token is refused here, so a compromised notify token can read nothing else.
- Ownership: `notification_log.user_id` must equal the token's user, else `not_found`. A row older than 7 days or with null text is `not_found`.
- Response `{ title, body, expiresAt }`.
- Bucket `read`.
- Logs: door, userId, status, ms. Never text.

Tests:
- `the person's notification text is returned`
- `another user's notification is not_found` (two users)
- `an access token is refused here`
- `a notify token is refused on every other door` (the door suite iterates every route)
- `text older than seven days is not_found`
- `no log line contains the text`
- fixtures `notification.content.json`, `error.notification.not_found.json`

---

### BE7.9b · The notify token                                               size: S
Place in the tree: outside › EX-3 notifications › the notify token
Repo · branch: backend · `be/BE7.9b-notify-token`
Needs: BE0.4 (sessions, device ids)      Unblocks: BE7.9a, PL7.12

Why: the notification on your phone can fetch its own words even if you haven't opened Retro for days, without the phone keeping anything that could sign you in.

Spec:
- Migration `0NN_notify_tokens.sql`: `notify_tokens (id uuid pk, user_id uuid references users on delete cascade, device_id text, token_hash text unique, expires_at timestamptz, revoked_at timestamptz null, created_at timestamptz default now())`.
- `POST /v2/notifications/token` (normal access token) issues 32 random bytes as `ntk_<base64url>`, stores the SHA-256 hash, sets `expiresAt` to now + 7 days, and revokes the device's previous token. Bucket `write`, at most 10 a day per device.
- `authMiddleware` gains a separate verifier `notifyTokenAuth` used only by BE7.9a.
- Sign-out (this device) and delete-account revoke the device's tokens (BE0.4 / BE0.7 hooks, one line each).

Tests:
- `a new token revokes the device's previous one`
- `an expired or revoked token is unauthenticated`
- `sign-out revokes it`
- `account deletion removes it`
- `tokens are stored hashed`
- fixture `notifications.token.json`

Watch out: never accept a notify token in `authMiddleware`'s normal path.

---

## Retiring the old (backend and brain)

Every step has the same shape:
1. **Count.** Prove there's no use from supported versions (door logs, counts only).
2. **Tombstone.** The route answers 410 with a plain message, behind a switch, for 14 days. Flipping the switch back is the rollback.
3. **Delete** the code in its own PR. A revert and a deploy is the rollback.
4. **Data** goes last, after a backup the founder confirms.

Nothing here deploys without the founder's yes (context §3).

### X02a · Version floor: the report and the switch                        size: S
Place in the tree: outside › retiring the old › version floor › backend
Repo · branch: backend · `be/X02a-version-floor-report`
Needs: BE0.10 (the floor mechanism), PL1.6 (the app's force-update state), X02b (the page people see) shipped in a version that is itself above the floor you're about to set      Unblocks: X07.0, every X07 group

Why: before an old route can go, every phone still allowed in must be on a version that doesn't need it. People on older versions are told to update instead of the app breaking.

Inputs: contract 00 §2 (`update_required`), §5 (`/v2/meta`); BE0.10 (`MIN_APP_VERSION`, `REQUIRE_APP_VERSION`).

Spec:
- `scripts/version-report.ts` reads the door and old-route access logs (BE0.1's log lines carry `X-App-Version` and the path template) and prints, per day for the last 30 days, the count of **distinct users** per app version, per route group (old groups listed in X07). Counts and versions only, no ids in the output.
- `docs/team/runbooks/version-floor.md` (new runbook, written in this PR) covers:
  1. read the report
  2. pick the floor: the oldest version still used by any active user in 14 days, *unless* it calls a route group being retired
  3. founder's yes
  4. set `MIN_APP_VERSION` on Render, then `REQUIRE_APP_VERSION=true` (the old app sends no header today; turning this on cuts off every pre-PL1.1 build)
  5. watch `update_required` counts for 48 hours
- **Rollback:** lower `MIN_APP_VERSION`, or set `REQUIRE_APP_VERSION=false`. Both are env changes, effective on restart, and data is untouched.
- **Safe order:** the floor is never raised above a version that hasn't been on TestFlight or the App Store for 14 days, and never before X02b's force-update page is in the build at the floor.

Tests: `the report counts distinct users per version and route group` (fixture log) · `the report prints no user ids`.

Proof: a report from local staging; the runbook.

Watch out: TestFlight testers update on their own, App Store users don't. Read the report before every raise.

---

### X07.0 · Route tombstones and usage counters                            size: S
Place in the tree: outside › retiring the old › old routes › tombstones
Repo · branch: backend · `be/X07.0-route-tombstones`
Needs: BE0.1      Unblocks: X07a–X07g

Why: an old route can be switched off for two weeks first and switched back on in a minute if anything breaks. Only then is its code deleted.

Spec:
- Middleware `retiredRoutes`, mounted before the old routers in `index.ts`:
  - `RETIRED_ROUTE_GROUPS` (comma list: `claude`, `pipeline`, `goals-extract`, `podcasts-sync`, `auth-v1`, `graph-feedback`, `content-v1`, `goals-v1`, `profile-v1`) → 410 `{ success:false, error:{ code:'gone', message:'This version of Retrospect is too old. Update it from the App Store.' } }`
  - adds `gone` (410) to contract 00's error list. **Change requested to contract 00** (report).
- Every old-route hit, tombstoned or not, increments a per-group daily counter (in memory, flushed to the log line `oldRouteHit group=… version=…`). X02a's report reads these.

Tests: `a tombstoned group answers 410 gone` · `turning the switch off restores the route` · `a /v2 path is never tombstoned` · `hits are counted per group and version without user content`.

Proof: test output.

---

### X07a–X07g · Remove the old route groups                                 size: S each (one PR per group)
Place in the tree: outside › retiring the old › old routes › <group>
Repo · branch: backend (+ agent where named) · `be/X07<x>-retire-<group>`
Needs (every group): X07.0, X02a's floor above the last version that calls it, the group tombstoned for 14 days with zero hits from versions at or above the floor (X02a's report pasted in the PR), and the integrator's go.

Why: the backend only runs code the app uses, so there's less to break, less to secure and less to pay for.

| Byte | Group | Removed | Last app caller | Extra needs | Rollback |
|---|---|---|---|---|---|
| X07a | `claude` | `POST /claude/generate` (open model proxy), `routes/claude.ts`, `claude-guard.ts` if unused | `ClaudeService`, `AIServiceManager` | X05a | revert + deploy |
| X07b | `pipeline` | `/pipeline/observations*`, `/pipeline/insights*`, `/pipeline/run`, `/pipeline/runs` | `GET /pipeline/insights` (`RetrospectAPIClient.swift:502-507`) | X05a, the you area's YO-x on doors | revert + deploy |
| X07c | `goals-extract` | `POST /goals/extract`, `/extract-and-save`, `/synthesize` | `RetrospectAPIClient.swift:386-419` | G4 shipped (X10d) | revert + deploy |
| X07d | `podcasts-sync` | `POST /podcasts/generate` (synchronous), old `GET /podcasts`, `/latest`, `/:id` (`select('*')`). **Agent:** stop writing `audio_url` (phase-a BEA.7 note) | old podcasts screens | G3 shipped (X10c), BE2.5b's job path in use | revert + deploy; the agent change is a separate PR, reverted on its own |
| X07e | `auth-v1` | `POST /auth/signin`, `/auth/refresh`, `/auth/dev/test-user` (prod), and the 30-day JWT shape in `authMiddleware` (phase-0 BE0.4 kept both shapes "until X07") | pre-PL1.4 builds | the floor above every pre-PL1.4 build; **all old 30-day tokens have expired** (30 days after the floor) | revert + deploy; anyone affected signs in again |
| X07f | `graph-feedback` | `POST /graph/assertions/:id/feedback`, `/graph/entity-resolution-candidates*` if no new caller | old you screens | G5 (X10e); BE1.7 corrections in use (phase-1 note) | revert + deploy |
| X07g | `content-v1`, `goals-v1`, `profile-v1` | old `/content` GET/reprocess/DELETE, `/goals` CRUD, `/profile*`, each **only when** a `/v2` door replaces every use (listed in the PR). `POST /content` stays while any integration path posts to it | old screens per flow | G1–G6 as applicable | revert + deploy |

What stays (not old, or not replaced yet): `/integrations/*` and `/speech/synthesize` (the speech proxy) stay until a contract replaces them, `/health`, `/admin` (hardened elsewhere), and `/public/*`.

Tests (each PR):
- `the removed paths answer 404`
- `the route list after removal equals the list before minus the group` (snapshot of `app._router.stack` paths)
- `no import of the removed module remains` (a grep test)

Proof: X02a's report (14 days of zero hits from supported versions); test output; the deploy is the founder's yes.

Watch out: removing a group can orphan helpers. Delete them in the same PR only if nothing else imports them, and say so in the PR body.

---

### X07h · Episode audio goes private                                       size: S (an ops step, done by the integrator with the founder)
Place in the tree: outside › retiring the old › old routes › private audio
Repo: Supabase (production) · runbook PR `be/X07h-private-audio-runbook`
Needs: X07d, BEA.7 (signed URLs in use)      Unblocks: X09

Why: nobody can ever play your episode from a leaked link.

Spec:
- The runbook: confirm no reads of `podcast_episodes.audio_url` for 14 days (X07.0 counters on the old podcasts group). Then switch the bucket to private, and null `audio_url` in a migration only after a backup the founder confirms.
- **Rollback:** switch the bucket back to public (instant). The URLs were kept until the migration.

---

### X08a · Brain: stop writing and reading the legacy tables               size: M
Place in the tree: outside › retiring the old › legacy brain tables › disconnect
Repo · branch: Retrospect-agent · `agent/X08a-disconnect-legacy`
Needs: X07b (nobody calls the insight routes), BE2.1's finding that nothing in v2 reads Cook 0 `user_understanding` (later-phases note)      Unblocks: X08b

Why: the brain stops spending effort on an old way of thinking that nothing shows any more.

Inputs: code anchors that touch `observations`, `insights`, `insight_units`, `identity_inferences`, `user_understanding` (21 Oct grep):
- `src/pipelines/legacy-writes.ts`, `legacy-shim.ts`, `ingest.ts`, `after-reading.ts`, `integration-evidence.ts`, `trace.ts`, `podcast.ts`
- `src/agents/cook0-agent.ts`, `agents/tools/search-insights.ts`, `routes/cook0.ts`, `routes/onboarding.ts` (interpret)
- `routes/notifications.ts` (reads observations and insights for 7 days)
- `routes/runs.ts`, `public/runs-dashboard.html`, `brain/lint.ts`

Spec:
- Remove `writeLegacyOutputs` and its call (facts mode already writes nothing).
- Remove the Cook 0 route and agent, and `search-insights`.
- `POST /notifications/generate`: remove it. BE7.8a replaces it for every push, including BE4.3's check-ins.
- Dashboards count only live tables.
- **A grep test:** no file under `src/` references the five table names except `db/tables.ts`. Those entries are removed in X08c.

Tests: `ingest writes nothing to legacy tables` · `no source file names a legacy table` (grep) · the existing suites stay green.

Rollback: revert the PR. The tables are untouched.

Watch out: `goal_candidates` is **not** legacy: onboarding goals use it (agent-api §6.2). Leave it.

---

### X08b · Brain: back up and set the legacy tables aside                   size: S (migration + founder step)
Place in the tree: outside › retiring the old › legacy brain tables › set aside
Repo · branch: Retrospect-agent · `agent/X08b-retire-legacy-tables`
Needs: X08a deployed for 14 days with zero writes (the row counts don't change), and a production backup the founder confirms      Unblocks: X08c

Spec:
- Migration `1NN_retire_legacy_tables.sql`: `alter table … rename to _retired_<name>` for `observations`, `insights`, `insight_units`, `identity_inferences`, `user_understanding`.
- FKs keep `on delete cascade` from `users`, so account deletion still removes these rows.
- Revoke `service_role` grants on them.

Rollback: the reverse migration (rename back, re-grant), written and tested in the same PR.

Tests: `the migration and its reverse both apply on PGlite` · `deleting a user still removes their retired rows`.

---

### X08c · Brain: drop the legacy tables                                   size: S
Needs: X08b live 30 days with no errors mentioning `_retired_` in the agent's logs, and the founder's yes. Spec: a migration dropping the five `_retired_*` tables, and their `db/tables.ts` entries removed. Rollback: restore from the X08b backup (the only way back; that's why X08b waits 30 days).
