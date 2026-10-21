# Contract 03 · Podcasts

The weekly episode, end to end: PC-1 (the podcasts tab: this week's episode, earlier episodes and briefs), PC-2 (the player in episode mode: loose chapters, the transcript, the "…" menu, a guess arriving), PC-3 (why this is here: one claim, stated or asked, with the moments Retro says it and what it rests on), episode feedback, the weekly "episode ready" push, signed private audio and offline copies. Built on contract 00; reuses contract 02's `Brief`, `Guess`, `SourceRef` and corrections. Status: **draft for the founder's review**. Every agent field below was read from the agent's code at `a886060` (21 Oct); where the agent can't give what the screen needs, the byte that adds it is named (cards in `../flows/podcasts/backend.md`).

**The founder's weight:** the weekly episode is Retrospect's top output. This contract is written so the episode is never wrong about the person, never silent about where a claim came from, and never lost offline.

## 0. What the brain has today, and what it must add

| Screen need | Today (agent `a886060`) | Added by |
|---|---|---|
| A list of episodes without the 3,072-float embedding and full script | `GET /podcasts/:userId` is `select('*')`, 50 rows (agent-api §7.2) | BE3.4a (projected library route) |
| One episode with its words split into lines and chapters | only `script` (paragraphs joined by `\n\n`); the written sections (id, register, kept sentences) are computed in `writeEpisode` and **thrown away** (`podcast-v2.ts` stores only `script` and `outline.plan`) | BE3.0a (store the sections and chapter titles) |
| Chapter start times and a real duration | none anywhere; `duration_seconds` is words/150 (§7.3) | BE3.0b (audio per chapter, measured) |
| Line start times (the transcript follows the spoken line) | none | BE3.0c (line times inside measured chapters) |
| Which claim a part makes, stated or asked, and what it rests on | the plan has `register` and `evidence` ids per item; `walkEvidence` has no user filter (§9.4) | BEA.2 (scoping), BE3.1a (claim route), BE3.1b (door) |
| Private audio | public, permanent URL with the user id in the path (§7.3) | BEA.7 (Beta 1), used by BE3.5 |
| Feedback that changes the next episode | `POST /feedback/episodes/:id` doesn't check ownership, isn't idempotent; **the v2 writer never reads feedback text** (only appetite reads ratings) | BEA.2, BE3.2a, BE3.2b |
| A weekly episode made in the person's own week, and a push when it's ready | one cron, Sundays 06:00 UTC, synchronous, legacy path unless `EPISODE_PLANNER=v2` | BE2.5a (job runner), BE3.3a (local-time schedule), BE3.3b (push), founder Q-16 (v2 for everyone) |
| An old brief, by id, with its audio (PC-1 shows briefs as squares) | contract 02 lists briefs without audio and has no "one brief" door | BE3.6 |

## 1. Shared types

```ts
// Reused from contract 02: SourceRef, Brief, Guess. Not redefined here.

type EpisodeKind = "weekly" | "first" | "onDemand" | "unknown";   // agent generation_type is always 'weekly' today; BE2.5a fixes it

type EpisodeSummary = {
  id: string;                         // podcast_episodes.id
  kind: EpisodeKind;
  number?: number;                    // episode_number; omitted when unknown (legacy rows can repeat it: §7.3 "racy")
  title: string;                      // lowercase is the writer's job, not the app's; the app never re-cases content
  about?: string;                     // what it's about: up to three chapter titles ("mornings, the standup, sleep", Paper PC-1 1FUM-0); omitted for legacy episodes
  durationSeconds: number;            // measured when timing == "measured", else the words/150 estimate
  timing: "measured" | "estimated" | "unknown";
  createdAt: string;                  // ISO 8601 UTC, ms
  coversFrom?: string;                // YYYY-MM-DD, user's zone
  coversTo?: string;
  hasAudio: boolean;                  // false when synthesis failed or was skipped: the episode reads as text
};

type BriefSummary = {                 // a past brief, as a square on PC-1
  id: string;                         // daily_briefs.id
  date: string;                       // YYYY-MM-DD
  title: string;                      // the brief's first part, cut at the first sentence end (≤ 80 chars), by the door. PC-1 squares title briefs by day ("today's brief", "monday's brief", Paper 1FUH-0) and use this only as the VoiceOver hint
  durationSeconds?: number;           // when audio exists
  hasAudio: boolean;
};

type LibraryItem =
  | { kind: "episode"; episode: EpisodeSummary }
  | { kind: "brief"; brief: BriefSummary }
  | { kind: "unknown" };              // the app skips it and logs a count

type Upcoming =
  | { state: "making"; readyAt?: string }                       // a weekly or first job is queued or running; readyAt = the delivery time (ISO)
  | { state: "quietWeek"; line: string; nextAt?: string }       // this week's job ended quiet_week or nothing_safe_to_say; shown for 7 days
  | { state: "none" }
  | { state: "unknown" };
```

`about` is built by the door, not a model: the titles of the first three chapters joined with ", ". Copy (lowercase, the voice) is the writer's.

## 2. PC-1 · the library

`GET /v2/podcasts?cursor=<opaque>&limit=20`
```json
{
  "hero": { "id": "…", "kind": "weekly", "number": 6, "title": "the week the plan met the calendar", "about": "the standup, sunday walks", "durationSeconds": 612.4, "timing": "measured", "createdAt": "2026-10-18T16:00:02.114Z", "coversFrom": "2026-09-20", "coversTo": "2026-10-18", "hasAudio": true },
  "upcoming": { "state": "none" },
  "items": [ { "kind": "brief", "brief": { "id": "…", "date": "2026-10-20", "title": "a quieter monday than usual", "durationSeconds": 248.0, "hasAudio": true } }, { "kind": "episode", "episode": { … } } ],
  "nextCursor": "…"
}
```
- `hero` is the newest **ready** episode (any age), or `null` when there is none yet. It is never repeated in `items`.
- `items` holds every other ready episode and every brief, newest first by `createdAt`, merged by the door. Briefs with `kind: "quiet"` are not listed (nothing to play). `limit` ≤ 50. The cursor is opaque (base64 of `createdAt`, `kind`, `id`), and paging never repeats or skips an item when two share a timestamp.
- `upcoming` comes only on the first page (no cursor). `quietWeek.line` is the brain's quiet line (founder copy; today's agent string for briefs is "nothing new since your last brief. i'll keep listening."; the episode line is founder Q-3).
- PC-1 labels everything below the hero "earlier" (Paper `1FUJ-0`); there is no "since" header, so the library carries no start date.
- Empty (day one, nothing made): `{ "hero": null, "upcoming": { "state": "none" }, "items": [], "nextCursor": null }`; with a first-run job running, `upcoming.state` is `making`.
- **Only `ready` episodes** are listed (`generating` and `failed` rows never appear). Columns are named, never `select('*')`.
- Bucket `read`. Cached by the app (`CachedRead` key `podcasts.library`, 5 min).

