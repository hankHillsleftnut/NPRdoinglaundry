# Backend · phase 1 cards: the journal slice

The tree for this phase: **journal** › capabilities: sending into your bank (BE1.1) · today's brief (BE1.3, BE1.3b) · guesses (BE1.4) · entries (BE1.5, BE1.5b) · what Retro took (BE1.6) · "not right" (BE1.7). Contract: [../contracts/02-journal.md](../contracts/02-journal.md). Every door is built with the kit (BE0.1), passes the door suite (BE0.2) and the invite gate (BE0.12). Every agent route gets a two-user PGlite test. Fixtures: the backend validates every `fixtures/02/*.json` response file against the door's zod output schema (testing.md layer 4).

Order: BE1.1 → BE1.5 → BE1.5b → BE1.6 (needs BEA.2) → BE1.7 (needs BEA.1, BEA.2) → BE1.3 → BE1.3b (needs BEA.7) → BE1.4. Two at most in review at once.

---

### BE1.1 · Sending into your bank                                         size: M
Place in the tree: journal › sending › `POST /v2/entries`, `GET /v2/entries/today`
Repo · branch: backend · `be/BE1.1-entries`
Needs: BE0.0, BE0.1, BE0.2, BE0.12      Unblocks: PL2.2's live target, PL3.1, P09

Why: everything you type or say in the journal lands in your bank exactly once, even when you were offline when you sent it.

Inputs:
- Contract: 02 §2, §5 (`Entry`); the integrator's contract pass (`retrospect-handover/contracts/BE1.1-BE1.5.md`, 22 Oct), whose leans this card now carries
- Reference: backend-reference §10 (`POST /content`, `insertRawContent`, dedup), §9 (raw_content columns); agent-api-reference §10.1 (content types, "sent by the person" set at `src/planner/daily.ts:22`)
- Code anchors: `src/entries/doors.ts`, `src/entries/store.ts`, `supabase/migrations/022_entries.sql`, `src/services/content-insert.ts` (`requestHash`), `src/services/agent-handoff.ts`, `src/services/agent-client.ts` (`runAgentIngest`)

Spec (as built):
- Migration `022_entries.sql`: a unique partial index on `(user_id, metadata->>'client_entry_id')`, whatever the content type (the agent's dedup key is per type, F1); `resolve_zone` (the request's `X-Time-Zone` wins and is stored on `users.time_zone` when it changes, else the stored zone, else UTC, F2); `entry_create` (insert once; a replay is the stored row; the same key with another fingerprint is a mismatch); `entries_today`. The functions never read `raw_content.embedding`.
- Request (zod, strict): `text` trimmed, 1–20,000 UTF-16 code units; `kind` `'typed' | 'voice'`; `clientEntryId` UUID; `createdAt` ISO datetime, UTC with a `Z` (an offset is `invalid_request`). Header `Idempotency-Key` required and equal to `clientEntryId`, lowercased both sides (else `invalid_request`).
- `createdAt`: no floor (an old offline entry is never thrown away, F3); more than 5 minutes ahead of the server is clamped to the server's now and counted in the door log (`clockSkew: 1`), never refused; within 5 minutes it is kept as sent.
- Write: `content_type` `journal_entry` (typed) or `voice_journal` (voice), `content_date = createdAt` (clamped), `metadata = { client_entry_id, request_hash, app_version }`, `processing_status 'pending'`, `created_at = now`. `request_hash` = `requestHash(contentType, text)`: **kind + trimmed text, never `createdAt`**, so a clamped retry is still a replay.
- New row → **201** `{ entry }` and the hand-off to ingest after the response (`startIngest`, injected; the server's is `setImmediate(() => handOffToAgent(runAgentIngest, …))`, which can never write the row's status). Replay → **200** `{ entry }` (the stored row, same bytes), no second ingest. Same key, different fingerprint → **409** `idempotency_mismatch`, nothing stored.
- `GET /v2/entries/today`: the person's own entries (`SENT_TYPES` in `entries/doors.ts`, the agent's "sent by the person" set, passed to SQL) whose `coalesce(content_date, created_at)` falls on today's calendar day in the resolved zone, oldest first (ties by id), max 200; `date` is that day. `video_entry` isn't in the agent's set, so old video notes never show (accepted for Beta 1).
- Mapping to `Entry`: `kind` per contract 02 §5 with a default of `imported`; `reading` from `processing_status` (null → `waiting`); `day` in the resolved zone; `clientEntryId` from `metadata.client_entry_id`, omitted when absent.
- Buckets: create `write`, today `read`; neither open to waitlisted people. Log: door, userId, status, ms, `clockSkew` (never the text or an id).

