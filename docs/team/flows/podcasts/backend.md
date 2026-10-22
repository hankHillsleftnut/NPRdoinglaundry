# Podcasts · backend cards (brain bytes and doors)

The backend engineer's cards for the podcasts area, every one in full byte-card form. Contract: [../../contracts/03-podcasts.md](../../contracts/03-podcasts.md). Every door is built with the kit (BE0.1), passes the door suite (BE0.2) and the invite gate (BE0.12). Every agent route gets a two-user PGlite test, and every agent query that touches SQL runs as `service_role` (testing.md layer 2). Fixtures: the backend validates every `fixtures/03/*.json` response against the door's zod output schema (layer 4).

**Tree:** podcasts › the episode itself (BE3.0a sections and chapters · BE3.0b audio per chapter · BE3.0c line times) › the library (BE3.4a agent route · BE3.4b door · BE3.6 a past brief) › one episode (BE3.5) › why this is here (BE3.1a agent route · BE3.1b door) › feedback (BE3.2a brain · BE3.2b door) › the weekly episode (BE3.3a local-time schedule · BE3.3b push) › retiring the old (BE3.8 old route on private audio).

**Order** (two at most in review at once): BE3.0a → BE3.4a → BE3.4b → BE3.5 → BE3.6 → BE3.0b → BE3.0c → BE3.1a → BE3.1b → BE3.2a → BE3.2b → BE3.3a → BE3.3b → BE3.8.

**Needs from other areas, merged first:** BEA.2 (scoping), BEA.4 (spend ledger), BEA.7 (private audio, Beta 1), BEA.8 (quiet weeks), BE1.3b (the per-part synthesis and measuring helper), BE2.5a (the job runner, first run), BE2.6 + BE2.7 (devices and the push sender, first run), BE0.1/BE0.2/BE0.12.

**Migration numbers** (phase-0.md assigns them; these need the integrator's go): agent `157_episode_chapters.sql` (already reserved for BE3.0), **`158_episode_feedback_keys.sql`** (BE3.2a) and **`159_weekly_delivery.sql`** (BE3.3a) are requests; backend **`013_push_sends.sql`** (BE3.3b) is a request.

---

### BE3.0a · Keep what the episode actually says: sections and chapter titles   size: M
Place in the tree: podcasts › the episode itself › sections and chapters (agent)
Repo · branch: retrospect-agent · `agent/BE3.0a-episode-sections`
Needs: BEA.8 (the v2 pipeline returns outcomes, not throws)      Unblocks: BE3.0b, BE3.0c, BE3.1a, BE3.5, M09 ticks, C23e.2

Why: the transcript you read is exactly what Retro said, split into its sentences, and each topic is a chapter you can jump to (founder D14: loose chapters, one per topic as the narrator moves on).

Inputs:
- Contract: 03 §0, §3 (`Chapter`, `Line`, `ClaimSummary`)
- Reference: agent-api-reference §7.1 (v2 response drops `v2`), §7.3 (no chapters anywhere; `outline` holds `{ planner, style, plan }`)
- Code anchors: `src/writer/write-episode.ts` (`WrittenEpisode.sections[]` with `id`, `register`, `kept`, `cut`; `outlineFromPlan`; section ids `pattern:<id>`, `answer:<id>`, `shift:<d>:<m>`, `goal:<id>`, `content:<i>`, `why:<id>`, `hypothesis:<id>`, `craft`; writer JSON `{ title, sections | sentences }`), `src/pipelines/podcast-v2.ts:63-110` (insert without sections), `src/planner/plan.ts:23-43` (`PlanItem.register`, `evidence`)

Spec:
- Migration `157_episode_chapters.sql` (house style: additive, header comment, RLS, grants): `podcast_episodes.sections jsonb not null default '[]'`, `podcast_episodes.chapters jsonb not null default '[]'`, `podcast_episodes.duration_measured boolean not null default false`, `podcast_episodes.timing_version smallint not null default 0`.
- **Sections stored** (`sections`): `[{ id, register, kind, chapterIndex, sentences: string[] }]` in spoken order, kept sentences only (cut sentences stay in the trace, never in the episode). `kind` from the plan item (`pattern|answer|shift|said_vs_did|content|why|hypothesis|craft`).
- **Chapter titles in the same writer call** (no new model call): the writer's JSON gains `"chapters": [{ "title": "<2–4 lowercase words>", "sections": ["<section id>", …] }]` in all three styles; `WRITER_SYSTEM` asks for "one chapter per topic as you move on, titled in 2–4 lowercase words, never a claim about the listener" (a chapter title is craft; it's checked by `styleIssue` and must not contain a number or a name that isn't in a section's facts: a pure validator `chapterTitleIssue(title, facts)`).
- **Fallback** when the writer returns no usable chapters: one chapter per non-craft section, titled in code from the plan item (`pattern` → its label's first 4 words; `said_vs_did` → the goal title; `shift` → the metric label; `answer` → the question's topic; `why`/`hypothesis` → "one question"); craft sections join the chapter of the next non-craft section (or the previous, at the end).
- `chapters` stored as `[{ index, title, sectionIds: string[] }]` (start times arrive with BE3.0b). Titles ≤ 40 chars, lowercase.
- Legacy runs (`runPodcast` without v2) store `sections: []`, `chapters: []`.
- The route `POST /podcasts/generate` response adds `chapters` (titles only) so local staging can check them.