## 3. PC-2 · one episode

`GET /v2/episodes/:id`
```ts
type Episode = EpisodeSummary & {
  madeFrom: Array<{ kind: SourceKind; count: number }>;   // the why line: "from 6 entries · calendar · steps"; empty → no why line
  chapters: Chapter[];                // [] for legacy and estimated-only episodes ("when uncertain, withhold": no fake ticks)
  lines: Line[];                      // the transcript; [] → the app shows `description` in its place
  description?: string;               // the agent's one-line description, used only when lines is empty
  claims: ClaimSummary[];             // one per stated or asked part; [] for legacy
  audio?: { url: string; expiresAt: string; durationSeconds: number; bytes?: number; mimeType: "audio/mpeg" };   // signed, private, 1 hour (BEA.7)
  feedback?: { verdict: FeedbackVerdict | null; at: string };    // the person's last feedback on this episode, if any
};

type Chapter = { index: number; title: string; startSeconds: number; claimId?: string };   // title lowercase, ≤ 40 chars
type Line = {
  index: number;
  text: string;                       // one spoken sentence, exactly as voiced
  chapterIndex: number;               // -1 when there are no chapters
  startSeconds?: number;              // present when timing is "measured"; absent → the app follows by chapter only, or not at all
  register: "stated" | "asked" | "craft";   // craft = a sentence that makes no claim about the person (writer's "craft" id)
  claimId?: string;                   // the claim this sentence belongs to (absent on craft)
};
type ClaimSummary = {
  id: string;                         // UUIDv5(episodeId, planItemId): stable, opaque
  kind: "pattern" | "answer" | "why" | "hypothesis" | "shift" | "goal" | "content" | "unknown";
  register: "stated" | "asked";
  chapterIndex: number;
  guessId?: string;                   // kind == hypothesis: the contract 02 Guess id, answerable with POST /v2/guesses/:id
};
type SourceKind = "entries" | "voice" | "calendar" | "health" | "steps" | "sleep" | "saved" | "watched" | "listened" | "mail" | "unknown";
type FeedbackVerdict = "more" | "less";
```
- **Mapping from the agent** (BE3.0a stores `podcast_episodes.sections`): each written section → its kept sentences become `lines` in spoken order; a section's plan item → one `ClaimSummary` (craft sections make none); consecutive sections that belong to one chapter (BE3.0a) share `chapterIndex`. The `why:<id>` and `hypothesis:<id>` sections are `register: "asked"`; a hypothesis carries `guessId`.
- **Legacy episodes** (`outline.planner` absent, or v2 episodes made before BE3.0a): `lines` = the script split on blank lines then sentences, `register: "craft"`, no `claimId`, `chapters: []`, `claims: []`, `timing: "estimated"`. The app plays them and shows the words; no chapter ticks, no PC-3.
- **Timing:** `timing: "measured"` only when BE3.0b measured each chapter's audio. Line times inside a chapter are spread by character count between the chapter's measured start and end (BE3.0c); the app treats them as approximate (it follows lines, never shows per-line times).
- **Audio** is absent when `hasAudio` is false. `expiresAt` is 1 hour after the response. The app re-fetches the episode to renew a link (§8).
- `madeFrom` counts the distinct sources behind the episode's claims, grouped by kind, kinds with zero omitted, most first; the app shows at most three kinds.
- Bucket `read`. Ownership: `podcast_episodes.user_id`, else `not_found`.