Acceptance:
- One send = one row and one ingest; ten retries with the same key = still one row and one ingest.
- An offline backlog of entries sent in order arrives with their original `createdAt`.
- `today` shows the person's entries and nothing from records, mail or other people.

Tests (door suite, plus; * = fails when its rule is removed), `backend/tests/entries.test.ts`, `entries-doors.test.ts`, `contract-02-fixtures.test.ts`:
- `a send creates one row and one ingest, in the shape of the contract fixture`
- `ten retries with the same key make one row and one ingest` (incl. two at once, and an upper-case key)
- `the same key with different text, or a different kind, is idempotency_mismatch` *
- `a future createdAt is clamped to now and counted, not refused` * · `the Idempotency-Key must be present and equal to clientEntryId; the body is strict`
- `today follows X-Time-Zone, not UTC, and stores the zone` * (UTC−8 at 23:30) · `today never lists calendar, mail or another person's rows, and equals the contract fixture` *
- `today lists every kind the person sends, maps the rest to imported, and stops at the cap`
- fixtures: every `fixtures/02/entr*.json` validates against the output or request schema.

Proof: test output; one safety test shown failing with its rule removed.

Watch out: don't route through `POST /content` internally (its responses and side effects are the old app's). `createdAt` is the person's moment, not the server's. Before applying 022 by hand: no two rows of one user may share `metadata->>'client_entry_id'` (nothing on main writes that field yet).

---

### BE1.3 · Today's brief: latest, history, the switch                     size: M
Place in the tree: journal › today's brief › `GET /v2/briefs/latest`, `GET /v2/briefs`, `PUT /v2/briefs/enabled`
Repo · branch: agent then backend · `agent/BE1.3-brief-history`, `be/BE1.3-briefs`
Needs: BE0.1, BE0.2      Unblocks: PL3.1, P09, P10, BE1.3b

Why: the brief card at the top of the journal and the brief sheet show the real brief, in plain words, never bookkeeping.

Inputs:
- Contract: 02 §3
- Reference: agent-api-reference §2.1–§2.5 (two shapes in one column; snake_case latest vs camelCase generate; v2 items are bookkeeping; UTC `brief_date`)
- Code anchors: agent `src/routes/briefs.ts:9-33`, `src/briefs/daily-brief.ts:39-54`, `src/briefs/run-daily-brief-v2.ts:46-53`

Spec:
- Agent: `GET /briefs/:userId/history?before=<brief_date>&limit=20` (newest first; projects `id, brief_date, kind, through_line, spine_movement, items, created_at`).
- Door mapping (one function `mapBrief(row)`, unit-tested against both shapes):
  - v1 (`spine_movement` not `'planner v2'`): one part per item: `text` = item.text, `why` = item.why (null → omitted), `sources` = `[{ kind: 'entry', id: sourceRef.raw_content_id }]` when that id is a non-empty UUID.
  - v2 (`spine_movement === 'planner v2'`): parts = `through_line` split on blank lines (`/\n\s*\n/`), each `{ text, sources: [] }`; **`items` are never mapped** (they hold the words "pattern"/"answer").
  - `kind 'quiet'`: one part with the agent's line.
  - `date` = `brief_date` (UTC today; the contract's "local day" lands with BE6.2's per-user brief time, which writes local dates. The PR notes this for the integrator).
