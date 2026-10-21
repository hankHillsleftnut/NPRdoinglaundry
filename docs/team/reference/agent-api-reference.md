# retrospect-agent API reference (field-level, from code)

Source: `retrospect-agent` at `origin/main` = `a886060` ("fix(security): the /runs cost dashboard needs the internal secret (M14 B0.7) (#130)", 21 Oct 2026). Every claim below is read from code with `git show origin/main:<path>`; line numbers are for that commit. Example JSON uses invented values.

## Read this first: global facts that apply to every route

- **There are no zod schemas on any route in this list.** `zod` is imported in exactly one file, `src/routes/integrations.ts:2`. Every route below validates its body by hand with `req.body ?? {}` destructuring and `typeof` checks. The "request schema" sections below therefore give the *effective* schema: what the handler actually checks, and what it lets through unchecked.
- **userId is never authenticated by the agent.** It always comes from the caller, either `req.params.userId` or `req.body.userId`, and the agent trusts it. The only gate is the shared `X-Internal-Secret` header (section 11). The backend door route must take userId from its own session and never forward a client-supplied one.
- **userId is not checked to exist.** No route except `POST /notifications/generate` checks that the user row exists. Writes for an unknown user fail on the FK and come back as a 500 with the Postgres message; reads return empty results with a 200.
- **Case convention is mixed.** DB rows returned through `select('*')` are snake_case (e.g. `GET /briefs/:userId/latest`, `GET /podcasts/:userId`). Engine results are camelCase (e.g. `POST /briefs/generate`, `/search/answer`). JSON stored *inside* jsonb columns is camelCase (e.g. `daily_briefs.items[].sourceRef`).
- **Dates.** `timestamptz` columns come back from PostgREST as ISO-8601 strings with an offset (e.g. `"2026-10-20T18:00:00.123456+00:00"`). `date` columns come back as `"YYYY-MM-DD"`. Engine-made timestamps use `new Date().toISOString()` (`"...Z"`, millisecond precision). Engines often truncate dates to `"YYYY-MM-DD"` with `.slice(0, 10)`. Day boundaries are **UTC** everywhere (brief date, "today" in the calendar, etc.); nothing takes a user timezone.
- **Durations** are in seconds (`duration_seconds`, `durationSeconds`), estimated at 150 words per minute (`src/services/elevenlabs.ts:37-40`). Money is in USD as a JS number (`costUsd`, `cost_usd`).
- **Model calls** go through `claudeJsonCompletion` (Anthropic) or `chatCompletion`/`jsonChatCompletion` (OpenAI). Model names come from env vars in `src/config.ts:33-51`:
  - `ANTHROPIC_WRITER_MODEL` (default `claude-sonnet-5-5`): conversation reply, correction targeting, search answer, brief v2 writer, hypothesis proposal, episode writer v2.
  - `ANTHROPIC_GUARD_MODEL` (default `claude-haiku-5-5`): the claim guard (fact check of every sentence).
  - `ANTHROPIC_TIME_CATEGORY_MODEL` (default `claude-haiku-5-5`): search query rewrite, said-vs-did judge, content-group naming.
  - `ANTHROPIC_QUESTIONS_MODEL` (default `claude-sonnet-5-5`): brief v1, onboarding stated goals, first pass.
  - `ANTHROPIC_COOK0_MODEL` (default `claude-sonnet-4-6`): onboarding magic moments.
  - `ANTHROPIC_COOK_B_MODEL` (default `claude-sonnet-4-6`): notifications, legacy Cook B agent.
  - `OPENAI_CHAT_MODEL` (default `gpt-4o`): episode summary and legacy title/description.
  - `OPENAI_COOK_A_MODEL` (default `gpt-4o-mini`): legacy Cook A.
  - `OPENAI_EMBEDDING_MODEL` (default `text-embedding-3-large`, 3072-dim): search query embedding, episode summary embedding.
  - `ELEVENLABS_MODEL_ID` (default `eleven_v3`), `ELEVENLABS_VOICE_ID`: episode audio only.
- **Spend cap.** `USER_DAILY_SPEND_CAP_USD` (default 15; `src/pipelines/spend-guard.ts:20`) is enforced only on `POST /podcasts/generate` (non-dry-run), the onboarding pipeline's episode step, and the daily-brief cron. It sums only `pipeline_run_traces.cost_breakdown.est_usd` plus `question_research_log.cost_usd` (`spend-guard.ts:29-43`). Conversation, search, corrections, briefs-by-HTTP, onboarding goals/interpret and notifications are **neither capped nor counted**.
- **Async errors.** Express is 4.x (`package.json`). A handler without try/catch that throws will not reach the JSON error handler; most handlers either catch or never throw. Called out per route where it matters.

---

## 1. Conversation

### 1.1 `POST /conversation`

- Handler: `src/routes/conversation.ts:9-14`. Engine: `converse()` in `src/conversation/reply.ts:54-114`.
- Auth: `requireInternalSecret` (`src/index.ts:64`).
- userId: `req.body.userId` (any truthy value; not type-checked).

**Request (effective schema)**

| field | type | rule |
|---|---|---|
| `userId` | string (UUID) | required, truthy only |
| `text` | string | required; `typeof text === 'string'` and `text.trim()` non-empty; trimmed before use. No max length (only the 10 MB body limit, `src/index.ts:37`). |

**Response 200** (the `usage` field is stripped at `conversation.ts:12`). TS type `Omit<ConverseResult, 'usage'>` (`reply.ts:35`):