## 4. PC-3 · one claim: stated or asked, where Retro says it, what it rests on

`GET /v2/episodes/:id/claims/:claimId?cursor=&limit=20`
```ts
type Claim = {
  id: string;
  kind: ClaimSummary["kind"];
  register: "stated" | "asked";
  text: string;                       // the claim in plain words, built in code from the plan item's facts (never a model): "you write on tuesday mornings"
  basis: "did" | "said" | "both" | "unknown";   // from the evidence kinds: own words only → said; records only → did
  sureness?: "just a hunch" | "fairly sure" | "very sure";   // contract 02's words and thresholds; on stated AND asked claims (Paper PC-3 1FZ7-0 "asked · fairly sure · rests on 3 mornings"); absent for shift and content, and when the brain has no confidence
  guess?: Guess;                      // contract 02 shape, when kind == hypothesis (the asked card's "that's right / not quite")
  moments: Array<{ episodeId: string; episodeTitle: string; startSeconds?: number; quote: string; inThisEpisode: boolean }>;   // where Retro says it; this episode first, then up to 2 earlier ones
  evidence: { rows: EvidenceRow[]; total: number; nextCursor: string | null };
  correct?: { kind: "fact" | "answer" | "pattern"; id: string };   // contract 02 §6 `about`, when "not right" can target this claim directly
};
type EvidenceRow = {
  kind: SourceKind;
  id: string;                         // raw_content.id or source_items.id
  date: string;                       // YYYY-MM-DD
  excerpt: string;                    // one line: the person's own words for entries; a plain record line otherwise ("team standup · 30 min")
  opens?: SourceRef;                  // present when a page can open it: entries → JR-4 now; records → YO-3 once phase 5 ships
};
```
- `text` comes from `factLines`-style pure functions in the agent (one per kind), lowercase, ≤ 140 chars. A `stated` claim renders as Paper's stated claim; an `asked` claim as the dashed asked card (C28 family). **An asked claim's text is always a question** ("could the late nights be about having too little left?"), and the door refuses to return an asked claim whose text doesn't end with "?" (logged, `not_found`): guesses are never asserted.
- **Evidence** walks backward from the claim (`walkEvidence`, scoped by BEA.2) to `raw_content` and `source_items`; kinds come from `content_type` / provider. Excerpts are the person's own words, shown only to them, **never logged**. `total` is the full count ("from 6 things"); rows page by 20.
- `moments.quote` is the first kept sentence of the claim's section in that episode; `startSeconds` present when measured. Earlier episodes are found by the same plan item id in their stored sections (BE3.0a), newest first, at most two.
- `correct` is present for claims of kind `pattern`, `answer` (and facts once exposed); absent for `shift`, `goal`, `content`, `why` and `hypothesis` ("not right" then sends free text with no `about`, contract 02 §6). PC-3 shows "not right" for every claim, stated or asked (Paper `1FXU-0`); a hypothesis's yes / not quite happens where it arrives in the transcript, through `guess`.
- Bucket `read`. Ownership: the episode's `user_id`, and the claim must be in that episode's sections, else `not_found`.