- `GET /v2/briefs/latest` → `{ brief, enabled }` (`enabled` from `users.daily_brief_enabled`); `GET /v2/briefs?cursor=` (opaque base64 of `brief_date`); `PUT /v2/briefs/enabled { enabled: boolean }` (strict boolean; the agent's route treats anything but `true` as false, so the door validates first).
- Buckets: reads `read`, the switch `write`. Agent timeouts 10 s, retry `read` on reads, `none` on the switch.

Acceptance: a v1 brief, a v2 brief and a quiet brief each map to readable parts; no part's text is ever just "pattern" or "answer".

Tests: `a v1 brief maps one part per item with its why` · `a v2 brief is split into paragraphs and its bookkeeping items are dropped` · `a quiet day is one plain part` · `history pages newest first` · `the switch only accepts true or false` · fixtures `brief.latest.v1/v2/quiet/none.json`, `briefs.list.json` · agent: `history only returns the person's briefs` (two users).

Watch out: production makes no briefs today (`ENABLE_DAILY_BRIEF` unset, founder decision D10); local staging generates them with `POST /briefs/generate` for test users.

---

### BE1.3b · Brief audio                                                   size: L (split: agent synthesis + storage · door audio fields)
Place in the tree: journal › today's brief › audio
Repo · branch: agent then backend · `agent/BE1.3b-brief-audio`, `be/BE1.3b-brief-audio`
Needs: BE1.3, BEA.7, BEA.4      Unblocks: P10 (JR-2), C26 playing states, EX-2

Why: **briefs are audio** (founder, 21 Oct): the journal's brief card plays, and the sheet shows the part being spoken.

Inputs:
- Reference: agent-api-reference §2.6 (no brief TTS anywhere), §7.3 (podcast audio upload pattern)
- Code anchors: agent `src/services/elevenlabs.ts` (`textToSpeech`, `VOICE_PERSONAS`, `estimateDuration`, `chunkScript`), `src/pipelines/podcast-v2.ts:78-90` (persona from `users.voice_persona`, upload), `src/briefs/run-daily-brief.ts:93-146`

Spec:
- Migration `155_brief_audio.sql`: `daily_briefs.audio_path text`, `audio_status text default 'none' check in ('none','making','ready','failed')`, `audio_duration_seconds numeric(8,2)`, `audio_parts jsonb default '[]'` (`[{ index, startSeconds }]`), `audio_chars int`.
- After a non-quiet brief is saved (not a dry run), synthesise **one part at a time** with the user's persona (`textToSpeech(partText, { persona })`), measure each part's real duration from the MP3 (add `music-metadata`, pinned, `parseBuffer`), concatenate the buffers in order (same encoding, so MP3 frames concatenate cleanly), record `startSeconds` cumulatively, upload to the private bucket at `briefs/<userId>/<briefId>.mp3`, set `audio_status 'ready'`. Record spend (`kind 'brief_audio'`, ElevenLabs characters) through BEA.4. Failure: `audio_status 'failed'`, the brief stays text-only, logged as a count.
- `POST /briefs/:userId/:briefId/audio` (internal): (re)make audio for one brief (idempotent: `ready` returns as is).
- Door: `GET /v2/briefs/latest` adds `audio: { url, expiresAt, durationSeconds }` when ready (signed URL, 1 hour, BEA.7) and `parts[i].startSeconds`; nothing in the list endpoint.
- Cost visibility: the PR reports measured characters and dollars for a typical brief on local staging.

Acceptance: a non-quiet brief gets audio whose parts start where the contract says; a failed synthesis leaves a readable brief; the URL expires.

Tests: `each part's start time is the sum of the previous parts' real durations` (fixture MP3s) · `a quiet brief makes no audio` · `a synthesis failure keeps the brief and marks audio failed` · `remaking audio for a ready brief does nothing` · `audio costs are recorded per brief` · door: `latest includes a signed audio link only when ready`.

Watch out: ElevenLabs `eleven_v3` has a 5,000-character limit per call (`V3_CHAR_LIMIT`); a part longer than that is split by `chunkScript` and its pieces concatenated before measuring. Voice is about 60% of per-user cost: never synthesise on a dry run or for staging test users unless the test asks.

---

### BE1.4 · Guesses                                                         size: M
Place in the tree: journal › guesses › `GET /v2/guesses`, `POST /v2/guesses/:id`, `GET /v2/guesses/:id/why`
Repo · branch: agent then backend
Needs: BE0.1, BE0.2      Unblocks: C28, P09

Why: a guess card in the journal asks one honest question, and shows what it rests on in words.

Inputs:
- Contract: 02 §4
- Reference: agent-api-reference §3.1–§3.5 (no list route; `restsOn` ids only; repeat answer 404s; the `speak` dial)
- Code anchors: agent `src/hypotheses/offer.ts:13-60`, `src/routes/hypotheses.ts:10-25`, `src/understanding/read.ts` (resolving ids to text)

Spec:
- Agent: `GET /hypotheses/:userId/pending` → `{ speaking, guesses: [{ id, question, framework: {name, source?, wonders?}, rationale, status, restsOn: [{ kind, id, text }] }] }`: rows from `loadOfferable`, filtered by the dial (`speak` false → `speaking:false, guesses:[]`) and by `chooseOffer`'s rules (still-supported claims only); `restsOn[].text` resolved from `readUnderstanding` (answer → `answer`, pattern → `label`, why → `mechanism` in words, fact → the fact's text). The `why` route gains the same resolved `restsOn`.
- Door: maps `kind` (`answer|pattern|why|fact`) onto `SourceRef` kinds (`why` → `pattern` with the why's text); `POST /v2/guesses/:id`: ownership check (`hypotheses.user_id`), then read status; if already `confirmed`/`declined` return it (the agent 404s on repeats); else call the agent.

Acceptance: with the dial off, the journal shows no guesses; with it on, each guess shows readable reasons; answering twice gives the same result.

Tests: `pending is empty while the dial is off` · `restsOn carries readable text for every kind` · `answering twice returns the stored status` · `another person's guess is not found` · agent two-user test.

Watch out: the dial is the founder's (D11); never flip it in code or migrations.

---

### BE1.5 · Entry history and one entry                                     size: M
Place in the tree: journal › entries › `GET /v2/entries`, `GET /v2/entries/:id`
Repo · branch: backend · `be/BE1.5-entry-history`
Needs: BE1.1      Unblocks: C31, P11, P12

Spec:
- `GET /v2/entries?cursor=&limit=50&q=`: own words only (the "sent by the person" set), newest first; cursor = base64 of `(coalesce(content_date, created_at), id)`; `q` (1–100 chars): case-insensitive `ilike` with `%`, `_` and `\` escaped; each result carries `matches: [{ start, length }]` computed in the door (case-insensitive, all occurrences, on the returned text); `limit` ≤ 100.
- `GET /v2/entries/:id`: ownership (`raw_content.user_id`), else `not_found`.
- Project columns explicitly (never `select('*')`: `raw_content.embedding` is 3,072 floats).

Tests: door suite · `search escapes wildcards` (searching "50%" finds only that) · `match ranges point at the right words` · `paging never repeats or skips an entry` (entries with equal timestamps) · `another person's entry is not found` · fixtures `entries.list.json`, `entries.search.json`, `entry.json`.

---

### BE1.5b · Editing and deleting an entry, and forgetting what came from it     size: L (split: agent forget/reread · doors)
Place in the tree: journal › entries › `PATCH /v2/entries/:id`, `DELETE /v2/entries/:id`
Repo · branch: agent then backend
Needs: BE1.5, BEA.1, BEA.2      Unblocks: P12 (JR-4 editing and delete)

Why: "deleting an entry removes everything taken from it" (founder rule K7), and an edit is read again, without leaving claims built on words you took back.

Inputs: agent-api-reference §4.3 (retraction plan: target then everything whose only support ran through it), §9.3 (`lineage` forward), §10.2 (`assertion_evidence.raw_content_id`), §10.4 (`answer_evidence`)

Spec:
- Agent `POST /entries/:userId/:rawContentId/forget { mode: 'delete' | 'edit' }`: find every claim supported by this entry (`lineage` forward plus `answer_evidence.raw_content_id`), retire the ones whose **only** support was this entry (reuse `retract.ts`'s planning and BEA.1's functions; claims with other support only lose this evidence), then for `delete` delete the `raw_content` row; for `edit` leave the row for the backend to update. One transaction; returns `{ retired, weakened }`.
- Door `DELETE /v2/entries/:id` → agent forget(delete) → `{ deleted: true }`; `PATCH /v2/entries/:id { text }` → agent forget(edit) → update `content`, `processing_status 'pending'`, clear the embedding, hand off to ingest → `{ entry }` with `reading 'waiting'` ("retro is reading it again").

Tests: `deleting an entry retires claims that rested only on it and keeps ones with other support` · `editing re-reads the entry and drops claims from the old words` · `another person's entry can't be deleted` · agent two-user test.

Watch out: never hard-delete claims (the brain retires, it never deletes: §4.3); the evidence rows go with the entry by cascade only where the foreign key says so; check each.

---

### BE1.6 · What Retro took from an entry                                  size: M
Place in the tree: journal › one entry › `GET /v2/entries/:id/took`
Repo · branch: agent then backend
Needs: BE1.5, BEA.2      Unblocks: UI1.2, P12

Spec:
- Agent `GET /lineage/:userId/entry/:rawContentId` → `{ reading, items: [{ kind: 'fact'|'answer'|'pattern', id, text, confidence }] }`: `lineage({ direction: 'forward', kind: 'raw_content' })` plus answers via `answer_evidence`; active claims only; text from the same keys `readUnderstanding` uses; `reading` from the entry's `processing_status`.
- Door maps `confidence` to `sureness` (< 0.5 `just a hunch`, < 0.8 `fairly sure`, ≥ 0.8 `very sure`: thresholds and words are founder decision 02 §7.1, kept in one exported constant).

Tests: `an unread entry reports waiting with no items` · `a read entry lists its facts, answers and patterns` · `retired claims don't appear` · `sureness thresholds map as the contract says` · two-user test.

---

### BE1.7 · "Not right"                                                    size: M
Place in the tree: journal › one entry › corrections › `POST /v2/corrections`, `POST /v2/corrections/confirm`
Repo · branch: backend
Needs: BEA.1, BEA.2, BE1.6      Unblocks: UI1.2, P12

Inputs: contract 02 §6; agent-api-reference §4.1–§4.2

Spec:
- `POST /v2/corrections { text, about? }`: with `about` (the person tapped "not right" on one item): check ownership of the claim, return `{ outcome: 'confirm', candidates: [about with its text] }` without a model call, so the app asks "wrong, or changed?" and calls confirm. Without `about`: call agent `POST /corrections` (bucket `expensive`, timeout 30 s, retry `none`) and map the four outcomes to the contract's camelCase union (`not_a_correction` → `notACorrection`, `ask_own_words` → `askOwnWords`; candidates drop `n`).
- `POST /v2/corrections/confirm { kind, id, mode, note? }`: ownership check first (the agent's own check lands in BEA.2; the door doesn't rely on it), call agent confirm, then build `target` and `echo` (the agent omits them): `echo` = `got it. i'll stop saying "<text>"` plus `, and <n> things built on it` when `retired > 1` (lowercase, the brand's voice; the exact copy is the founder's, kept in one constant).
- The old `POST /graph/assertions/:id/feedback` stays until X07.

Tests: `tapping not right on an item asks wrong-or-changed without a model call` · `free text maps every agent outcome` · `confirming someone else's claim is not found and retires nothing` · `the echo counts knock-on claims` · fixtures `correction.*.json`.

Watch out: production must have migration 152 (BEA.1) before this door is used, or answer corrections half-fail.