| field | type | notes |
|---|---|---|
| `intent` | `'fyi' \| 'question' \| 'correction' \| 'chat'` | Model-chosen; any other value becomes `'chat'` (`reply.ts:82`). If the model fails twice, `'chat'` (`reply.ts:81`). |
| `reply` | string | May be `""`. Empty is a valid answer ("saying nothing is allowed"): fyi, model failure, every sentence cut, or no sentences. Citation markers `[n]` are removed. |
| `cut` | `Array<{ sentence: string; reason: string }>` | Sentences dropped. `reason` is free text, one of: the guard's (`"not in the evidence: ..."`, `"takes for granted: ..."`, `"meant to be asked, but reads as a statement"`, `"not checked"`), the style check's (`"stock comfort, not about this person (goal 9)"`, `"empathy not grounded in anything they said (goal 9)"`), `"restates their own words as a discovery (goal 18)"`, or `"over the N-sentence budget (goal 18)"`. Always `[]` on the correction path. |
| `used` | `Array<{ kind: string; id: string }>` | De-duplicated context lines cited by **kept** sentences only. `kind` is one of `'answer'` (id = `question_answers.id`), `'pattern'` (`behavior_patterns.id`), `'item'` (`raw_content.id`), `'fact'` (`assertions.id`), `'saved'` (`reference_items.id`), or `'said_today'` (**id is the earlier turn's `created_at` ISO timestamp, not a UUID**, `reply.ts:74`). Always `[]` on the correction path. |

Example:

```json
{
  "intent": "question",
  "reply": "You moved the Saturday run twice this month, both after late Fridays.",
  "cut": [{ "sentence": "Be kind to yourself.", "reason": "stock comfort, not about this person (goal 9)" }],
  "used": [{ "kind": "pattern", "id": "5b0f6c1e-1d2a-4c55-9a51-0f3c2b7e8d11" }, { "kind": "said_today", "id": "2026-10-20T13:02:11.410Z" }]
}
```

Correction path (`reply.ts:84-90`): when the model labels the message `correction`, `handleCorrection()` runs (section 4) and **may apply the correction immediately** (writes). `reply` is then one of: the `echo` text (applied), `You wrote "<quote>" on <YYYY-MM-DD>. Has that changed, or did I read it wrong?` (ask_own_words), `Which did you mean: "<a>", or "<b>"?` (confirm with candidates), or `Got it.` (not a correction / no candidates). **The candidate ids are not returned**, so the app cannot offer one-tap confirm from this route; it would have to call `POST /corrections` itself.

**Errors**

| status | body | when |
|---|---|---|
| 400 | `{ "error": "userId and text required" }` | missing/blank |
| 401/500 | see section 11 | secret |
| 500 | `{ "error": "<message>" }` | any thrown error: guard model failure (`guardSentences` does not catch, `src/writer/claim-guard.ts:54-65`), `readUnderstanding` DB error, correction failure. Search failure does **not** 500 (caught, `reply.ts:71`). |

**Side effects (in order)**

1. `raw_content` insert: `{ user_id, content_type: 'conversation', content: text, authorship: 'self', trust_class: 'own_words' }` (`reply.ts:61`). `processing_status` defaults to `pending`, so the ingestion pipeline will later read it as the person's own words.
2. `conversation_turns` insert, `role: 'person'`, with `raw_content_id` (`reply.ts:62`).
3. If the reply is non-empty: `conversation_turns` insert, `role: 'companion'`, `text: reply`, `used`, `created_at = now + 1 ms` (`reply.ts:109-113`).
4. Correction path only: writes from `applyCorrection` (section 4.3).

Both inserts ignore their errors (no check on the insert result).

**Latency / cost**: 1 embedding (search) + `search_person` RPC + `readUnderstanding` (about 11 queries) + 1 writer call (`ANTHROPIC_WRITER_MODEL`, maxTokens 500; retried once on failure) + 1 guard call (`ANTHROPIC_GUARD_MODEL`). Correction path: + search + 1 targeting call (writer model, maxTokens 120) + lineage reads. Several seconds. Not capped.

**Idempotency**: **not idempotent.** A retry inserts a second `raw_content` row and a second person turn, and may apply a correction twice (the second apply is mostly a no-op on already-retired rows). The door route should not auto-retry POSTs.

**Context rules** (`src/conversation/rules.ts`): reply budget = `max(1, min(4, ceil(words*2/20)))` sentences (`rules.ts:27-30`). `mayReveal` (`rules.ts:40-48`) hides automated/third-party items always, and silent-domain answers, extreme patterns and saved links unless the message is a question. Working memory is the last **18 hours** (rolling, `reply.ts:20`), at most 60 turns, 40 context lines.

### 1.2 `GET /conversation/:userId/today`

- Handler: `src/routes/conversation.ts:17-22`. No engine.
- userId: path param.
- Query: `conversation_turns` `select('role,text,created_at')`, `user_id = :userId`, `created_at >= now - 18h`, ordered by `created_at` ascending. **No limit, no tie-break on `id`** (the engine adds `.order('id')`, the route does not).

**Response 200**

```json
{ "turns": [
  { "role": "person", "text": "Dentist at 3 today, dreading it", "created_at": "2026-10-20T13:02:11.41+00:00" },
  { "role": "companion", "text": "Good luck at 3.", "created_at": "2026-10-20T13:02:11.411+00:00" }
] }
```

`role`: `'person' | 'companion'`. "Today" is a rolling 18-hour window, not a calendar day. **`used` and `raw_content_id` are not returned**, so sources for past companion turns cannot be shown without a route change. Errors: 500 `{ error }` on DB error.

### 1.3 `conversation_turns` table (`supabase/migrations/150_conversation_turns.sql:6-14`)

| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid NOT NULL → users ON DELETE CASCADE | |
| `role` | text NOT NULL | CHECK `('person','companion')` |
| `text` | text NOT NULL | |
| `raw_content_id` | uuid → raw_content ON DELETE SET NULL | person turns only |
| `used` | jsonb NOT NULL default `[]` | companion turns: `[{kind,id}]` |
| `created_at` | timestamptz NOT NULL default now() | |

Index `(user_id, created_at DESC)`. RLS on; service_role has full DML.

---

## 2. Daily briefs

### 2.1 `GET /briefs/:userId/latest`

- Handler: `src/routes/briefs.ts:9-14`. Reads `daily_briefs` `select('*')`, latest by `brief_date` desc, `maybeSingle`.
- Response: `{ "brief": <daily_briefs row, snake_case> | null }`. Errors: 500 `{ error }`.

```json
{ "brief": {
  "id": "0e7b...", "user_id": "9c1d...", "brief_date": "2026-10-20", "kind": "brief",
  "through_line": "Your week keeps circling back to the launch.",
  "spine_question_id": 2, "spine_movement": "strengthens",
  "items": [{ "text": "You wrote that the demo finally worked.", "why": "the launch is what you are building", "quote": "the demo finally worked end to end tonight", "sourceRef": { "raw_content_id": "a1b2..." } }],
  "dropped": 1, "model_version": "claude-sonnet-5-5", "cost_usd": 0.0123, "created_at": "2026-10-20T08:00:04.2+00:00"
} }
```

### 2.2 `POST /briefs/generate`

- Handler: `src/routes/briefs.ts:17-25`. Engine: `runDailyBrief(userId, { dryRun })` (`src/briefs/run-daily-brief.ts:93-146`), which dispatches to `runDailyBriefV2` when `dailyV2For(userId)` (`DAILY_PLANNER=v2`, or the id is in `DAILY_PLANNER_V2_USERS`; `run-daily-brief-v2.ts:20-23`).
- Request: `{ userId (truthy), dryRun? (coerced with !!) }`.
- **Not gated** by `users.daily_brief_enabled` or by the spend cap (only the cron checks those, `src/jobs/daily-brief.ts:7-25`).

**Response 200**: `BriefRun` (`run-daily-brief.ts:26-33`), camelCase:

| field | type | notes |
|---|---|---|
| `brief` | `VettedBrief` | see 2.5 |
| `briefDate` | string `YYYY-MM-DD` | UTC date of `now` |
| `costUsd` | number | |
| `cost` | `CostLine[]` | `{ provider: 'Anthropic'\|'OpenAI'\|'ElevenLabs'\|'Perplexity'\|'unknown', model, calls: number\|null, inputTokens, outputTokens, pricePerMTokIn, pricePerMTokOut, usd, estimatedAtFallback: boolean, units?: string }` (`src/pipelines/trace.ts:345-359`) |
| `materialCount` | number | v1: material items considered; v2: inbox items |
| `saved` | boolean | false on dryRun |

Note this is a **different shape** from `GET .../latest` (camelCase `VettedBrief` here vs the snake_case row there). The door route should normalise one of them.

Errors: 400 `{ error: 'userId required' }`; 500 `{ error }` (including `Could not save the brief: ...`).

**Side effects**: upsert into `daily_briefs` on `(user_id, brief_date)` (`run-daily-brief.ts:130-141`; v2 `run-daily-brief-v2.ts:59-63`). **Idempotent per UTC day** in the sense that a re-run replaces today's row; v1 re-runs use the same window as today's first run (`lastBriefAt` looks at earlier dates only, `run-daily-brief.ts:85-91`) so a re-run cannot replace a real brief with a quiet one. v2 has no such protection: its window starts at the latest brief's `created_at` including today's (`src/planner/daily.ts:91-93`), so a second v2 run the same day sees only what arrived since the first and can overwrite a full brief with a quiet one.

**Cost**: v1: one `ANTHROPIC_QUESTIONS_MODEL` call (maxTokens 3000), skipped entirely on a quiet day. v2: `readUnderstanding` + daily inputs + one writer call (maxTokens 2500) + one guard call. No embeddings, no TTS.

### 2.3 `PUT /briefs/:userId/enabled`

- Handler: `src/routes/briefs.ts:28-33`. Body `{ enabled }`; **anything other than literal `true` becomes `false`** (no 400). Updates `users.daily_brief_enabled`. Unknown userId still returns 200.
- Response: `{ "enabled": true }`. Errors: 500.
- Idempotent.

### 2.4 `daily_briefs` table (`supabase/migrations/128_daily_briefs.sql:11-29`)

`users.daily_brief_enabled BOOLEAN NOT NULL DEFAULT false` (line 11).

| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid NOT NULL → users CASCADE | |
| `brief_date` | date NOT NULL | UTC |
| `kind` | text NOT NULL | CHECK `('brief','quiet')` |
| `through_line` | text NOT NULL | v1: one sentence. **v2: the whole spoken brief text** goes here (`run-daily-brief-v2.ts:46`) |
| `spine_question_id` | smallint → canonical_questions | v2 always null |
| `spine_movement` | text | v1: model value, intended `strengthens\|weakens\|complicates\|contradicts` but not validated; v2: literal `'planner v2'` |
| `items` | jsonb NOT NULL default `[]` | see 2.5 |
| `dropped` | integer NOT NULL default 0 | v1: items failing quote check; v2: sentences cut by the guard |
| `model_version` | text | null when no model call |
| `cost_usd` | numeric(8,4) NOT NULL default 0 | |
| `created_at` | timestamptz NOT NULL default now() | |

UNIQUE `(user_id, brief_date)`. RLS on; revoked from anon/authenticated.

### 2.5 `VettedBrief` and item shapes

`src/briefs/daily-brief.ts:39-54`:

```ts
interface BriefItem { text: string; why: string | null; quote: string; sourceRef: { raw_content_id: string } }
interface VettedBrief { kind: 'brief' | 'quiet'; throughLine: string; spineQuestionId: number | null; spineMovement: string | null; items: BriefItem[]; dropped: number }
```

v1 rules (`vetBrief`, `daily-brief.ts:88-124`): at most `MAX_ITEMS + 1` = 5 items; at most one aside (`why: null`); every `quote` must be found in its source (`verifyExcerpt`); no em dashes; if no item with a `why` survives, the brief becomes quiet with default `throughLine` `"Nothing new since your last brief. I'll keep listening."`.

**v2 items are a different shape** (`run-daily-brief-v2.ts:48-53`), stored in the same column:

| item source | `planId` | `text` | `why` | `quote` | `sourceRef.raw_content_id` | extra |
|---|---|---|---|---|---|---|
| inbox (what they sent) | `inbox:<raw_content.id>` | 280-char preview | null | same preview | the raw_content id | |
| resurfaced saved link | `saved:<reference_items.id>` | title or url | `"goal:<uuid>"` or `"question:<n>"` (a machine reason, not prose) | their saving reason or `""` | **`""`** | |
| plan item | `pattern:<id>`, `answer:<id>`, `shift:<domain>:<metric>`, `goal:<id>`, `content:<n>` | **the item kind word** (`"pattern"`, `"answer"`, ...), not text | null | `""` | `evidence[0]` (an answer/pattern/raw id) or `""` | `register: 'stated'\|'asked'` |

So in v2 the readable brief is only in `through_line`; `items` are bookkeeping for novelty and lint. Rendering v2 items as v1 items will show the word "pattern" as text.

### 2.6 Audio for briefs

**There is no TTS for briefs anywhere in the agent.** ElevenLabs is called only from the podcast pipelines (`src/pipelines/podcast.ts:511-535`, `src/pipelines/podcast-v2.ts:82-92`). Briefs record `elevenlabs_chars: 0` (`run-daily-brief.ts:123`). Migration 128's comment says "Text first; audio later". If the app needs spoken briefs, the backend (or a new agent route) must synthesise `through_line`.

Cron: 08:00 UTC, only with `ENABLE_DAILY_BRIEF=true`, only for users with `daily_brief_enabled`, skipping anyone over the spend cap (`src/index.ts:99-104`, `src/jobs/daily-brief.ts`).

---

## 3. Hypotheses

### 3.1 `POST /hypotheses/:userId/:id`

- Handler: `src/routes/hypotheses.ts:10-15`. Engine `answerHypothesis` (`src/hypotheses/offer.ts:54-60`).
- Body: `{ verdict: 'yes' | 'no' }` (exact strings).
- Response 200: `{ "status": "confirmed" }` or `{ "status": "declined" }`.
- Errors: 400 `{ error: 'verdict "yes" or "no"' }`; **404 for every thrown error**, including DB errors (`hypotheses.ts:14`): body `{ error: 'answerHypothesis: no open hypothesis with that id for this person' }` or `{ error: 'answerHypothesis: <db message>' }`.
- Side effect: `hypotheses.status` and `status_at` updated, only where `user_id` matches and status is `stored` or `offered`.
- Idempotency: a second call 404s (the row is no longer open). Treat 404-after-success as success in the door route, or read state first.

### 3.2 `GET /hypotheses/:userId/:id/why`

- Handler: `src/routes/hypotheses.ts:18-25`. Scoped by `id` and `user_id`.
- Response 200:

| field | type | notes |
|---|---|---|
| `question` | string | the hypothesis, phrased as a question |
| `status` | `'stored'\|'offered'\|'confirmed'\|'declined'\|'expired'` | |
| `framework` | `{ name: string; source: string; wonders: string }` or `{ name: string }` | full form for known ids; otherwise `name` is the raw framework id |
| `rationale` | string \| null | |
| `restsOn` | `Array<{ kind: string; id: string }>` | **ids only, no text.** Kinds are claim kinds (`answer`, `pattern`, `why`, `fact`). To show what it rests on, the door must resolve each id (e.g. `GET /search/:userId/source/answer/:id`). |

```json
{ "question": "Could the Saturday runs be more about time alone than fitness?", "status": "offered",
  "framework": { "name": "Self-determination theory", "source": "Deci & Ryan; Ng et al. 2012 meta-analysis", "wonders": "which need (autonomy, competence, connection) an activity feeds" },
  "rationale": "Runs cluster on days with no meetings.", "restsOn": [{ "kind": "pattern", "id": "5b0f..." }] }
```

Framework ids and values (`src/hypotheses/validate.ts:8-13`): `sdt`, `flow`, `intention_gap`, `habit_cue`, `approach_avoid`.

Errors: 404 `{ error: 'not found' }`; 500.

**Gap: there is no route that lists hypotheses or the one currently offered.** The app can only learn a hypothesis id from a v2 episode's `podcast_episodes.outline.plan.hypothesis` (`Offer`, below).

### 3.3 `hypotheses` table (`supabase/migrations/149_hypotheses_and_dials.sql:11-25`)

| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid NOT NULL → users CASCADE | |
| `framework` | text NOT NULL | ids above |
| `domain_id` | text | question domain id |
| `question` | text NOT NULL | |
| `rationale` | text | |
| `supports` | jsonb NOT NULL default `[]` | `[{kind, id}]` |
| `status` | text NOT NULL default `'stored'` | CHECK `('stored','offered','confirmed','declined','expired')` |
| `offered_count` | integer NOT NULL default 0 | |
| `last_offered_at` | timestamptz | |
| `status_at` | timestamptz NOT NULL default now() | |
| `model_version` | text | |
| `created_at` | timestamptz NOT NULL default now() | |

Lifecycle: proposed and stored weekly by the v2 episode pipeline (`podcast-v2.ts:45-58`); offered at most twice, 14 days apart, only while everything it rests on is still in the understanding contract; marked offered only if the sentence survived the fact check (`podcast-v2.ts:110`); expired after `expire_days` by the daily-ingestion cron (`src/jobs/daily-ingestion.ts:69`, only with `ENABLE_AGENT_CRONS`).

### 3.4 `offer.ts` signatures (`src/hypotheses/offer.ts`)

```ts
interface HypothesisDial { speak: boolean; min_appetite: number; per_episode: number; expire_days: number }   // :13
const DIAL_DEFAULT = { speak: false, min_appetite: 2, per_episode: 1, expire_days: 30 }                        // :14
readHypothesisDial(db?): Promise<HypothesisDial>                                                               // :17-21  missing row or error => DIAL_DEFAULT
interface Offer { id: string; question: string; framework: string; frameworkName: string; rationale: string; evidence: string[] }  // :23
type Row = { id; question; framework; rationale: string|null; supports: Array<{kind;id}>; offered_count: number; last_offered_at: string|null; status: string; created_at: string }  // :24 (not exported)
chooseOffer(rows: Row[], c: UnderstandingContract, appetite: number, dial: HypothesisDial, now: Date): Offer | null  // :27-39 pure
loadOfferable(userId: string, db?): Promise<Row[]>          // :41-45 status in (stored, offered), limit 100; DB error => []
markOffered(userId, id, db?, now?): Promise<void>            // :47-51
answerHypothesis(userId, id, verdict: 'yes'|'no', db?, now?): Promise<{ status: string }>  // :54-60
expireHypotheses(userId, dial, db?, now?): Promise<number>   // :63-67
```

`chooseOffer` returns null unless `dial.speak` and `appetite >= dial.min_appetite` and `per_episode >= 1`. `per_episode > 1` is not honoured (at most one per episode). `Offer.evidence` is the text of each supporting claim from the contract.

### 3.5 `product_dials` and the `speak` dial

`149_hypotheses_and_dials.sql:31-36`: `key TEXT PK, value JSONB NOT NULL, note TEXT, updated_at timestamptz`. Seeded row (lines 42-44): key `hypotheses`, value `{"speak": false, "min_appetite": 2, "per_episode": 1, "expire_days": 30}`. `speak` is the founder's master switch for saying hypotheses out loud; it is read on every v2 episode (no cache, no route to change it; change it in SQL). It is the only dial in use. Not user-scoped.

---

## 4. Corrections

### 4.1 `POST /corrections`

- Handler: `src/routes/corrections.ts:14-19`. Engine `handleCorrection(userId, text)` (`src/corrections/target.ts:51-72`). `usage` stripped.
- Request: `{ userId (truthy), text (non-blank string, trimmed) }`.
- Response 200: one of four outcomes (`CorrectionResult`, `target.ts:34-38`, minus `usage`):

```ts
interface Candidate { n: number; kind: 'fact' | 'answer' | 'pattern' | 'why'; id: string; text: string }   // target.ts:16
| { outcome: 'not_a_correction' }
| { outcome: 'applied'; target: Candidate; retired: number; echo: string }
| { outcome: 'confirm'; candidates: Candidate[] }            // 0 to 3 candidates; [] when nothing matched
| { outcome: 'ask_own_words'; target: Candidate; quote: string; writtenOn: string | null }  // quote <= 200 chars; writtenOn "YYYY-MM-DD"
```

Candidates come from `search_person` hits of kind `fact` or `answer` (snippet text) plus up to 50 live patterns (label); `kind: 'why'` never appears as a candidate in practice. `n` is a 1-based index in the candidate list. `echo` example: `Got it. I'll stop saying "Training for the half marathon", and 2 things built on it.`

Examples:

```json
{ "outcome": "confirm", "candidates": [
  { "n": 3, "kind": "answer", "id": "c0ff...", "text": "What have they quit, and when? Running, in September" },
  { "n": 1, "kind": "fact", "id": "f00d...", "text": "quit or stopped: running" } ] }
```
```json
{ "outcome": "ask_own_words", "target": { "n": 1, "kind": "fact", "id": "f00d...", "text": "stated goal: half marathon" }, "quote": "I am going to run the half in March", "writtenOn": "2026-09-02" }
```

Errors: 400 `{ error: 'userId and text required' }`; 500 `{ error }` (search RPC failure is **not** caught here, unlike in conversation; `target.ts:28`).

Side effects: only on `applied` (section 4.3). Cost: 1 embedding + RPC + 1 writer-model call (maxTokens 120, retried once; on double failure returns `confirm` with the top 3 rather than guessing) + lineage reads. Idempotency: a repeat may re-apply; re-applying an already-retired target is mostly harmless but re-upserts `claim_rejections` and re-counts.

### 4.2 `POST /corrections/confirm`

- Handler: `src/routes/corrections.ts:27-32`.
- Request:

| field | type | rule |
|---|---|---|
| `userId` | string | truthy |
| `kind` | `'fact'\|'answer'\|'pattern'\|'why'` | must be in the set |
| `id` | string | `typeof id === 'string'` |
| `note` | string? | stored on `claim_rejections.note` |
| `mode` | `'changed'` or anything | `'changed'` = true then, not now: retire without blacklisting; anything else = `'wrong'`: retire and record a rejection so it is never resurrected |

- Response 200: `{ "outcome": "applied", "retired": 3 }` (count of claims retired, including the target). **No `target`/`echo`**, unlike `POST /corrections`'s `applied`.
- Errors: 400 `{ error: 'userId, kind and id required' }`; 500.
- Ownership is not pre-checked: an id that is not this user's still returns `{ outcome: 'applied', retired: 1 }` (the plan always contains the target, `src/corrections/retract.ts:39`), while the writes match nothing because they are scoped by `user_id`.

### 4.3 What applying writes (`src/corrections/apply.ts:74-108`)

1. Mode `wrong`: upsert `claim_rejections` on `(user_id, claim_kind, claim_key)` for facts and answers (`apply.ts:25-40`). Patterns and whys are protected by their `user_rejected` status instead.
2. For each claim in the retraction plan (target first, then everything whose only support ran through it, `retract.ts:30-65`):
   - fact: `assertions.status='retired', valid_to=now`
   - pattern: `behavior_patterns.status = 'user_rejected'` (target) or `'retired'` (knock-on)
   - why: `behavior_pattern_whys.status`, `retired_at`, `retirement_reason`
   - answer: `question_answers.status='retired', retired_at`, plus `user_verdict='rejected', verdict_at` for the target
3. Surviving answers that lost evidence: `answer_evidence.retired_at = now` on the dropped rows.

Never deletes. Migration 148 triggers keep a rejected fact/answer retired if any writer re-creates it.

**Likely production failure:** migration 121 revokes all privileges on `question_answers` and `answer_evidence` from `service_role` and grants back only SELECT (`121_question_answers.sql:431-432`), and `tests/migrations.test.ts` asserts the service key cannot write `question_answers` directly. No later migration grants UPDATE. Steps 2 (answer) and 3 use direct `.update()` with the service key, so correcting an answer, or any correction that weakens an answer, should fail with 42501 and surface as a 500 after the rejection row (and possibly other retirements) are already written. Tests pass because PGlite runs as superuser. Worth verifying against production before shipping the corrections UI.

---

## 5. Search

### 5.1 `POST /search/sources`

- Handler: `src/routes/search.ts:13-18`. Engine `searchPerson(userId, q, { limit: 15 })` (`src/search/search.ts:13-20`), which calls RPC `search_person` (current definition `supabase/migrations/147_search_saved_by_meaning.sql:8-63`).
- Request: `{ userId (truthy), q (non-blank string) }`. `q` is **not** trimmed in the echo.
- Response 200:

```ts
{ query: string; sources: SearchHit[] }
interface SearchHit { kind: 'item' | 'fact' | 'answer' | 'saved'; id: string; snippet: string; happened_at: string | null; score: number }  // search.ts:11
```

| kind | id is | snippet | happened_at |
|---|---|---|---|
| `item` | `raw_content.id` | first 400 chars of `content` | `raw_content.created_at` (**not** `content_date`) |
| `fact` | `assertions.id` | `"<predicate with spaces>: <object_value.raw or .normalized>"` | `event_time` or `observed_at` |
| `answer` | `question_answers.id` | `"<question text> <answer>"` | `last_moved_at` |
| `saved` | `reference_items.id` | `"<title> <summary> <intent> <url>"` | `created_at` |

`score` is a reciprocal-rank-fusion number (sum of `1/(60+rank)`, typically 0.01 to 0.05); only useful for ordering. At most 10 items and 5 of each other kind before the overall limit. Only active, non-contradicted facts and active, non-rejected answers are searchable. Items are searched regardless of trust class (newsletters included); no `trust_class` is returned.

```json
{ "query": "half marathon", "sources": [
  { "kind": "item", "id": "a1b2...", "snippet": "Signed up for the half marathon in March...", "happened_at": "2026-08-04T19:22:01+00:00", "score": 0.0325 },
  { "kind": "answer", "id": "c0ff...", "snippet": "What have they said they want? To run a half marathon", "happened_at": "2026-10-01T07:00:00+00:00", "score": 0.0164 } ] }
```

Errors: 400 `{ error: 'userId and q required' }`; 500. Cost: one OpenAI embedding (if embedding fails, keyword-only). About 1 s. Read-only, idempotent.

### 5.2 `POST /search/answer`

- Handler: `src/routes/search.ts:21-26`. Engine `searchAndAnswer(userId, q)` (`src/search/answer.ts:74-112`). `usage` stripped.
- Request: same as 5.1.
- Response 200 (`SearchResult`, `answer.ts:21-28`, minus `usage`):

| field | type | notes |
|---|---|---|
| `query` | string | |
| `summary` | string | 2 to 5 sentences **with `[n]` citation markers left in** (kept sentences are the model's original strings, `answer.ts:106`), or an abstain sentence |
| `abstained` | boolean | |
| `sources` | `Array<{ n: number; kind: 'item'\|'fact'\|'answer'\|'saved'; id: string; date: string \| null; snippet: string }>` | `n` 1-based, matches `[n]` in `summary`; `date` is `YYYY-MM-DD`. **Field names differ from `/search/sources`** (`date` vs `happened_at`, no `score`, adds `n`). Up to 15. |
| `cut` | `Array<{ sentence: string; reason: string }>` | sentences the guard removed (citations stripped) |

Abstain texts (fixed): `"Nothing in your bank speaks to this yet."` (no sources), `"The answer could not be written this time; the sources are below."` (writer failed twice), `"Nothing in your bank really answers this."`, or the model's own `why`.

Errors: 400; 500 (guard failure is not caught). Cost: rewrite (`ANTHROPIC_TIME_CATEGORY_MODEL`, maxTokens 200) + up to 4 searches (1 with embedding) + writer (`ANTHROPIC_WRITER_MODEL`, maxTokens 3000, one retry) + guard. Several seconds. Not capped. Read-only.

### 5.3 `GET /search/:userId/source/:kind/:id`

- Handler: `src/routes/search.ts:29-34`. Engine `openSource` (`src/search/source.ts:14-38`). Scoped by `user_id` on the main row.
- `kind` must be `item | fact | answer | saved`.
- Response 200: `{ source: OpenedSource }`, `OpenedSource = { kind; id; date: string|null; title: string; body: string; extra?: Record<string, unknown> }` (`source.ts:12`):

| kind | date | title | body | extra |
|---|---|---|---|---|
| item | `created_at` (YYYY-MM-DD) | content_type with spaces (e.g. `"journal entry"`) | full `content` | none |
| fact | event_time or observed_at | predicate with spaces | `object_value.raw` or `.normalized` | `{ from: [{ quote: string\|null, itemId: string\|null }] }` from `assertion_evidence` (that lookup is not user-scoped, but keyed by an assertion already checked) |
| answer | last_moved_at | the canonical question text | answer | none |
| saved | created_at | title or url | summary or `""` | `{ url, yourReason: intent }` |

Errors: 400 `{ error: 'unknown kind' }`; 404 `{ error: 'not found' }` (also returned on DB errors, since `openSource` ignores them). Read-only.

---

## 6. Onboarding

### 6.1 `POST /onboarding/interpret`

- Handler: `src/routes/onboarding.ts:26-78`. Engine `runMagicMoments({ userId, keep })` (`src/pipelines/magic-moments.ts:32+`, model `ANTHROPIC_COOK0_MODEL`, maxTokens 4000) then `writeNewDocumentVersion` (`src/agents/cook0-agent.ts:271`).
- Request: `{ userId (truthy), keep?: number (default 2, not validated) }`.
- Response 200:

```ts
{ moments: MagicMoment[]; documentVersion: number | null; notes?: string; hadOnboarding: boolean; integrationTypes: string[]; note?: string }
interface MagicMoment { structure: 'transferred_capability'|'defended_fear'|'contradiction'|'the_gap'|'already_knowing'|'the_condition'; title: string; pattern: string; evidence: string; reframe: string; future_self_line: string | null; hypothesis: string; strength: number }  // src/types/index.ts:480-497
```

`note` only on the zero-moments branch (`"No magic moments produced — likely thin onboarding + no integrations."`, which contains an em dash). `integrationTypes` are raw content types from the set `healthkit, screen_time, google_docs, calendar, social_web_research, apple_music, photos, contacts`.
- Side effects: a new `user_understanding` version (legacy Cook 0 document) with `magic-moment:*` emerging dimensions. Not idempotent (each call writes a new version). Errors: 400, 500.
- This is the **legacy** path; nothing in the v2 brain reads `user_understanding`.

### 6.2 `POST /onboarding/goals`

- Handler: `src/routes/onboarding.ts:137-156`. Engine `extractStatedGoals(answersText)` (`src/onboarding/stated-goals.ts:52-78`), model `ANTHROPIC_QUESTIONS_MODEL`, maxTokens 2000.
- Request: `{ userId (truthy, used only for logging), answersText: string }` (an empty string is allowed and returns no goals with no model call).
- Response 200:

```ts
{ goals: StatedGoal[]; dropped: number; cost: CostLine[] }
interface StatedGoal { title: string; description: string; reasoning: string; quote: string }  // stated-goals.ts:21-27; max 5; quote verified present in answersText
```

```json
{ "goals": [{ "title": "Run a half marathon", "description": "Finishing a half in the spring.", "reasoning": "You said it is the first thing you have finished in years.", "quote": "I want to finally finish a half marathon this spring" }], "dropped": 0,
  "cost": [{ "provider": "Anthropic", "model": "claude-sonnet-5-5", "calls": 1, "inputTokens": 812, "outputTokens": 140, "pricePerMTokIn": 3, "pricePerMTokOut": 15, "usd": 0.0045, "estimatedAtFallback": false }] }
```
- **Saves nothing** (comment line 135). Errors: 400 `{ error: 'userId and answersText required' }`, 500. Idempotent in effect (no writes; model output may vary).

### 6.3 `GET /onboarding/readiness/:userId`

- Handler: `src/routes/onboarding.ts:163-170`. Engine `loadOnboardingFacts` + `stageFor` (`src/onboarding/pipeline.ts:44-76`).
- Response 200: `{ stage: OnboardingStage; facts: OnboardingFacts }`.

```ts
type OnboardingStage = 'reading' | 'understanding' | 'making_episode' | 'ready'   // pipeline.ts:22
interface OnboardingFacts {               // pipeline.ts:24-37
  outstandingJobs: number;   // integration_jobs in queued|leased|running
  outstandingRows: number;   // raw_content in pending|processing
  lastArrivalAt: string | null;   // latest raw_content.created_at
  startedAt: string;         // users.created_at (or now if the user row is missing)
  answers: number;           // question_answers rows, any status
  episodesReady: number;     // podcast_episodes with status 'ready'
  episodeRunning: boolean;   // a podcast trace 'running' started in the last 15 min
}
```

`facts` is the raw evidence used to compute the stage, intended for debugging/progress, not a stable contract. Stage rule (`stageFor`): `reading` until nothing is outstanding and nothing arrived for 2 minutes (or 20 minutes since signup), then `understanding` until any answer exists, then `making_episode` until a ready episode exists, then `ready`. Read-only, idempotent, cheap (7 count queries). Errors: 500.

### 6.4 `POST /onboarding/advance`

- Handler: `src/routes/onboarding.ts:173-181`. Engine `advanceOnboarding(userId, defaultAdvanceDeps)` (`pipeline.ts:88-106`; deps `src/jobs/onboarding-pipeline.ts:9-14`).
- Request: `{ userId }`.
- Response 200: `{ stage: OnboardingStage; action: AdvanceAction }`, `AdvanceAction = 'waiting_for_reading' | 'ran_first_pass' | 'made_episode' | 'episode_already_running' | 'over_spending_limit' | 'nothing_to_do'` (`pipeline.ts:86`). `stage` is the stage **before** the step ran.
- Side effects: `understanding` → runs the first pass (writes `question_answers` via `record_answer`, many model calls); `making_episode` → runs a full episode (`runPodcast`, TTS, `podcast_episodes` insert). Synchronous: can take minutes (server timeout is 600 s, `src/index.ts:87`).
- Idempotency: safe to call repeatedly in sequence, **but not concurrently**: the cron's in-process `inFlight` lock (`onboarding-pipeline.ts:18`) is not used by this route, so an app poll plus the cron tick can run two first passes or two episodes at once. `episodeRunning` only protects after the trace row exists.

"facts" in this API means `OnboardingFacts` above, nothing to do with `assertions`.

---

## 7. Podcasts

### 7.1 `POST /podcasts/generate`

- Handler: `src/routes/podcasts.ts:13-51`. Engine `runPodcast` (`src/pipelines/podcast.ts:360-629`), which dispatches to `runPodcastV2` (`src/pipelines/podcast-v2.ts:30-123`) when `EPISODE_PLANNER=v2` or the user is in `EPISODE_PLANNER_V2_USERS` (`podcast.ts:72-75`).
- Request (`PodcastOptions`, `podcast.ts:35-50`; nothing validated except `userId`):

| field | type | notes |
|---|---|---|
| `userId` | string | required |
| `daysBack` | number? | legacy only, default 14; ignored by v2 (28-day window) |
| `skipTTS` | boolean? | `!!` |
| `dryRun` | boolean? | `!!`; skips spend check, TTS and all writes except traces (memory-only trace) |
| `persona` | `'thoughtful_friend'\|'wise_mentor'\|'energetic_host'`? | passed through unchecked |
| `notes` | string? | trace note |

- Response 200:

| field | type | notes |
|---|---|---|
| `traceId` | string \| null | `pipeline_run_traces.id`; null on dry run |
| `episodeId` | string \| null | null on dry run |
| `title` | string | |
| `description` | string | v2: first line of the summary, ≤280 chars |
| `mood` | string | v2: always `"reflective"`; legacy: model value |
| `durationSeconds` | number | **estimate** (words/150 × 60), not measured from audio |
| `audioUrl` | string \| null | see 7.3 |
| `script` | string | full script |
| `summary` | string | |
| `outlineV2` | `OutlineV2` or **absent** | v2 runs return `undefined`, so the key disappears from JSON. `v2` (plan + guard stats) and `cost` from the engine are **not** passed through |

```json
{ "traceId": "7a1e...", "episodeId": "e9d2...", "title": "The week the plan met the calendar", "description": "You said Tuesdays were for writing...",
  "mood": "reflective", "durationSeconds": 412, "audioUrl": "https://<project>.supabase.co/storage/v1/object/public/podcast-audio/podcasts/9c1d.../7a1e....mp3",
  "script": "...", "summary": "..." }
```

- Errors: 400 `{ error: 'userId required' }`; **429** `{ error: "Daily limit reached: $15.20 of $15 in the last 24 hours. Try again tomorrow.", spentUsd: number, capUsd: number }`; 500 `{ error }`, including expected product outcomes: legacy `"Not enough data to generate a podcast episode. ..."`, v2 `"Nothing this week clears the bar to be said: a quiet week (planner v2 never pads)."` and `"The fact check cut every sentence; nothing safe to say."`. The door should map those to a non-error "quiet week" state.
- Side effects: `pipeline_run_traces` row; `podcast_episodes` insert (`status: 'ready'`, `generation_type: 'weekly'` even for on-demand runs); audio upload; v2 also stores new `hypotheses` and may mark one offered; legacy marks `episode_feedback.processed` and appends feedback to `user_preferences.directives`.
- Cost/latency: the most expensive route. v2: understanding + said-vs-did judge + group naming + hypothesis proposal + writer + guard + OpenAI summary + embedding + ElevenLabs TTS of the whole script (about $0.30 per 1k chars as priced in `trace.ts:57`). Minutes; server timeout 600 s.
- Idempotency: **none.** Every call makes a new episode with the next `episode_number`.

### 7.2 `GET /podcasts/:userId`

- Handler: `src/routes/podcasts.ts:53-63`. `select('*')` from `podcast_episodes`, newest first, limit 50.
- Response: `{ episodes: <podcast_episodes rows, snake_case>[] }`.
- **Returns `summary_embedding`**, a 3072-float vector serialised as a string, for every row (about 30 to 40 KB per episode, up to 50 rows), plus the full `script` and `outline`. The door route should project columns or the agent route should change.
- No status filter: `generating`/`failed` rows would be included (current writers only insert `ready`).

### 7.3 `podcast_episodes` columns and audio

The table is created by the **retrospect-main (backend) repo**, not this one: the vendored copy is `tests/fixtures/base-schema.sql` ("A verbatim copy of retrospect-main/supabase/combined_migration.sql"). This repo only adds `summary TEXT` and `summary_embedding vector(3072)` (`supabase/migrations/100_agent_extensions.sql:41-45`).

| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid NOT NULL → users CASCADE | |
| `title` | text NOT NULL | |
| `description` | text | |
| `script` | text NOT NULL | |
| `audio_url` | text | |
| `duration_seconds` | integer | estimate |
| `mood` | text | |
| `generation_type` | text default `'weekly'` | CHECK `('weekly','on_demand','milestone')`; agent always writes `weekly` |
| `status` | text default `'generating'` | CHECK `('generating','ready','failed')`; agent inserts `ready` only |
| `insight_ids` | uuid[] | legacy |
| `goal_ids` | uuid[] | legacy |
| `research_citations` | jsonb default `[]` | legacy: `[{source, url?}]` |
| `outline` | jsonb default `{}` | legacy: `OutlineV2`; v2: `{ planner: 'v2', style, plan: EpisodePlan }` |
| `episode_number` | integer | count of ready episodes + 1 (racy) |
| `covers_period_start`, `covers_period_end` | timestamptz | |
| `previous_episode_id` | uuid → podcast_episodes | legacy only |
| `topics_covered` | text[] | legacy: segment titles; v2: item kinds (`"pattern"`, `"answer"`...) |
| `error_message` | text | |
| `metadata` | jsonb | legacy `{word_count, voice_persona, onboarding_profile_id, tool_call_count}`; v2 `{planner:'v2', writer_style, voice_persona, word_count, guard, withheld}` |
| `summary` | text | added by 100 |
| `summary_embedding` | vector(3072) | added by 100 |
| `created_at`, `updated_at` | timestamptz | |

**OutlineV2** (legacy path only; `src/types/index.ts:229-278`):

```ts
interface OutlineV1 { theme: string; segments: OutlineV1Segment[]; estimatedMinutes: number }
interface OutlineV1Segment { title: string; type: string; insightIds: string[]; goalIds: string[]; observationIds?: string[]; talkingPoints: string[]; estimatedSeconds: number }
interface OutlineV2 extends OutlineV1 { historicalConnections: { description: string; insightIds?: string[]; observationIds?: string[]; previousEpisodeIds?: string[] }[]; notRealizedYet: { patternType?: PatternType; pattern: string; evidenceObservationIds: string[]; hintApproach: string }[]; researchFindings: { query: string; summary: string; citations: { source: string; url?: string }[] }[]; toolCallsSummary?: string }
type PatternType = 'hidden_strength'|'distortion_habit'|'discounting_system'|'thought_behavior_cycle'|'progress_signal'|'self_esteem_blocker'
```

**v2 plan** (`src/planner/plan.ts:23-43`), stored at `outline.plan`:

```ts
interface PlanItem { id: string; kind: 'pattern'|'answer'|'shift'|'said_vs_did'|'content'; register: 'stated'|'asked'; facts: Record<string, unknown>; evidence: string[] }
interface EpisodePlan { spine: PlanItem | null; items: PlanItem[]; reflection: { whyId: string; patternId: string; mechanism: string } | null; hypothesis?: Offer | null; withheld: Array<{ id: string; why: string }>; silent: string[] }
```

**Chapters: there are none.** No chapter, segment-timing or timestamp data exists in either path (`git grep chapters` finds nothing). Legacy segments carry `estimatedSeconds` from the outline, not from audio. v2 writes no timing at all. Chapters would need new work (e.g. per-section TTS or ElevenLabs timestamps).

**audioUrl**: uploaded to Supabase Storage bucket **`podcast-audio`** at path `podcasts/<userId>/<traceId or Date.now()>.mp3`, `contentType: audio/mpeg`, `upsert: true`, and the URL comes from `getPublicUrl()` (`podcast.ts:522-532`, `podcast-v2.ts:87-89`). It is a **public, unsigned, non-expiring URL**; the bucket is expected to be public (`scripts/doctor.ts:340`). Anyone with the URL can fetch the audio, and the path contains the user id. If upload fails, `audioUrl` is null and the episode is still saved.

---

## 8. Feedback, settings, preferences, notifications

### 8.1 `POST /feedback/episodes/:episodeId`

- Handler: `src/routes/feedback.ts:11-27`. No engine.
- Body: `{ userId (truthy), text (truthy, not type-checked), rating?: 1..5, source?: 'manual'|'voice'|'tap' }`. `rating`/`source` validated only by DB CHECKs (bad values → 500 with the Postgres message).
- Response 200: `{ feedback: <episode_feedback row> }` with columns `id, user_id, episode_id, feedback_text, rating, source, processed, metadata, created_at` (`100_agent_extensions.sql:93-103`).
- Episode ownership is **not** checked: a user can attach feedback to any episode id. Not idempotent (each call inserts).
- Effects downstream: legacy podcast folds unprocessed feedback into the next script and into `user_preferences.directives`; appetite reads ratings ≤2 as discomfort and ≥4 as engagement.

`GET /feedback/episodes/:episodeId` (`feedback.ts:29-37`) exists too and is **completely unscoped by user**: it returns every feedback row for that episode id.

### 8.2 Settings (`src/routes/settings.ts`)

| route | lines | request | response |
|---|---|---|---|
| `GET /settings/:userId/ambient` | 20-25 | - | `{ enabled: boolean, effective: boolean }`; `enabled` is `users.ambient_enabled !== false` (true for an unknown user) |
| `PUT /settings/:userId/ambient` | 12-17 | `{ enabled: boolean }` (strict) | same shape; 400 `{ error: 'enabled (true/false) required' }` |
| `GET /settings/:userId/appetite` | 28-31 | - | `{ level: 0\|1\|2\|3, source: 'stated'\|'inferred', reasons: string[], suggested?: { level, reasons: string[], capped: string\|null, at: string }, levels: Record<'0'\|'1'\|'2'\|'3', string> }` |
| `PUT /settings/:userId/appetite` | 34-39 | `{ level: 0\|1\|2\|3\|null }` (strict; null hands back to inference) | same as GET; 400 `{ error: 'level 0-3, or null' }` |
| `GET /settings/:userId/learning` | 42-45 | - | `{ current: { at: string, arms: ArmStat[] } \| null, history: Array<{at, arms}>, inUse: boolean }`, `ArmStat = { arm: string; asked: number; answered: number; rate: number; weight: number }` (`src/learning/reception.ts:15`) |

- `effective = enabled && !masterOff()`, where the master switch is env `AMBIENT_MASTER=off` (`src/ambient/switch.ts:16`).
- Appetite level texts (`src/appetite/appetite.ts:12-17`): 0 "Just what happened: facts, patterns, what you said vs what you did"; 1 "Gentle questions: one question about why, now and then"; 2 "Honest observations: gaps named plainly, guesses asked as questions"; 3 "Don't hold back: direct challenge, always from evidence". `reasons` is `['you chose this']` when stated. JSON keys of `levels` are strings `"0"`..`"3"`.
- Learning `arm` values: `why`, `hypothesis:<framework>`, `answer:<domainId>`. `inUse` reflects env `ENABLE_LEARNING`.
- **There is no `PUT /settings/:userId/learning`.** The only learning write is the daily cron (`refreshLearning`).
- Storage: `users.ambient_enabled` (migration 141, default TRUE); appetite at `user_preferences.metadata.appetite`; learning at `user_preferences.metadata.learning`.
- PUT ambient on an unknown user returns 200. Appetite PUT on an unknown user tries to insert a `user_preferences` row → FK error → 500.
- Idempotent (all PUTs are set-to-value).

### 8.3 Preferences (`src/routes/preferences.ts`)

- `GET /preferences/:userId` (7-15): `{ preferences: <user_preferences row> | null }`. Row columns (`100_agent_extensions.sql:51-65`): `id, user_id (UNIQUE), tone: text|null, trusted_voice_description: text|null, focus_areas: text[], avoid_topics: text[], directives: jsonb [{date, text, source: 'feedback'|'manual'}], metadata: jsonb, created_at, updated_at`. `metadata` includes the agent's internal `appetite`, `learning` and optionally `authorised_actions`, so the GET leaks internal state; project it in the door.
- `PUT /preferences/:userId` (17-54): body `{ tone?, trusted_voice_description?, focus_areas?, avoid_topics?, directives? }`. **Full replace, not a patch**: any omitted field is written as null/`[]` (lines 27-34), so a client that sends only `tone` wipes `directives` (which hold folded episode feedback). `metadata` is left alone. No validation, no try/catch around the first read. Response `{ preferences: row }`; 500 on error.

### 8.4 `POST /notifications/generate`

- Handler: `src/routes/notifications.ts:25-97`. Model `ANTHROPIC_COOK_B_MODEL`, maxTokens 500.
- Body: `{ userId }`.
- Response 200:

```json
{ "morning": { "title": "...", "body": "..." }, "evening": { "title": "...", "body": "..." }, "referenced": "the Tuesday writing block", "hadData": true }
```
`referenced: string | null`. Fallback text when the model omits fields: title `"A note about your week"`, body `"Want to hear what I noticed?"`.
- Errors: 400 `{ error: 'userId required' }`; **404 `{ error: 'user not found' }`** (the only route that checks); 500.
- Reads the **legacy** tables `observations` and `insights` (last 7 days) plus the latest ready episode. In the default facts-only extractor mode (`EXTRACTOR=facts`, `src/config.ts:56`) nothing writes observations or insights any more (`src/pipelines/legacy-writes.ts` header), so for new users this route mostly sees only the episode summary. No writes; not idempotent in content.

---

## 9. Engines without routes

### 9.1 `buildPortrait` (`src/brain/portrait.ts:122-145`)

```ts
buildPortrait(userId: string): Promise<PortraitDocument>
type PortraitSlot = 'current_goals'|'current_state'|'live_tensions'|'significant_people'|'open_threads'|'self_talk_now'|'what_changed'
interface PortraitBlock { slot: PortraitSlot; lines: string[]; sourceAssertionIds: string[]; sourcePatternIds: string[]; populated: boolean }
interface PortraitDocument { blocks: Record<PortraitSlot, PortraitBlock>; builtAt: string; emptySlots: PortraitSlot[] }
```
Populated slots: `current_goals` (facts `stated_goal`), `current_state` (`felt`), `self_talk_now` (`said_about_self`, rendered in quotes), `live_tensions` (live promotable pattern labels). `significant_people`, `open_threads`, `what_changed` are **always empty** today. Max 6 lines per block. Reads only; uses the global client (no `db` parameter). Line text comes from `object_value.text ?? object_value.normalized` (`portrait.ts:47-50`), while search/correction code reads `object_value.raw ?? .normalized`: the two disagree on which key holds the human text.

### 9.2 `readUnderstanding` (`src/understanding/read.ts:113-135`)

```ts
readUnderstanding(userId: string, db?: SupabaseClient, now?: Date): Promise<UnderstandingContract>
interface UnderstandingContract { userId: string; asOf: string /* YYYY-MM-DD */; answers: AnswerItem[]; silent: Array<{ domainId: string; label: string }>; patterns: PatternItem[]; whys: WhyItem[]; goals: GoalItem[]; shifts: Shift[]; time: { categories: WeekTime[]; otherShare: number; weeksOfBaseline: number }; moves: { since: string | null; items: AnswerMove[] } }
interface AnswerItem { kind: 'answer'; id: string; questionId: number; question: string; domainId: string; answer: string; confidence: number /* 0..1, 2dp */; sources: number; confirmed: boolean; register: 'stated'|'asked'; lastMovedAt: string | null }
interface PatternItem { kind: 'pattern'; id: string; label: string; confidence: number; instances: number; firstSeenAt: string|null; lastSeenAt: string|null; trajectory: 'weakening'|'holding'|'strengthening'|'insufficient'|null; trajectoryDetail: Partial<TrajectoryResult>|null; register: 'stated' }
interface WhyItem { kind: 'why'; id: string; patternId: string; mechanism: string /* avoidance|ambivalence|capacity|unclear */; confidence: number; register: 'asked'; provisional: boolean }
interface GoalItem { kind: 'goal'; id: string; title: string; description: string|null; statedAt: string|null; register: 'stated' }
interface Shift { domain: string; metric: string; label: string; direction: 'up'|'down'; recentMedian: number; baselineMedian: number; change: number; p: number; recentDays: number; baselineDays: number; sourceIds: string[] }   // src/brain/baseline-shifts.ts:43-51
interface WeekTime { category: 'exercise'|'health'|'learning'|'travel'|'social'|'meetings'|'focus'|'personal'|'other'; thisWeek: number; usualWeek: number }  // hours; src/brain/time-categories.ts:14,54-59
interface AnswerMove { answerId: string; questionId: number; before: number|null; after: number; isNew: boolean; newSupporting: number; newContradicting: number; evidenceIds: string[] }  // src/understanding/answer-moves.ts:40-47
interface TrajectoryResult { trajectory; prior: number; recent: number; priorDays: number; recentDays: number; p: number; ratio: number|null }  // src/brain/trajectory.ts:26-36
```
Rules: one standing answer per question (confirmed first, then most confident); answers in domains that may not speak are omitted and the domain is listed in `silent`; rejected answers and anything with an open non-info lint finding are omitted. Goals are filtered by `is_active !== false` (not by `goals.status`). About 11 queries, no model calls. This is the designated read contract for "what the brain knows" and the right basis for an app "portrait" door.

### 9.3 `src/brain/pulls.ts`

```ts
interface FactRow { id; predicate; subject_entity_id; object_entity_id: string|null; object_value: Record<string,unknown>|null; event_time: string|null; observed_at: string; valid_from: string|null; valid_to: string|null; status: string; assertion_kind: string; supersedes_id: string|null; metadata: Record<string,unknown> }  // :18-32 (rows are select('*'), so extra columns come through too)
currentTruth({ userId, predicate?, subjectEntityId?, limit? = 200 }): Promise<FactRow[]>        // :41-62  status active, valid_to null, newest observed first
changedSince({ userId, since, limit? = 200 }): Promise<ChangeRow[]>                            // :77-120 ChangeRow = { fact; change: 'became_true'|'retired'; replacedBy?: FactRow|null }
factsAbout({ userId, entityId, includeHistorical?, limit? = 100 }): Promise<FactRow[]>          // :123-140
goalsVsBehavior(userId): Promise<{ stated: FactRow[]; quit: FactRow[]; abandonedGoals: FactRow[] }>  // :146-168
selfTalk({ userId, since?, limit? = 50 }): Promise<FactRow[]>                                   // :171-185
livePatterns({ userId, includeNonPromotable?, limit? = 50 }): Promise<PatternRow[]>             // :214-234
pattern({ userId, patternId }): Promise<{ pattern: PatternRow; whys: any[]; facts: FactRow[] } | null>  // :237-254
factsFor({ userId, patternId, role? }): Promise<FactRow[]>                                       // :257-277
significantPeople({ userId, minSignificance? = 0.1, limit? = 50 }): Promise<PersonRow[]>         // :289-310 PersonRow = { id; canonical_name; significance: number; mentions: number }
gaps({ userId, since, expectedSources? = ['journal_entry','calendar','healthkit'] }): Promise<string[]>  // :319-340 plain-English strings, e.g. "no calendar data in this period"
lineage({ userId, id, kind: 'raw_content'|'assertion'|'pattern', direction: 'backward'|'forward' }): Promise<LineageNode[]>  // :359-436
interface LineageNode { kind: 'raw_content'|'assertion'|'pattern'|'why'; id: string; summary: string; stoppedBecause?: string }  // :344-350
```
Notes: all use the global client. `significantPeople` takes the first 50 person entities **before** filtering and sorting, so it can miss significant people in a large set. `factsAbout` interpolates `entityId` into a PostgREST `.or()` filter string (`:131`): never pass an unvalidated client value. Several sub-queries are not user-scoped: `pattern()` whys by `pattern_id` (`:248-249`), `factsFor`'s link lookup, `lineage` backward evidence by `assertion_id` and forward pattern links/patterns by id (`:377-379, 417-428`). Safe only because ids are UUIDs reached from user-scoped rows; a door must still never pass a raw client id into these.

### 9.4 `walkEvidence` (`src/brain/lineage.ts:31-64`)

```ts
type ClaimKind = 'answer' | 'why' | 'pattern' | 'fact'
type EvidenceKind = ClaimKind | 'raw_content' | 'source_item'
walkEvidence(claim: { kind: ClaimKind; id: string }, db?): Promise<Lineage>
interface Lineage { sources: Array<{ kind: EvidenceKind; id: string }> /* raw_content or source_item only */; steps: Array<{ from: EvidenceNode; to: EvidenceNode; role: string|null; excerpt: string|null }> }
```
Reads the `claim_edges` view (migration 131) up to depth 6. **No `user_id` filter at all**: the caller must check that the starting claim belongs to the user. Role values come from the underlying tables (`supports`, `contradicts`, `context`, `weakly_related`, `counter_evidence`, ...).

### 9.5 `readSaidVsDid` (`src/understanding/said-vs-did.ts:81-127`)

```ts
readSaidVsDid(userId, db?, now?, judge?): Promise<{ goals: SaidVsDid[]; usage: ClaudeUsage; considered?: number }>
interface SaidVsDid { goalId: string; title: string; said: { statedAt: string; lastMentionedAt: string|null }; did: { hoursThisWeek: number; hoursUsualWeek: number; events: number; contentItems: number; patterns: string[] }; evidence: string[] }
```
Hours are booked calendar hours (a floor), 1 decimal; "usual week" = average of the 4 weeks before. Makes **one model call** (`ANTHROPIC_TIME_CATEGORY_MODEL`, maxTokens 2000) whenever the user has active goals. Scans all of the user's calendar and YouTube rows each call. Filters goals by `goals.status = 'active'`, whereas `readUnderstanding` filters by `is_active`: the two can disagree about which goals exist. `considered` is missing when there are no goals.

---

## 10. Tables relevant to the app

### 10.1 `raw_content` (base table from retrospect-main + agent migrations)

Base (`tests/fixtures/base-schema.sql`): `id uuid PK, user_id uuid NOT NULL, content_type text NOT NULL (no CHECK), content text NOT NULL, content_date timestamptz, metadata jsonb default {}, processing_status text default 'pending', processing_error text, source_id uuid → data_sources, created_at, processed_at`.

Added by agent migrations: `embedding vector(3072)` (100), `source_item_id uuid → source_items`, `processing_started_at` (106), `attempt_count int NOT NULL default 0`, `next_attempt_at`, `failure_kind` (114; values `transient|terminal|not_applicable` after 116), `authorship` (115/124/126; `self|other|unknown`, set by trigger from content_type when not given), `dedup_key`, `dedup_strategy` (117), `trust_class` (129; `own_words|record|third_party|automated|reference`, NULL until read).

`processing_status` values: CHECK `('pending','processing','completed','failed')`.

`content_type` has **no CHECK**; values seen in code and migrations: own words `text_entry, journal_entry, voice_recording, voice_journal, video_entry, manual_journal, note, conversation, onboarding_profile`; documents `google_docs`; mail `gmail`; records `calendar, google_calendar, healthkit, screen_time, apple_music, photos, contacts, spotify, youtube, reddit, tiktok, x, netflix, linkedin, pinterest`; AI-assistant exports `chatgpt, claude`; reference `link, shared_link, reference, twitter_bookmarks`; system `daily_summary, social_web_research`. Sets that matter: "sent by the person" = `text_entry, journal_entry, voice_recording, voice_journal, conversation, manual_journal, link, shared_link, reference, note` (`src/planner/daily.ts:22`); own-words types for trust = `journal_entry, voice_journal, voice_recording, text_entry, video_entry, conversation, onboarding_profile, google_docs` (`src/brain/trust.ts`). Note `google_docs` counts as own words for trust but `unknown` authorship by default.

### 10.2 `assertions` (facts) and `assertion_evidence` (`108_integration_operations_graph_v2.sql:169-213`)

`assertions`: `id, user_id, subject_entity_id → entities NOT NULL, predicate text, object_entity_id → entities, object_value jsonb, assertion_kind, confidence numeric(4,3) 0..1, event_time, observed_at NOT NULL default now(), valid_from, valid_to, model_version, normalizer_version, supersedes_id → assertions, status, metadata jsonb, origin_key text NOT NULL (UNIQUE with user_id), created_at, updated_at`, plus `source_run_id` (110), `retired_by`, `retirement_reason` (113). CHECK: object_entity_id or object_value present.
- `assertion_kind`: `observed | inferred | user_confirmed | contradicted | superseded`.
- `status`: `active | contradicted | superseded | retired`.
- Predicates: open text; preferred vocabulary `stated_goal, quit_or_stopped, skipped_or_avoided, attended, said_about_self, mentioned_person, felt, health_metric, scheduled, communicated_with` (`src/types/index.ts:293-303`).
- `object_value` shape is inconsistent across writers: `{ normalized, raw }` (record patterns), `{ content, domain, identity_inference_id }` (legacy graph), `{ text }` (portrait reader expectation).
- Written only through the `write_fact(jsonb)` function (119/127), which checks evidence is the same user's.

`assertion_evidence`: `id, user_id, assertion_id → assertions CASCADE, analysis_unit_id, source_item_id, raw_content_id, evidence_role ('supports'|'contradicts'|'context'), weight numeric(4,3) default 1, excerpt text, created_at`, plus `char_start`, `char_end` (110). At least one of the three sources required.

### 10.3 `entities` (`108...sql:123-137`)

`id, user_id, entity_type, canonical_name, description, attributes jsonb (significance, significance_mentions live here for people), confidence numeric(4,3), status ('active'|'merged'|'retired'), merged_into_id, created_at, updated_at`. `entity_type`: `person, organization, project, place, topic, event, goal, identity, emotion, habit`. Related: `entity_aliases`, `entity_resolution_candidates`.

### 10.4 Question store (`120_canonical_questions.sql`, `121_question_answers.sql`)

- `question_domains`: `id text PK, label, position, speak_coverage numeric(3,2), confidence_floor numeric(3,2), half_life_days int, always_active bool`.
- **The 8 areas** (id: label): `who`: Who they are; `want`: What they want; `do`: What they actually do; `attention`: Their attention; `people`: The people in their life; `how`: How they are; `in_the_way`: What is in the way; `speak`: How to speak to them (always active).
- `canonical_questions`: `id smallint 1..99, domain_id, text, answerable_from text[], requires_own_words bool, hypothesis_only bool, half_life_days`. 36 rows: who 1-5, want 6-11, do 12-17, attention 18-21, people 22-26, how 27-30, in_the_way 31-33, speak 34-36. Hypothesis-only: Q10 ("What do they want that they have never named?") and Q32. Full texts at `120_canonical_questions.sql:62-99`.
- `evidence_kinds`: `journal 1.0, onboarding 1.0, confirmation 1.0, sent_mail 0.6, document 0.6, public_writing 0.6, profile 0.6, mail 0.6, pattern 0.6, calendar 0.4, screen_time 0.4, consumption 0.4, web 0.3, record 0.3, health 0.15`.
- `question_answers`: `id, user_id, question_id, answer text (non-blank), detail jsonb, status ('active'|'retired'), derived_by ('first_pass'|'researcher'|'arithmetic'|'quote'|'hypothesis'), derivation_key (UNIQUE with user), model_version, user_verdict ('confirmed'|'rejected'|null), verdict_at, created_at, updated_at, last_moved_at, retired_at, retirement_reason`. Writes only via `record_answer(jsonb)`; verdicts via `record_answer_verdict(user, answer, verdict)`. Service role has **SELECT only**.
- `answer_evidence`: `id, user_id, answer_id, stance ('supports'|'contradicts'), assertion_id | pattern_id | raw_content_id (exactly one), kind_id, source_key, observed_at, excerpt, created_at`, plus `retired_at` (138).
- Views (service_role SELECT): `answer_confidence (answer_id, user_id, question_id, status, user_verdict, support, against, confidence, independent_sources)`; `current_answers (user_id, question_id, domain_id, answer_id, answer, detail, confidence, independent_sources, user_verdict, last_moved_at, competing_answers)`; `domain_coverage (user_id, domain_id, label, questions, answered, confident, coverage, speak_coverage, may_speak)`; `answer_accuracy (user_id, confirmed, rejected, accuracy)`. Confidence = support / (support + against + 2), with time decay; computed at read time.

**Gap**: no agent route exposes `record_answer_verdict`, so the app has no way to confirm/reject an answer except via corrections.

### 10.5 `goal_candidates` (`100_agent_extensions.sql:73-85`)

`id, user_id, title, description, reasoning NOT NULL, supporting_observation_ids uuid[], confidence_score decimal(3,2), status ('pending'|'accepted'|'rejected'|'merged'), accepted_as_goal_id → goals, created_at, updated_at`. Only the legacy extractor writes it (`src/pipelines/ingest.ts:213`); in default facts mode nothing new arrives.

### 10.6 `goals` (base + 139)

Base: `id, user_id, title, description, is_active bool default true, embedding vector(3072), created_at, updated_at`. 139 adds `status ('active'|'quit'|'achieved'|'expired'|'merged') NOT NULL default 'active', merged_into, status_reason, status_at, last_mentioned_at`.

### 10.7 `users` columns added by agent migrations

`voice_persona` (123, re-adding the base column; `'thoughtful_friend'|'wise_mentor'|'energetic_host'`), `daily_brief_enabled boolean NOT NULL default false` (128), `ambient_enabled boolean NOT NULL default true` (141). Base columns: `id, apple_user_id UNIQUE NOT NULL, email, voice_persona, created_at, updated_at`.

### 10.8 Others

- `conversation_turns`: 1.3. `daily_briefs`: 2.4. `hypotheses`, `product_dials`: 3.3, 3.5.
- `actions` (`151_action_ledger.sql:5-17`): `id, user_id, action_class text, params jsonb, preview text NOT NULL, origin_raw_content_id, status ('proposed'|'approved'|'done'|'rejected'|'undone'|'failed'), approved_by ('person'|'standing_authorisation'), result jsonb, status_at, created_at`. Classes (`src/actions/ledger.ts:14-19`): `draft_message, reminder, calendar_hold, note`. Routes exist (`GET /actions/:userId`, `POST /actions/:userId/:id { decision: approve|reject|undo }`, 409 on wrong state) but **`proposeAction` has no caller anywhere**, so the ledger is always empty.
- `behavior_patterns` (111 + 135): `id, user_id, slug, label, status ('candidate'|'live'|'retired'|'user_rejected'), severity ('standard'|'high'|'extreme'), episode_promotable, first_seen_at, last_seen_at, instance_count, weighted_count, source_count, confidence, subject_entity_id, grouping_key, metadata, promoter_version, source_run_id, promoted_at, retired_at, retirement_reason, created_at, updated_at, trajectory, trajectory_detail, trajectory_at`. `behavior_pattern_whys`: `mechanism ('avoidance'|'ambivalence'|'capacity'|'unclear')`, `status ('provisional'|'live'|'retired'|'user_rejected')`.
- `reference_items` (142, 143, 147): `id, user_id, raw_content_id, url, intent, title, summary, topics text[], status ('new'|'enriched'|'failed'|'unsafe'), fetched_at, created_at, goal_ids uuid[], question_ids smallint[], related_at, embedding vector(3072)`.
- `claim_rejections` (148): `id, user_id, claim_kind ('fact'|'answer'), claim_key, source_id, note, created_at`.
- `claim_edges` view (131): `user_id, claim_kind, claim_id, evidence_kind, evidence_id, role, excerpt`.
- `pipeline_run_traces` (101): `kind` CHECK `('ingest','podcast','cookA','cookB','cookC')`, `status` `('running','completed','failed')`, `cost_breakdown` jsonb (used by the spend cap).

---

## 11. Auth middleware and error handler

- `requireInternalSecret` (`src/middleware/internal-auth.ts:15-34`) guards every route in this document (`src/index.ts:53-68`). Reads env `INTERNAL_API_SECRET`; if unset, **every** protected request gets `500 { "error": "server misconfigured: missing INTERNAL_API_SECRET" }`. Otherwise compares header `x-internal-secret` with `!==` (not constant-time); mismatch or missing → `401 { "error": "unauthorized" }`. No per-user auth, no rate limiting.
- `/runs` uses `requireInternalSecretOrLocalDev` (`:45-54`): open from loopback with no `x-forwarded-for` when `NODE_ENV !== 'production'`.
- `/health` is open. `cors()` is wide open (`index.ts:36`). Body limit `express.json({ limit: '10mb' })` (`:37`). A malformed JSON body: body-parser calls `next(err)`, which reaches the global handler below, so the caller gets **500** `{ "error": "<parser message>" }` (the handler ignores `err.status`, so it is not a 400). Same for a body over 10 MB.
- Global error handler (`src/index.ts:74-79`): `500 { "error": err.message }` and logs `[unhandled]`. Only reached by synchronous throws or `next(err)`; async throws in Express 4 handlers bypass it.
- Error body shape everywhere is `{ "error": string }`, with extra fields only on the 429 (`spentUsd`, `capUsd`). Raw Postgres/Supabase messages are passed through to the caller; the door should not forward them to the app verbatim.
- Server timeout 600 s, keep-alive 120 s (`index.ts:87-88`).

---

## 12. Test infrastructure

### 12.1 Pattern

There are **no HTTP-level route tests** (no test imports `src/routes/*`, no supertest). Tests call engine functions directly against a real Postgres (PGlite) built from all migrations, with the Supabase client's `from`/`rpc` swapped for a PGlite-backed fake.

- `freshDatabase(options?: { onApplied?, through? }): Promise<{ db: PGlite; results: MigrationResult[] }>` (`tests/support/fresh-database.ts:72-107`): stubs Supabase's `auth`/roles/storage, applies `tests/fixtures/base-schema.sql` (vendored retrospect-main schema), then every `supabase/migrations/NNN_*.sql` in order; a failing migration is reported in `results`, not thrown.
- `insertUser(db, email?)` (`:110-116`) returns a new user id.
- `supabaseOnPglite(db)` (`tests/support/supabase-on-pglite.ts:223`) returns `{ from, rpc }` translating supabase-js builders to SQL; unsupported builder calls throw. Production limits are simulated (`MAX_ROWS = 1000`, `MAX_IN_LIST = 300`).
- Runner: `node:test` via `npm test` = `tsx --test $(find tests -name '*.test.ts')`. `src/config.ts` requires `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `OPENAI_API_KEY` at import; CI passes placeholders (`.github/workflows/quality.yml`).
- PGlite runs as superuser, so **grant/privilege problems are invisible** unless a test does `SET ROLE service_role` (only `tests/migrations.test.ts` does).

Minimal example (shape of `tests/conversation.test.ts` / `tests/actions.test.ts`):

```ts
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { freshDatabase, insertUser, type PGlite } from './support/fresh-database';
import { supabaseOnPglite } from './support/supabase-on-pglite';
import { supabase } from '../src/db/supabase';
import { answerHypothesis } from '../src/hypotheses/offer';

let db: PGlite;
before(async () => {
  ({ db } = await freshDatabase());
  const fake = supabaseOnPglite(db);
  Object.assign(supabase, { from: fake.from, rpc: fake.rpc });   // every engine now hits PGlite
});

test('a yes confirms an open hypothesis, once', async () => {
  const user = await insertUser(db);
  const { rows: [h] } = await db.query<{ id: string }>(
    `INSERT INTO hypotheses (user_id, framework, question) VALUES ($1, 'sdt', 'Is it about time alone?') RETURNING id`, [user]);
  assert.deepEqual(await answerHypothesis(user, h!.id, 'yes'), { status: 'confirmed' });
  await assert.rejects(answerHypothesis(user, h!.id, 'yes'), /no open hypothesis/);
});
```

Model calls are injected through each engine's `options` (e.g. `converse(user, text, { model, guard, search, contract, now })`). To test a route handler itself you would need to add supertest or call the router with fake `req`/`res` objects, as `tests/runs-auth.test.ts` does for middleware.

### 12.2 Adding a migration

- Name: `supabase/migrations/NNN_snake_case.sql`, three digits, next is **152**. The replay and ledger pick up files matching `/^\d{3}_.*\.sql$/`, sorted lexically (`fresh-database.ts:51-55`). (`ALL_second_brain_migrations.sql` is ignored.)
- House style: additive (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`), header comment with the goal and why, `ENABLE ROW LEVEL SECURITY`, `REVOKE ALL ... FROM PUBLIC, anon, authenticated`, explicit `GRANT ... TO service_role`.
- Apply: `npm run db:migrate` (plan only), `npm run db:migrate -- --apply`, or `--only 152_x.sql [--apply]`; first-time adoption `--baseline-through NNN_x.sql` (`scripts/migrate.ts:1-23`). Needs `DATABASE_URL` (direct Postgres string). Each migration runs in its own transaction and is recorded; first failure rolls back and stops (`src/db/migrate.ts:96-116`). It refuses to run a migration that `db:check` says production already has (applied by hand).
- Ledger: table `schema_migrations (file text PK, applied_at timestamptz default now(), how text CHECK in ('applied','baseline'))`, `REVOKE ALL FROM PUBLIC` (`src/db/migrate.ts:15-26`).
- `tests/migrations.test.ts` replays everything; add assertions there for constraints/grants, and use `SET ROLE service_role` to test privileges.
- Note: tables `users`, `raw_content`, `goals`, `podcast_episodes`, `observations`, `insights` belong to retrospect-main's schema; the agent only alters them.

---

## Appendix: route table

| method + path | handler | engine | writes | model | idempotent |
|---|---|---|---|---|---|
| POST /conversation | conversation.ts:9 | reply.ts:54 | raw_content, conversation_turns (+corrections) | writer, guard (+writer) | no |
| GET /conversation/:userId/today | conversation.ts:17 | - | - | - | yes |
| GET /briefs/:userId/latest | briefs.ts:9 | - | - | - | yes |
| POST /briefs/generate | briefs.ts:17 | run-daily-brief.ts:93 | daily_briefs upsert | questions (v1) / writer+guard (v2) | per day (see 2.2) |
| PUT /briefs/:userId/enabled | briefs.ts:28 | - | users | - | yes |
| POST /hypotheses/:userId/:id | hypotheses.ts:10 | offer.ts:54 | hypotheses | - | second call 404s |
| GET /hypotheses/:userId/:id/why | hypotheses.ts:18 | - | - | - | yes |
| POST /corrections | corrections.ts:14 | target.ts:51 | on applied (4.3) | writer | no |
| POST /corrections/confirm | corrections.ts:27 | apply.ts:74 | 4.3 | - | mostly |
| POST /search/sources | search.ts:13 | search.ts:13 | - | embedding | yes |
| POST /search/answer | search.ts:21 | answer.ts:74 | - | rewrite, writer, guard, embedding | yes |
| GET /search/:userId/source/:kind/:id | search.ts:29 | source.ts:14 | - | - | yes |
| POST /onboarding/interpret | onboarding.ts:26 | magic-moments.ts:32 | user_understanding | cook0 | no |
| POST /onboarding/goals | onboarding.ts:137 | stated-goals.ts:52 | - | questions | yes (no writes) |
| GET /onboarding/readiness/:userId | onboarding.ts:163 | pipeline.ts:55 | - | - | yes |
| POST /onboarding/advance | onboarding.ts:173 | pipeline.ts:88 | answers or episode | many | sequentially yes, concurrently no |
| POST /podcasts/generate | podcasts.ts:13 | podcast.ts:360 | episode, traces, storage, hypotheses | many + TTS | no |
| GET /podcasts/:userId | podcasts.ts:53 | - | - | - | yes |
| POST /feedback/episodes/:episodeId | feedback.ts:11 | - | episode_feedback | - | no |
| GET/PUT /settings/:userId/ambient | settings.ts:20/12 | switch.ts | users | - | yes |
| GET/PUT /settings/:userId/appetite | settings.ts:28/34 | appetite.ts | user_preferences.metadata | - | yes |
| GET /settings/:userId/learning | settings.ts:42 | reception.ts:85 | - | - | yes |
| GET/PUT /preferences/:userId | preferences.ts:7/17 | - | user_preferences (full replace) | - | yes |
| POST /notifications/generate | notifications.ts:25 | - | - | cookB | no writes |