## 5. Episode feedback

`POST /v2/episodes/:id/feedback` — idempotent (`Idempotency-Key: <clientFeedbackId>`)
```json
{ "clientFeedbackId": "<uuid>", "verdict": "more", "text": "the bit about sunday walks was spot on", "given": "typed" }
```
- `verdict` optional (`more | less`); `text` optional, 1–2,000 chars trimmed; at least one of them. `given`: `tap | typed | voice` (agent `source`: tap → tap, typed → manual, voice → voice).
- → `{ "feedback": { "id": "<uuid>", "verdict": "more", "createdAt": "…" } }` (201; a replay returns 200 with the same row; same key with a different body → `idempotency_mismatch`).
- Stored in `episode_feedback` with `metadata { client_feedback_id, verdict }`; `rating` stays null until the founder agrees how a verdict maps to a rating (appetite reads ratings ≤ 2 as discomfort: a "less like this" isn't necessarily discomfort; founder Q-2b). `text` goes into the next episode's writing through BE3.2a.
- Sent through the app's outbox (works offline, sent once). Bucket `write`. The text is never logged.

## 6. A past brief, by id

`GET /v2/briefs/:id` → `{ "brief": Brief }` (contract 02 §3 shape, **with** `audio` when ready). Used when a brief square on PC-1 is opened; the player opens in brief mode (C23b). Bucket `read`; ownership `daily_briefs.user_id`. Contract 02 is unchanged; this door is listed here because only PC-1 needs it.

## 7. Episode jobs (shared with contract 01)

First run (ON-10) creates the first episode as a job; podcasts only reads job state through `upcoming`. The shapes live here so both contracts use one definition.
```ts
type EpisodeJob = {
  id: string;
  kind: "first" | "weekly" | "onDemand" | "unknown";
  state: "queued" | "running" | "made" | "quietWeek" | "nothingSafeToSay" | "failed" | "unknown";
  stage?: "reading" | "writing" | "voicing" | "unknown";
  episodeId?: string;                 // when made
  readyAt?: string;                   // the delivery time the person was told
  createdAt: string;
  finishedAt?: string;
};
```
`POST /v2/episodes/jobs { "kind": "first" }` (idempotent per user and kind while one is open: returns the open job) → `{ job }`; `GET /v2/episodes/jobs/:id` → `{ job }`. Bucket `expensive` for create (spend cap: `spend_limited`), `read` for status. Built in BE2.5b (first run).

## 8. Signed audio and offline copies

- Every audio link is a **signed URL to a private object**, valid 1 hour (BEA.7). Nothing in the app persists a link as playable after `expiresAt`.
- **Streaming:** the app hands the player a link valid for at least the remaining duration ÷ rate + 5 minutes; otherwise it re-fetches `GET /v2/episodes/:id` first. A link that expires mid-play (a long pause) is renewed and the player resumes at the same position (PL3.4c).
- **Offline copies** (founder Q-1, lean A): the newest weekly episode downloads itself on Wi-Fi when it appears; any other episode can be downloaded from the "…" menu. Copies live on the phone only, excluded from backup, and are deleted on sign-out and when the server says an episode is gone (`not_found`).
- The server never sees whether something was downloaded. No new door.

## 9. The weekly push (shared with contract 07)

When a weekly job ends `made`, the backend sends one content-free push at the person's delivery time (BE3.3b):
```json
{ "aps": { "alert": { "body": "this week's episode is here." }, "sound": "default", "thread-id": "episodes", "category": "episode.ready" },
  "kind": "episodeReady", "episodeId": "<uuid>", "path": "/podcasts/episodes/<uuid>" }
```
- The title of the episode never passes through Apple. `apns-collapse-id` = `episode-<episodeId>`; `apns-expiration` = 48 hours.
- Delivery: never between 21:00 and 08:00 in the person's zone (EX-3: never at night); at most one push a day across all kinds (contract 07 owns the daily cap).
- `quietWeek` sends nothing (founder Q-3, lean). `failed` sends nothing; the failure is logged as a count.
- Tap → `/podcasts/episodes/<id>` → PC-2 for that episode, paused at the start (or where it was).
- Deep links (contract 07 lists them): `retrospect://podcasts`, `retrospect://podcasts/episodes/<id>`, `retrospect://podcasts/episodes/<id>?at=<seconds>`, `retrospect://podcasts/episodes/<id>/claims/<claimId>`.

## 10. Errors

Contract 00 §2's envelope and codes. Per door:

| Door | Codes it can return |
|---|---|
| `GET /v2/podcasts` | `invalid_request` (bad cursor or limit), `unauthenticated`, `invite_required`, `rate_limited`, `upstream_timeout`, `upstream_unavailable`, `internal` |
| `GET /v2/episodes/:id` | the above + `not_found` |
| `GET /v2/episodes/:id/claims/:claimId` | the above + `not_found` |
| `POST /v2/episodes/:id/feedback` | the above + `not_found`, `idempotency_mismatch` |
| `GET /v2/briefs/:id` | as `GET /v2/episodes/:id` |

None of these doors calls a model, so none returns `spend_limited` (job creation does, §7).

## 11. Limits and timeouts

| Door | Bucket | Agent call | Timeout | Retry |
|---|---|---|---|---|
| library | `read` | `GET /podcasts/:userId/library` + `GET /briefs/:userId/history` | 10 s | `read` |
| episode | `read` | `GET /podcasts/:userId/:episodeId` | 10 s | `read` |
| claim | `read` | `GET /podcasts/:userId/:episodeId/claims/:claimId` | 10 s | `read` |
| feedback | `write` | `POST /feedback/episodes/:episodeId` | 10 s | none (the door's idempotency covers a client retry) |
| brief by id | `read` | `GET /briefs/:userId/:briefId` | 10 s | `read` |

## 12. Decisions the founder makes for this contract

Full options and what changes under each are in `../flows/podcasts/README.md` §8. The plan proceeds on the lean.

1. **Offline copies** (§8): lean A, the newest weekly episode downloads itself on Wi-Fi, any other by hand.
2. **Feedback** (§5): lean A, "more like this / less like this" at the end, plus "say more" in your own words; (b) how a verdict maps to a rating: lean, it doesn't until you decide.
3. **A quiet week** (§2, §9): lean, no push; one line in the podcasts tab with the next date.
4. **The weekly time**: lean, Sunday 9:00 in your own time zone.
5. **Past briefs in the podcasts tab** (§2, §6): lean yes, as Paper draws them.
6. **The "…" menu**: lean chapters ›, download / remove download, as Paper draws (AirPlay stays in Control Center).
7. **Reaching "why this is here" while playing**: lean, long-press a line → "why this is here ›" · "correct this part".
8. ~~Asked claims that aren't guesses~~: settled by Paper (PC-3 shows every claim with "not right"; guesses are answered in the transcript).
18. **The line after the spoken one**: Paper draws it `text.secondary`; player.md (21 Oct) says every other line is `text.tertiary`. Lean: Paper.
9. **Old episodes made on the phone by the old app**: lean, carried over as "made on this phone".
16. **The new episode writer (v2) for everyone** (`EPISODE_PLANNER=v2`): lean, at the podcasts ship gate (G3); chapters and "why this is here" exist only for v2 episodes.

## 13. Fixtures

`fixtures/03/`: `podcasts.library.json`, `podcasts.library.empty.json`, `podcasts.library.making.json`, `podcasts.library.quiet.json`, `podcasts.library.page2.json`, `episode.v2.json`, `episode.legacy.json`, `episode.noaudio.json`, `claim.stated.json`, `claim.asked.hypothesis.json`, `claim.asked.why.json`, `feedback.request.json`, `feedback.response.json`, `brief.byid.json`, `job.running.json`, `job.made.json`, `job.quiet.json`, `push.episode-ready.json`, and `error.*.json` for `invalid_request`, `unauthenticated`, `invite_required`, `not_found`, `idempotency_mismatch`, `rate_limited`, `upstream_timeout`, `upstream_unavailable`, `internal`. Content is invented (sam, priya; plain made-up lines), never anyone's data.