Steps: migration → writer prompt + parser → validator + fallback → store → tests.

Acceptance:
- A v2 episode stores its kept sentences by section, in spoken order, and `scriptText` of the stored sections equals `script` exactly.
- Every chapter title is lowercase, 2–4 words, and passes `chapterTitleIssue`.
- A legacy episode still saves, with empty sections and chapters.
- No new model call is made (the trace's call count is unchanged).

Tests (layer 1; a fake writer and guard):
- `the stored sections join back into exactly the spoken script`
- `chapters group sections in the order they are spoken`
- `a chapter title naming a number not in the facts is replaced by the code title`
- `craft sections join the next topic's chapter`
- `a writer reply without chapters falls back to one chapter per topic`
- `the light and medium styles still produce sections and chapters`
- `a legacy run stores no sections and no chapters`
- `writing an episode makes the same number of model calls as before`

Proof in the PR: test output; a local-staging dry run's chapter titles for two test users (titles only, no script lines in the PR).

Watch out: sentences that the guard cut must never reach `sections` (they were cut for being unsupported). The medium and light styles interleave sections, so one section id can appear in two places: store each run of sentences as its own section entry with the same id and plan item, never merge non-adjacent runs.

---

### BE3.0b · Audio per chapter, measured                                    size: M
Place in the tree: podcasts › the episode itself › audio per chapter (agent)
Repo · branch: retrospect-agent · `agent/BE3.0b-chapter-audio`
Needs: BE3.0a, BE1.3b (the per-part synthesis + `music-metadata` measuring helper), BEA.4, BEA.7      Unblocks: BE3.0c, BE3.5 (`timing: measured`), C25 chapter capsules, M09

Why: the chapter ticks on the scrubber land where each topic really starts, and the episode's length is its true length.

Inputs:
- Contract: 03 §3 (`timing`, `Chapter.startSeconds`, `audio.durationSeconds`)
- Reference: phase-1-journal.md BE1.3b (concatenate per-part MP3s, measure each, cumulative starts), agent-api-reference §7.3
- Code anchors: `src/services/elevenlabs.ts` (`textToSpeech`, `V3_CHAR_LIMIT` 5,000, `chunkScript`), `src/pipelines/podcast-v2.ts:84-100` (one TTS call for the whole script, upload, `estimateDuration`)

Spec:
- Replace the single `textToSpeech(script)` with BE1.3b's shared helper `synthesizeParts(parts: string[], { persona }) → { buffer, parts: [{ startSeconds, durationSeconds }], chars }`, one part per **chapter** (the chapter's sections' sentences joined with spaces), in order. A chapter over 5,000 chars is split by `chunkScript` inside the helper and measured as one part.
- Store `chapters[i].startSeconds` and `chapters[i].endSeconds` (cumulative, measured, 0.01 s), `duration_seconds` = the measured total rounded to whole seconds (the column stays `integer` for old readers; the door reports the precise value from the last chapter's `endSeconds`), `duration_measured = true`, `timing_version = 1`.
- Upload once to the private bucket at `podcasts/<userId>/<episodeId>.mp3` (BEA.7's `audio_path`); `audio_url` stays written for old app versions until X07.
- Spend: `recordSpend(userId, 'episode_audio', chars)` once (BEA.4). Character count is unchanged by splitting (same words), so cost is unchanged.
- **Voice continuity:** pass each chunk's neighbouring text as context if the ElevenLabs model supports it for `eleven_v3` (`previous_text` / `next_text`); if it doesn't, record the finding and measure on local staging whether chapter joins are audible (founder listens to one A/B pair before merge).
- Failure of any part: no audio (`audio_status`-style: `audio_path` null, `duration_measured` false), the episode saves as text (`hasAudio: false`), logged as a count.

Steps: swap in the helper → store starts and duration → upload → A/B join check on staging → tests.

Acceptance:
- Each chapter's `startSeconds` equals the sum of the measured durations before it (± 0.05 s).
- The episode's duration is the measured total, not words/150.
- Splitting into chapters costs the same characters as one call.
- A failed chapter leaves a readable episode with no audio.

Tests (layer 1; fixture MP3s of known lengths, a fake TTS):
- `each chapter starts where the previous chapters' real audio ends`
- `the stored duration is the measured total`
- `a chapter over the character limit is chunked and measured as one part`
- `a failed chapter keeps the episode as text with no audio`
- `episode audio spend is recorded once with the same character count`
- `a dry run synthesises nothing`

Proof in the PR: test output; on local staging, one episode's measured chapter starts next to its estimate (numbers only) and the founder's yes on the A/B join recording.

Watch out: voice is about 60% of per-user cost: never synthesise on a dry run or for staging test users unless the test asks. MP3 frames from one encoder concatenate cleanly; don't re-encode. If joins are audible and the founder says no, the fallback is one synthesis call plus ElevenLabs' timestamp endpoint for chapter starts (a new card, not a hack here).

---

### BE3.0c · Line times inside chapters, and legacy episodes as plain text   size: S
Place in the tree: podcasts › the episode itself › line times (agent)
Repo · branch: retrospect-agent · `agent/BE3.0c-line-times`
Needs: BE3.0b      Unblocks: BE3.5 (`lines[].startSeconds`), C23e.2 (the transcript follows the spoken line)

Why: the transcript keeps the line being spoken in the clear middle, line by line, not just chapter by chapter.

Inputs: contract 03 §3 (`Line.startSeconds` approximate; the app never shows per-line times); C23b's follow rules (`transcriptFollow` 420)

Spec:
- A pure function `lineTimes(chapter: { startSeconds, endSeconds, sentences: string[] }) → number[]`: each sentence's start = chapter start + (chapter length × characters before it ÷ chapter characters), with a 0.25 s floor between lines. Computed when the agent route builds an episode (not stored: it's cheap and stays consistent if the rule changes).
- `splitLegacyScript(script) → string[]`: paragraphs on blank lines, then sentences (`(?<=[.!?])\s+(?=[A-Z"'])`), for episodes without sections; their lines carry no times.
- Exported for BE3.5's mapping.

Acceptance: line starts are increasing, the first equals the chapter start, the last is before the chapter end; a legacy script splits into readable sentences.

Tests (layer 1): `line starts grow with the characters before them` · `the first line starts at the chapter start` · `no two lines start less than a quarter second apart` · `a legacy script splits into paragraphs then sentences` · `an abbreviation like "dr. lee" doesn't split a sentence` (the splitter keeps a short list of abbreviations).

Proof in the PR: test output.

Watch out: never present these as exact: the contract calls them approximate, and the app follows by them without showing them.

---

### BE3.4a · The library route: episodes without the heavy columns          size: S
Place in the tree: podcasts › PC-1 › library (agent)
Repo · branch: retrospect-agent · `agent/BE3.4a-podcast-library`
Needs: BEA.2      Unblocks: BE3.4b

Why: the podcasts tab opens fast: today's list ships every episode's 3,072-float embedding and full script.

Inputs: agent-api-reference §7.2 (`select('*')`, limit 50, no status filter); contract 03 §1, §2

Spec:
- `GET /podcasts/:userId/library?before=<createdAt>&limit=20` → `{ episodes: [{ id, title, generation_type, episode_number, duration_seconds, duration_measured, created_at, covers_period_start, covers_period_end, has_audio, chapter_titles: string[] }] }`: named columns only, `status = 'ready'`, `user_id` filter, newest first, `limit` ≤ 50. `has_audio` = `audio_path is not null` (BEA.7). `chapter_titles` = the first three `chapters[].title`.
- `GET /podcasts/:userId` (the old route) stays as it is until X07.
- Keyset paging on `(created_at, id)`.

Tests (layer 1 + 2): `the library never returns the script or the embedding` · `only ready episodes are listed` · `paging never repeats an episode with the same timestamp` · `another person's episodes are never listed` (two users) · `runs as service_role`.

Proof in the PR: test output; response size for 20 episodes on staging before and after (bytes only).

Watch out: `summary_embedding` is a `vector(3072)`; any `*` or forgotten projection brings it back. Add a test that fails if the selected column list contains `summary_embedding`, `script` or `outline`.

---

### BE3.4b · The library door: `GET /v2/podcasts`                           size: M
Place in the tree: podcasts › PC-1 › library (door)
Repo · branch: backend · `be/BE3.4b-library`
Needs: BE3.4a, BE1.3 (brief history route), BE2.5a (job state for `upcoming`), BE0.1, BE0.2      Unblocks: PL3.4a, P13 on live data

Why: your podcasts tab shows this week's episode first, then everything earlier, briefs and episodes together, with an honest line when the next one is being made or the week was quiet.

Inputs: contract 03 §1, §2, §10, §11; fixtures `podcasts.library*.json`

Spec:
- Query (zod): `cursor` optional opaque string (base64 of `createdAt|kind|id`, validated after decode); `limit` 1–50, default 20.
- First page: call the library route (limit + 1) and brief history (limit), merge newest first by `createdAt` (ties: episode before brief, then id), take the first ready episode as `hero`, the rest into `items` up to `limit`. Later pages: no `hero`, no `upcoming`; both sources fetched with `before` from the cursor.
- **Mapping:** `generation_type` → `kind` (`weekly`, `on_demand` → `onDemand`, BE2.5a's `first` → `first`, else `unknown`, logged); `episode_number` → `number` (omitted if null); `duration_measured` → `timing` (`measured`/`estimated`); `about` = `chapter_titles.join(', ')` when non-empty (Paper's hero line "mornings, the standup, sleep"); briefs: `title` = the first part's text cut at the first sentence end, ≤ 80 chars (`kind 'quiet'` briefs dropped); `hasAudio` from `audio_status 'ready'`.
- **`upcoming`** (first page only), from the person's newest job (BE2.5a): `queued|running` → `{ state: "making", readyAt }`; `quiet_week|nothing_safe_to_say` finished in the last 7 days and no newer episode → `{ state: "quietWeek", line, nextAt }` (`line` from one exported constant, founder Q-3 copy); else `none`.
- Bucket `read`; agent timeout 10 s, retry `read`. Log: door, userId, status, ms, item count (never a title).

Acceptance: the first page has the newest episode as hero and nothing twice; quiet and making show only on page one; paging merges briefs and episodes without gaps.

Tests (door suite, plus):
- `the newest ready episode is the hero and isn't repeated in items`
- `briefs and episodes merge newest first across pages without repeats or gaps`
- `quiet briefs are not listed`
- `a running job shows making with its ready time`
- `a quiet week shows its line for seven days, then nothing`
- `a newer episode after a quiet week clears the quiet line`
- `an unknown generation type maps to unknown and is logged`
- `a tampered cursor is invalid_request`
- `another person's episodes and briefs never appear` (two users)
- fixtures `podcasts.library.json`, `.empty`, `.making`, `.quiet`, `.page2` validate against the output schema.

Proof in the PR: test output; a local-staging call for a seeded test account (counts only).

Watch out: the two sources page independently; build the cursor from the last item **returned**, not the last fetched, or items fall between pages.

---

### BE3.5 · One episode: `GET /v2/episodes/:id`                             size: M
Place in the tree: podcasts › PC-2 › one episode (agent route + door)
Repo · branch: agent then backend · `agent/BE3.5-episode`, `be/BE3.5-episode`
Needs: BE3.0a, BE3.0c (for lines; until then, legacy-style lines), BEA.7, BEA.2, BE0.1, BE0.2      Unblocks: PL3.4b, PL3.4c, P14 on live data, P06 (ON-11 tease, first run)

Why: opening an episode gives you its words line by line, its chapters, a private link to its audio and what it was made from, and nothing it shouldn't.

Inputs: contract 03 §3, §8; fixtures `episode.v2.json`, `episode.legacy.json`, `episode.noaudio.json`; BEA.7's `signedAudioUrl(path, ttl)`

Spec:
- Agent `GET /podcasts/:userId/:episodeId` → `{ episode: { id, title, description, generation_type, episode_number, duration_seconds, duration_measured, created_at, covers_period_start, covers_period_end, audio: { url, expiresAt } | null, sections, chapters, made_from: [{ kind, count }], feedback: { verdict, at } | null } }`: ownership by `user_id` (404 `{ error: 'not found' }` otherwise), named columns, `audio` via `signedAudioUrl(audio_path, 3600)`. `made_from` counts distinct evidence sources over the plan items' evidence (resolved through BE3.1a's resolver; kinds mapped to `SourceKind`). `feedback` = the newest `episode_feedback.metadata.verdict` for this episode and user.
- Door mapping (`mapEpisode(row)`, unit-tested on all three shapes):
  - `lines`: for each section, each sentence → `{ index, text, chapterIndex, register, claimId }` (`claimId` = UUIDv5(episodeId, section.id) for non-craft; `register: craft` for craft); `startSeconds` from `lineTimes` when `duration_measured`.
  - `chapters`: `{ index, title, startSeconds?, claimId? }` (`claimId` of the chapter's first non-craft section); omitted entirely unless measured (no estimated ticks).
  - `claims`: one per non-craft section id (first occurrence), `kind` mapped (`said_vs_did` → `goal`), `guessId` for `hypothesis:<id>`.
  - Legacy (`sections` empty): `lines` from `splitLegacyScript`, `register: craft`, `chapterIndex: -1`, no claims, `timing: estimated`; no script → `lines: []` and `description`.
  - `audio.durationSeconds` = measured total or estimate; `mimeType: audio/mpeg`.
- Bucket `read`; agent timeout 10 s, retry `read`.

Acceptance: a v2 episode has lines, chapters with measured starts, claims and a signed link; a legacy episode has readable lines and nothing invented; the link expires after an hour.

Tests (door suite, plus):
- `a v2 episode's lines follow the spoken order with their chapters and claims`
- `chapters appear only when timing was measured`
- `a hypothesis part carries its guess id`
- `a legacy episode reads as plain lines with no chapters or claims`
- `an episode without audio has no audio object and still has its words`
- `the audio link is signed and expires within an hour`
- `claim ids are stable across two reads`
- `another person's episode is not found` (two users)
- agent: `the episode route never returns the embedding` · two-user test
- fixtures `episode.v2.json`, `episode.legacy.json`, `episode.noaudio.json`.

Proof in the PR: test output; a staging read of a seeded v2 episode (counts of lines, chapters, claims; no text).

Watch out: the script and sentences are the person's material: never log them. `script` itself is not in the response (lines replace it).

---

### BE3.6 · A past brief by id: `GET /v2/briefs/:id`                         size: S
Place in the tree: podcasts › PC-1 › a brief square › the brief (agent route + door)
Repo · branch: agent then backend · `agent/BE3.6-brief-by-id`, `be/BE3.6-brief-by-id`
Needs: BE1.3, BE1.3b, BEA.2      Unblocks: PL3.4a (opening a brief square), P13

Why: tapping an older brief in the podcasts tab plays it, like today's.

Inputs: contract 03 §6; contract 02 §3 (`Brief`, `mapBrief`)

Spec: agent `GET /briefs/:userId/:briefId` (ownership, named columns, `audio` signed when `audio_status 'ready'`); door reuses BE1.3's `mapBrief` and BE1.3b's audio fields. Bucket `read`.

Tests: door suite · `an old brief comes with a fresh signed link` · `a brief without audio reads as text` · `another person's brief is not found` · fixture `brief.byid.json`.

Proof in the PR: test output.

Watch out: brief audio retention: briefs keep their audio for as long as the account (founder Q-5); nothing here deletes it.

---

### BE3.1a · Why this is here: the claim route                              size: M
Place in the tree: podcasts › PC-3 › one claim (agent)
Repo · branch: retrospect-agent · `agent/BE3.1a-episode-claim`
Needs: BEA.2 (`walkEvidence` scoped), BE3.0a      Unblocks: BE3.1b, BE3.5's `made_from`

Why: any part of an episode can show you what it claims, whether it's stated or asked, how sure Retro is, where it says it, and every source it rests on, in your own words.

Inputs:
- Contract: 03 §4 (`Claim`, `EvidenceRow`)
- Reference: agent-api-reference §9.4 (`walkEvidence`), §9.3 (`lineage`), §10.1 (`raw_content.content_type`, `trust_class`), §3 (hypotheses `restsOn` resolution, BE1.4)
- Code anchors: `src/brain/lineage.ts:31-64`, `src/writer/write-episode.ts` (`factLines`), `src/understanding/read.ts`, `src/hypotheses/offer.ts`

Spec:
- `GET /podcasts/:userId/:episodeId/claims/:sectionId?cursor=&limit=20` (`sectionId` = the plan item id; the door converts from the claim UUID by matching UUIDv5 over the episode's section ids).
- **Claim text** (`claimText(item)`, pure, one case per kind, lowercase, ≤ 140 chars, never a model): pattern → its label ("your standups run long most mornings"); answer → the answer in second person; shift → "your <metric> was <up|down> this week"; said_vs_did → "you said <goal>; this week <hours> hours went to it"; content → "you followed <topic>"; why → the mechanism as a question; hypothesis → the stored question. **Asked kinds must end in "?"**; a function test enforces it.
- **Basis:** from the evidence rows' `trust_class` (`own_words` → said; `record`/`automated` → did; both → both; none → unknown).
- **Sureness:** from the claim's confidence through the contract 02 thresholds (the BE1.6 constant, imported): pattern, answer and why carry their own confidence; a hypothesis takes the lowest confidence among what it rests on; shift and content have none. Asked claims show it too (Paper PC-3: "asked · fairly sure · rests on 3 mornings").
- **Evidence:** pattern/answer/why/fact → `walkEvidence(claim, db, userId)` sources; said_vs_did, shift, content → the plan item's `evidence` ids; hypothesis → its `restsOn` claims' sources. Resolve each to `{ kind, id, date, excerpt }`: `raw_content` (own words: the first line of `content`, ≤ 120 chars; voice → `voice`) or `source_items` (a record line built from its fields: calendar → "<title> · <minutes> min", health → "<value> <unit> · <weekday>"). Dedup by id, newest first, keyset paged.
- **Moments:** this episode's first sentence of the section, plus up to two earlier episodes whose stored `sections` contain the same plan item id (newest first), with `startSeconds` from `chapters` + `lineTimes` when measured.
- **Correct target:** pattern → `{ kind: 'pattern', id }`; answer → `{ kind: 'answer', id }`; others none (PC-3's "not right" then sends free text).
- Every query filtered by `user_id`; the starting claim's ownership checked first (404 otherwise).

Acceptance: every v2 section in a seeded episode returns a claim with readable text and at least one evidence row (or `total: 0` with no rows when the brain has none, never invented); asked claims are questions.

Tests (layer 1 + 2, two users):
- `a stated pattern returns its label, sureness and its entries as evidence`
- `an asked why is returned as a question with its sureness`
- `a hypothesis claim carries its guess and rests on its stated claims' sources`
- `said-vs-did evidence lists the calendar events behind it`
- `the same plan item in an earlier episode is listed as a moment`
- `own-words-only evidence reads as said; records only as did`
- `an asked claim whose text isn't a question is refused`
- `evidence pages by twenty without repeats`
- `another person's claim returns nothing` · runs as `service_role`.

Proof in the PR: test output; a staging run over one seeded episode (counts per claim kind; no excerpts in the PR).

Watch out: excerpts are the person's own words: never log them, never put them in the PR. `walkEvidence` depth 6 can fan out: cap resolved rows at 200 per claim and report `total` from the capped count with a `capped` log flag.

---

### BE3.1b · Why this is here: the door                                       size: S
Place in the tree: podcasts › PC-3 › one claim (door)
Repo · branch: backend · `be/BE3.1b-claim`
Needs: BE3.1a, BE3.5 (claim id ↔ section id), BE0.1, BE0.2      Unblocks: PL3.4d, P15 on live data

Spec: `GET /v2/episodes/:id/claims/:claimId?cursor=&limit=20` → contract 03 §4. Validates both ids as UUIDs; maps the agent's `generation`-free claim into the contract (`said_vs_did` → `goal`, kinds outside the list → `unknown` logged); `guess` mapped with contract 02's `mapGuess` (BE1.4); `opens` for `raw_content` own-words rows → `{ kind: 'entry', id }`, records → omitted until contract 05's YO-3 door exists. Refuses (404, logged as `askedNotQuestion`) an asked claim whose text doesn't end in "?". Bucket `read`.

Tests: door suite · `a stated claim maps with its evidence and correct target` · `an asked claim with a guess maps the guess like the journal does` · `records carry no opens until a source page exists` · `an asked claim that isn't a question is not found` · fixtures `claim.stated.json`, `claim.asked.hypothesis.json`, `claim.asked.why.json`.

Proof in the PR: test output.

Watch out: the claim id is opaque to the app; never accept a raw plan item id from the client.

---

### BE3.2a · Feedback the next episode actually hears                         size: M
Place in the tree: podcasts › after an episode › feedback (agent)
Repo · branch: retrospect-agent · `agent/BE3.2a-episode-feedback`
Needs: BEA.2 (feedback POST checks the episode belongs to the user), BEA.3 (preferences merge)      Unblocks: BE3.2b

Why: when you tell Retro what landed and what didn't, next week's episode is written with it. Today the new writer never reads it.

Inputs: agent-api-reference §8.1 (feedback route, not idempotent, no ownership), §8.3 (directives wiped by PUT); `src/pipelines/podcast.ts:239, 583-603` (legacy folds feedback), `src/writer/write-episode.ts` (`writerPrompt` takes `listener.tone`), `src/appetite/appetite.ts:95` (ratings as signals)

Spec:
- Migration `158_episode_feedback_keys.sql` (request): unique index on `episode_feedback (user_id, (metadata->>'client_feedback_id')) where metadata ? 'client_feedback_id'`.
- `POST /feedback/episodes/:episodeId` accepts `{ userId, text?, verdict?: 'more'|'less', source, clientFeedbackId }`: at least one of text or verdict; `text` stored in `feedback_text` (empty string when only a verdict, since the column is NOT NULL); `metadata { client_feedback_id, verdict }`; **`rating` left null** (founder Q-2b). A repeat `clientFeedbackId` returns the stored row (200), no second insert.
- **The v2 writer hears it:** `writerPrompt` gains a "WHAT THEY TOLD YOU ABOUT RECENT EPISODES" block: the last 5 unprocessed feedback items for the user (verdict + text, each ≤ 300 chars), framed as craft guidance ("more of / less of this kind of thing"), **never as facts about the listener** (the guard still checks every sentence against section facts only). After a made episode, those rows get `processed = true`.
- `GET /feedback/episodes/:episodeId` (BEA.2 scoped) also returns `verdict`.

Acceptance: feedback sent twice is one row; next week's writer prompt includes it; it never becomes a claim.

Tests (layer 1, two users): `the same feedback key twice stores one row` · `a verdict alone is accepted` · `the writer prompt carries the latest feedback as guidance` · `feedback can't produce a claim the guard keeps` (a fake writer that turns feedback into a claim is cut) · `feedback is marked processed after a made episode, not after a quiet week` · `another person's episode can't take feedback`.

Proof in the PR: test output.

Watch out: never fold feedback into `user_preferences.directives` with a `PUT` (BEA.3: it replaces); the v2 path reads `episode_feedback` directly.

---

### BE3.2b · Feedback door: `POST /v2/episodes/:id/feedback`                 size: S
Place in the tree: podcasts › after an episode › feedback (door)
Repo · branch: backend · `be/BE3.2b-feedback`
Needs: BE3.2a, BE0.1, BE0.2      Unblocks: PL3.4e, UI5.4 on live data

Spec: request (zod) per contract 03 §5: `clientFeedbackId` UUID equal to `Idempotency-Key`; `verdict` enum optional; `text` 1–2,000 trimmed optional; at least one; `given` `tap|typed|voice` → agent `source` (`typed` → `manual`). Ownership: the door reads `podcast_episodes.user_id` first (doesn't rely on the agent). 201 new / 200 replay / 409 `idempotency_mismatch`. Bucket `write`. Logs never carry `text`.

Tests: door suite (idempotency, isolation) · `a verdict-only feedback is accepted` · `empty feedback is invalid_request` · `the text never appears in a log line` · fixtures `feedback.request.json`, `feedback.response.json`, `error.idempotency_mismatch.json`.

Proof in the PR: test output.

---

### BE3.3a · The weekly episode, made in your own week                         size: M
Place in the tree: podcasts › the weekly episode › schedule (agent)
Repo · branch: retrospect-agent · `agent/BE3.3a-weekly-local-time`
Needs: BE2.5a (job runner and `podcast_jobs`), BEA.4, BEA.5, BEA.8      Unblocks: BE3.3b, BE3.4b's `upcoming`

Why: your episode arrives on Sunday morning where you live (founder Q-4 lean: Sunday 9:00 your time), not at 6 a.m. UTC, which is the middle of Saturday night in California.

Inputs: `src/index.ts:141-143` (`0 6 * * 0` UTC), `src/jobs/weekly-podcast.ts` (eligible = anything new in 14 days; legacy unless `EPISODE_PLANNER=v2`); BE2.5a card (jobs, `generation_type`, transactions); `users.time_zone` (contract 00 `X-Time-Zone`)

Spec:
- Migration `159_weekly_delivery.sql` (request): `podcast_jobs.deliver_at timestamptz`, unique index `(user_id, kind, date_trunc('week', deliver_at))` for `kind = 'weekly'` (one weekly job per person per week, ever).
- Replace the Sunday cron with an hourly sweep: for each eligible user (same 14-day rule, `ambient` honoured), compute this week's delivery time = next Sunday 09:00 in `users.time_zone` (UTC when unset, logged); when `now ≥ deliver_at − 3h` and no weekly job exists for that week, enqueue `{ kind: 'weekly', deliver_at }`. The runner makes it (v2 when the switch says so).
- Outcomes recorded on the job (`made`, `quiet_week`, `nothing_safe_to_say`, `failed`). A failed job retries once within the 3-hour window; after `deliver_at` it doesn't retry (the person was promised Sunday morning, a Monday episode isn't the same; logged).
- The old `runWeeklyPodcasts` stays behind `LEGACY_WEEKLY_CRON` (default off once this ships) until X07.

Acceptance: a person in Los Angeles and one in London each get one job per week, timed for their Sunday morning; restarts never make a second.

Tests (layer 1, injected clock and zones): `a job is queued three hours before sunday nine in the person's zone` · `two sweeps in one hour queue one job` · `a person without a time zone is scheduled in utc and logged` · `a quiet week is recorded and not retried` · `a failure retries once before delivery, never after` · `the spend cap skips the person and logs it` · two-user isolation.

Proof in the PR: test output; a local-staging sweep over three seeded zones (job times only).

Watch out: daylight saving: compute `deliver_at` with the zone's rules for that Sunday (a date library with IANA support, pinned), never by adding a fixed offset.

---

### BE3.3b · "This week's episode is here": the push                           size: S
Place in the tree: podcasts › the weekly episode › push (backend)
Repo · branch: backend · `be/BE3.3b-episode-push`
Needs: BE3.3a, BE2.6, BE2.7 (push sender), founder action (APNs key)      Unblocks: PL3.4g's tap handling on device, T05a's push step (staging)

Why: one quiet notification on Sunday morning tells you this week's episode is ready, and tapping it opens the episode.

Inputs: contract 03 §9; BE2.7 card (content-free payloads, collapse id, environments)

Spec:
- Migration `013_push_sends.sql` (backend, request): `push_sends(id, user_id → users cascade, kind, ref_id, local_day date, sent_at, apns_id)`, unique `(user_id, kind, ref_id)` (never twice for one episode) and a check against more than one push per `local_day` across kinds (enforced in code with the row as the lock).
- A minute sweep: weekly jobs with `state = made` and `deliver_at ≤ now` and no `push_sends` row → send the payload in contract 03 §9 to every active device of the user; if it's between 21:00 and 08:00 local, wait for 08:00. A first-run job's push belongs to first run (contract 01), not here.
- `quiet_week`, `nothing_safe_to_say`, `failed`: no push.
- Log: kind, user id, device count, APNs status codes (no title).

Acceptance: one push per made weekly episode, at its delivery time, never at night, never twice; a quiet week sends nothing.

Tests (door-adjacent, a fake APNs): `a made episode is pushed once at its delivery time` · `a push due at night waits for eight` · `a second sweep sends nothing again` · `a quiet week sends nothing` · `the payload carries no title or words` (fixture `push.episode-ready.json` compared) · `a second push the same local day is held` · two-user isolation.

Proof in the PR: test output; on the founder's phone (sandbox), one recorded push and tap (with the integrator).

Watch out: old builds still schedule a local "weekly reflection" reminder at Sunday 10:00 (PodcastNotificationService). Until X3.2 retires it, the person could get two Sunday notifications; X3.2 sequencing in platform.md handles it.

---

### BE3.8 · Old screens keep playing after the bucket goes private              size: S
Place in the tree: podcasts › retiring the old › old route on private audio (backend)
Repo · branch: backend · `be/BE3.8-old-podcasts-signed`
Needs: BEA.7      Unblocks: the founder-approved step that makes `podcast-audio` private before X07

Why: the old podcasts tab (still live through Beta 1) plays episodes from a public link; making audio private must not silence it.

Inputs: backend-reference §11 (`GET /podcasts`, `/latest`, `/:id` return `audio_url`); app-reference §7 (the old app refetches `GET /podcasts` on every `TranscriptViewModel` init and plays the remote URL)

Spec: the old routes replace `audio_url` in their responses with a signed link (24 hours) built from `audio_path` (BEA.7), falling back to `audio_url` only when `audio_path` is null; projected columns (drop `summary_embedding`, keep `script`, which the old screens read). No new route.

Tests: `the old list returns signed links that expire in a day` · `an episode without a path falls back to its old link` · `the old list no longer carries the embedding` · two-user isolation.

Proof in the PR: test output; the old app on local staging plays an episode with the bucket private (integrator).

Watch out: the old app stores the URL into `podcasts.json` and may replay it days later; 24 hours plus refetch-on-open covers the old screens' pattern (they refetch at every construction). Don't change the response shape: the old decoder is strict.
